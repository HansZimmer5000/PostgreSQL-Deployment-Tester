#!/bin/sh

log(){
	echo "$1" >> /etc/keepalived/notify_log.txt
}

gather_running_containers(){
    docker ps --format "table {{.ID}}\t{{.Names}}"
}

role_sql(){
    docker exec $1 psql -v ON_ERROR_STOP=1 --username primaryuser --dbname testdb -c 'SELECT * FROM pglogical.pglogical_node_info();'
}

determine_role(){
    # pglogical.show_subscription_status() --> if >0 shows that subscriber
    # SELECT * FROM pg_replication_slots; --> if >0 shows that provider
    # pglogical.pglogical_node_info() --> shows what nodes are active, if "provider" -> provider
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
				if [[ ($CURRENT_NAME == pg_db*) ]]; then
					CURRENT_NAME=${CURRENT_NAME:3:12}
					CURRENT_IP=$(docker inspect -f '{{.NetworkSettings.Networks.pg_pgnet.IPAddress}}' $CURRENT_ID)
					
					# It is only possible to have one postgres instance running!
					container_id="$CURRENT_ID"
					subscription_id="subscription${CURRENT_IP//./}"
				fi
			fi
		fi
		info_no=$((info_no+1))
	done
}

# unused value TYPE=$1
# unused value NAME=$2
state=$3
echo "$state $(date)" > /etc/keepalived/current_state.txt

log "Notify.sh at $(date):" 
container_id=""
subscription_id=""
set_ids

log "1=$1 2=$2 State=$3 Prio=$4"
log "ContainerID: $container_id SubscriptionID: $subscription_id"

# TODO Notes
# State 1: no VIP, 	no PG	-> Nothing todo 
# State 2: no VIP, 	Sub		-> Nothing todo 
# State 3: no VIP, 	Prov	-> Reconnect or Receive VIP
# State 4: VIP, 	no PG	-> Release VIP
# State 5: VIP, 	Sub		-> Release VIP or promote 
# State 6: VIP, 	Prov	-> Nothing todo 

# TODO keepalived restart -> beduetet das eine Zurücksetzung der Priority? - Fehler gefunden dass neuer keepalivd immer Vip bkeommt ? test 4 

case $state in
	"MASTER") 	log "Enter MASTER" 
				if [ -z $(docker ps | grep "pg_db") ]; then {
					log "Finite State Machine State 4 - VIP but no PG"
					log "Restarting keepalived with notify.sh: $(docker ps | grep "pg_db")" 
					systemctl restart keepalived
				}
				else
					# Differentiate State 5 and 6
					if [ -z "$container_id" ]; then
						"ContainerID was empty, no role check or pormotion possible!"
					else
						role=$(determine_role $container_id)
						if [ $role == "sub" ]; then 
							log "Finite State Machine State 5 - VIP and Sub"
							log "$(/etc/keepalived/promote.sh $container_id $subscription_id)"
						fi
					fi
				fi
 				;;
	"BACKUP") 	log "Enter BACKUP" 
				if [ -z $(docker ps | grep "pg_db") ]; then
					log "Finite State Macine State 1 - no VIP, no PG"
				else
					if [ -z "$container_id" ]; then
						"ContainerID was empty, no role check or reconnection possible!"
					else
						role=$(determine_role $container_id)
						if [ $role == "sub" ]; then 
							log "Finite State Machine State 2 - no VIP, Subscriber, but Provider may have changed so reconnect to make logical replication work again"
							/etc/reconnect.sh "$container_id"
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
							/etc/reconnect.sh "$container_id"
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