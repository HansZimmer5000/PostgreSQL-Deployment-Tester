#!/bin/sh

log(){
	echo "$1" >> /etc/keepalived/notify_log.txt
}

get_pg_status(){
	(docker exec $1 psql -v ON_ERROR_STOP=1 --username postgres --dbname testdb -c 'SELECT * FROM pglogical.pglogical_node_info();') 1> /dev/null
}

# TODO adjusted copy from id_ip_nodes.sh
# TODO may only use Major Version (9.5 / 9.6 / 10 / 11 / ...)
determine_db_version() {
	result_raw=$(docker exec $1 psql -v ON_ERROR_STOP=1 --username postgres --dbname testdb -c 'SELECT version();' 2>/dev/null)
    arr=($result_raw)
    result="${arr[3]}"
    if [ -z "$result" ] || [ "$result" == "failed:" ]; then
        result="err"
    fi
    echo $result
}

pg_is_ready(){
	result=false
	version=$(determine_db_version $1) 
	status=$(get_pg_status $1 2>&1)
	if ! [ "$version" == "err" ] && [ -z "$status" ]; then
		result=true
	fi
	echo $result
}

# To check on VM (Beware, long cmd): 
# source notify.sh ; export -f get_pg_status gather_running_containers set_ids pg_is_ready determine_db_version ; watch "container_id=0 ; set_ids ; pg_is_ready $container_id"
wait_for_all_pg_to_boot(){
    while [[ $(systemctl status keepalived) == *"Active: active"* ]]; do

		if $(pg_is_ready $1); then	
			break
		fi
		
		log "Still waiting for PG"
        sleep 2s
    done
    echo ""
}

gather_running_containers(){
    docker ps --format "table {{.ID}}\t{{.Names}}"
}

role_sql(){
    docker exec $1 psql -v ON_ERROR_STOP=1 --username postgres --dbname testdb -c 'SELECT * FROM pglogical.pglogical_node_info();'
}

determine_role(){
    res="$(role_sql $1)"
    rows=$( echo "$res" | grep "provider")
    if [[ "$rows" == *provider* ]]; then
        echo "prov"
    else 
        echo "sub"
    fi
}

set_ids(){
	running_containers=$(gather_running_containers root@$node)
	info_no=0
	for info in $running_containers; do
		# Via "-gt 2" skip the headlines
		if [ "$info_no" -gt 2 ]; then
			if [ $((info_no % 2)) == 1 ]; then
				# First comes the id
				CURRENT_ID=$info
			else 
				# Second comes the name
				CURRENT_NAME=$info

				# Implicitly set ids
				if [[ ($CURRENT_NAME == pg95_db*) ]] || [[ ($CURRENT_NAME == pg10_db*) ]]; then
					CURRENT_NAME=${CURRENT_NAME:3:12}
					CURRENT_IP="$(docker inspect -f '{{.NetworkSettings.Networks.pg95_pgnet.IPAddress}}' $CURRENT_ID)"
					
					if [ -z "$CURRENT_IP" ] || [[ "$CURRENT_IP" == *"<no value>"* ]]; then
						CURRENT_IP="$(docker inspect -f '{{.NetworkSettings.Networks.pg10_pgnet.IPAddress}}' $CURRENT_ID)"
					fi

					# It is only possible to have one postgres instance running!
					container_id="$CURRENT_ID"
					subscription_id="subscription${CURRENT_IP//./}"
				fi
			fi
		fi
		info_no=$((info_no+1))
	done
}

state=$3
echo "$state $(date)" > /etc/keepalived/current_state.txt

log "Notify.sh at $(date):" 
container_id=""
subscription_id=""
set_ids

log "1=$1 2=$2 State=$3 Prio=$4"
log "ContainerID: $container_id SubscriptionID: $subscription_id"

## States
# State 1: no VIP, 	no PG	-> Nothing to do 
# State 2: no VIP, 	Sub		-> Nothing to do 
# State 3: no VIP, 	Prov	-> Reconnect or Receive VIP
# State 4: VIP, 	no PG	-> Release VIP
# State 5: VIP, 	Sub		-> Release VIP or promote 
# State 6: VIP, 	Prov	-> Nothing to do 

case $state in
	"MASTER") 	log "Enter MASTER" 
				grep_res_v95=$(docker ps | grep "pg95_db")
				grep_res_v10=$(docker ps | grep "pg10_db")
				if [ -z "$grep_res_v95" ] && [ -z "$grep_res_v10"] ; then 
					log "Finite State Machine State 4 - VIP but no PG"
					log "Restarting keepalived with notify.sh" 
					systemctl restart keepalived
				else
					# Differentiate State 5 and 6
					if [ -z "$container_id" ]; then
						log "ContainerID was empty, no role check or pormotion possible!"
					else
						role=$(determine_role $container_id)
						if [ $role == "sub" ]; then 
							log "Finite State Machine State 5 - VIP and Sub"

							log "Waiting for Postgres to be ready"
							wait_for_all_pg_to_boot $container_id
							
							# TODO let it match only major version?
							cluster_pg_version=$(cat /etc/keepalived/cluster_version.txt)
							local_pg_version=$(determine_db_version $container_id)
							if [ "$local_pg_version" == "$cluster_pg_version" ]; then
								log "$(/etc/keepalived/promote.sh $container_id $subscription_id)"
							else
								log "Cluster version was different (File=$cluster_pg_version//Local=$local_pg_version), cannot promote! Restarting keepalived"
								systemctl restart keepalived
							fi
						fi
					fi
				fi
 				;;
	"BACKUP") 	log "Enter BACKUP" 
				if [ -z $(docker ps | grep "pg95_db") ] && [ -z $(docker ps | grep "pg10_db") ]; then
					log "Finite State Machine State 1 - no VIP, no PG"
				else
					if [ -z "$container_id" ]; then
						log "ContainerID was empty, no role check or reconnection possible!"
					else
						role=$(determine_role $container_id)
						if [ $role == "sub" ]; then 
							log "Finite State Machine State 2 - no VIP, Subscriber, but Provider may have changed so reconnect to make logical replication work again"
							/etc/reconnect.sh $container_id $subscription_id
						else
							log "Finite State Machine State 5 - no VIP, Provider"
							# TODO Reconnect or wait for VIP to be released?
							# What do i need to answer this?
							# 	Why did Provider loose the VIP?
							#	- keepalived Fails
							#	- keepalived has lower priority
							#	- Promotion without VIP
							# 	Is there another Provider now in the system?
							log "Testing Safe Approach - Reconnect"
							/etc/reconnect.sh $container_id $subscription_id
						fi
					fi
				fi
				;;
	"FAULT")  	log "Enter FAULT" 
				;;
	*)			log "Enter NIX"
				;;
esac

log "Notify End"
log ""