#!/bin/sh

TYPE=$1
NAME=$2
STATE=$3
echo "$STATE" > /etc/keepalived/current_state.txt

log(){
	echo "$1" >> /etc/keepalived/notify_log.txt
}

log "Notify.sh at $(date):" 

gather_running_containers(){
    docker ps --format "table {{.ID}}\t{{.Names}}"
}

container_id=""
subscription_id=""
RUNNING_CONTAINERS=$(gather_running_containers root@$node)
INFO_NO=0

set_ids(){
	for info in $RUNNING_CONTAINERS; do
		if [ "$INFO_NO" -gt 2 ]; then
			if [ $((INFO_NO % 2)) == 1 ]; then
				CURRENT_ID=$info
			else 
				CURRENT_NAME=$info

				if [[ ($CURRENT_NAME == pg_db*) ]]; then
					CURRENT_NAME=${CURRENT_NAME:3:12}
					CURRENT_IP=$(docker inspect -f '{{.NetworkSettings.Networks.pg_pgnet.IPAddress}}' $CURRENT_ID)
					
					# Is it is only possible to have one postgres instance running!
					container_id="$CURRENT_ID"
					subscription_id="subscription${CURRENT_IP//./}"

					log "GOT $container_id AND $subscription_id"
				fi
			fi
		fi
		INFO_NO=$((INFO_NO+1))
	done
}

set_ids
case $STATE in
	"MASTER") 	if [ -z "$container_id" ] || [ -z "$subscription_id" ]; then
					log "MASTER Failed due to empty container_id($container_id) or subscription_id($subscription_id)"
				elif [ -z $(docker ps | grep "pg_db") ]; then {
					echo "Restarting keepalived with notify.sh: $(docker ps | grep "pg_db")"  >> /etc/keepalived/notify_log.txt
					systemctl restart keepalived
				}
				else
					/etc/keepalived/promote.sh "$container_id" "$subscription_id" >> /etc/keepalived/notify_log.txt
				fi
 				;;
	"BACKUP") 	if [ -z "$container_id" ] || [ -z "$subscription_id" ]; then
					log "BACKUP Failed due to empty container_id($container_id) or subscription_id($subscription_id)"
				else
					/etc/reconnect.sh "$container_id" "$subscription_id" >> /etc/keepalived/notify_log.txt
				fi
				;;
	"FAULT")  	echo "FAULTY" >> /etc/keepalived/notify_log.txt
				;;
	*)			echo "NIX" >> /etc/keepalived/notify_log.txt
				;;
esac

log ""