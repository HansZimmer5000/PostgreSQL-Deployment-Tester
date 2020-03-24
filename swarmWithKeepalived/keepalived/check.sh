#!/bin/bash

gather_running_pg_container(){
    docker ps --format "table {{.ID}}\t{{.Names}}" | grep "pg_db"
}

get_pg_container_id(){
    RUNNING_CONTAINER=($(gather_running_pg_container))
    if [ ${#RUNNING_CONTAINER[@]} -gt 0 ]; then
        echo ${RUNNING_CONTAINER[0]}
    fi
}

sql(){
    docker exec $1 psql -v ON_ERROR_STOP=1 --username primaryuser --dbname testdb -c 'SELECT * FROM pglogical.pglogical_node_info();'
}

determine_role(){
    # pglogical.show_subscription_status() --> if >0 shows that subscriber
    # SELECT * FROM pg_replication_slots; --> if >0 shows that provider
    # pglogical.pglogical_node_info() --> shows what nodes are active, if "provider" -> provider
    res="$(sql $1)"
    rows=$( echo "$res" | grep "provider")
    if [[ "$rows" == *provider* ]]; then
        echo "prov"
    else 
        echo "sub"
    fi
}

# Exists with 0 if pg status' is good, otherwise 1
pg_is_up(){
    container_id=$(get_pg_container_id)
    if [ -z "$container_id" ]; then
        if [[ "$(hostname -I)" == *"192.168.99.149"* ]]; then
            systemctl restart keepalived
        else
            exit 0
        fi
    else
        #result="$(docker exec -ti $container_id pg_isready)"
        #if [[ "$result" == *"- accepting connections"* ]]; then
        result="$(determine_role $container_id)"

        #/etc/keepalived/current_state.txt
        if [ "$result" == "prov" ]; then
            if [[ "$(hostname -I)" == *"192.168.99.149"* ]]; then
                echo 1
            else 
                /etc/keepalived/notify.sh . . BACKUP >> /etc/keepalived/notify_log.txt
            fi
        else   
            if [[ "$(hostname -I)" == *"192.168.99.149"* ]]; then
                echo "Restarting keepalived" >> /etc/keepalived/notify_log.txt
                systemctl restart keepalived
                #/etc/keepalived/notify.sh . . MASTER >> /etc/keepalived/notify_log.txt
            else 
                exit 0
            fi
        fi
    fi
}

pg_is_up