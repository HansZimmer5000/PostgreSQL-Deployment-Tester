#!/bin/bash

# TODO What happens when keepalived on Provider node fails - Release of VIP?

# Exit 0 = OK
# Exit 1 = NOK

log(){
	echo "$1" >> /etc/keepalived/notify_log.txt
}

gather_running_pg_container(){
    docker ps --format "table {{.ID}}\t{{.Names}}" | grep "pg_db"
}

get_pg_container_id(){
    RUNNING_CONTAINER=($(gather_running_pg_container))
    if [ ${#RUNNING_CONTAINER[@]} -gt 0 ]; then
        echo ${RUNNING_CONTAINER[0]}
    fi
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

# Exists with 0 if pg status' is good, otherwise 1
sophisticated_test(){
    container_id=$(get_pg_container_id)
    has_vip=false

    if [[ "$(hostname -I)" == *"192.168.1.149"* ]]; then
        has_vip=true
    fi

    if [ -z "$container_id" ] && $has_vip; then
        # Finit State Machine State 4 - VIP, no PG
        log "Restarting keepalived due to having VIP but not having any postgres instance"
        systemctl restart keepalived
    elif [ -z "$container_id" ] && ! $has_vip; then
        # Finit State Machine State 1 - not VIP, no PG 
        exit 0
    else
        role="$(determine_role $container_id)"
        #result="$(docker exec -ti $container_id pg_isready)"
        #if [[ "$result" == *"- accepting connections"* ]]; then
        #/etc/keepalived/current_state.txt

        if [ "$role" == "prov" ] && $has_vip; then
            # Finite State Machine State 6 - VIP, Provider 
            exit 0
        elif [ "$role" == "prov" ] && ! $has_vip; then
            # Finite State Machine State 3 - no VIP, Provider
            #/etc/keepalived/notify.sh . . BACKUP >> /etc/keepalived/notify_log.txt
            # TODO what now? Wait for release or become sub?
            exit 0 # wait
        elif [ "$role" == "sub" ] && $has_vip; then
            # Finite State Machine State 5 - VIP, no Provider
            # TODO Restart keepalived or Promote or wait for notify script to promote
            exit 0 #wait

            #log "Restarting keepalived due to having VIP but not having Primary"
            #systemctl restart keepalived
            #/etc/keepalived/notify.sh . . MASTER >> /etc/keepalived/notify_log.txt
        else # [ "$role" == "sub" ] && ! $has_vip; then
            exit 0
        fi
    fi
}

advanced_test(){
    container_id=$(get_pg_container_id)
    has_vip=false

    if [[ "$(hostname -I)" == *"192.168.1.149"* ]]; then
        has_vip=true
    fi

    if [ -z "$container_id" ] && $has_vip; then
        exit 1
    elif [ -z "$container_id" ] && ! $has_vip; then
        exit 0
    elif ! [ -z "$container_id" ] && $has_vip; then
        exit 0
    else 
        exit 0
    fi
}

basic_test(){
    container_id=$(get_pg_container_id)
    if [ -z "$container_id" ]; then
        exit 1
    else
        exit 0
    fi
}

basic_test_v2(){
    # Not a good idea since then if only subs are in cluster, all keepalived priorities decrease infinitely
    container_id=$(get_pg_container_id)
    if [ -z "$container_id" ]; then
        if [ $(determine_role $container_id) == "prov" ]; then
            exit 0
        fi
    fi
    exit 1
}

sophisticated_test