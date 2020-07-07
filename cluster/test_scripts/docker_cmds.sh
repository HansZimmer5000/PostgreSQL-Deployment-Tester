# !/bin/sh 
# This is meant to be 'sourced' from test_client_lib.sh!

# CONTAINER
################

# TODO This variable is intentionally the same as in id_ip_nodes.sh, but this seems very ugly!
current_sub_count=1

kill_postgres(){
    CURRENT_INFO=$(get_node_and_id_from_name "$1")
    IFS=',' read CURRENT_NODE CURRENT_ID <<< "${CURRENT_INFO}"

    $SSH_CMD root@$CURRENT_NODE "docker rm -f $CURRENT_ID"
}

kill_provider(){
    # TODO make compatible to V10 stack?
    # Kill the Provider
    # Test: Swarm creates new Provider
    # Test: Provider takes over old subscriptions (does it work that way?

    for tuple in $ID_IP_NODEs 
    do
        CURRENT_ROLE=$(get_role "$tuple")
        if [[ $CURRENT_ROLE == "prov" ]]; then
            CURRENT_NAME=$(get_name "$tuple")
            kill_postgres "$CURRENT_NAME"
            CURRENT_NODE=$(get_node "$tuple")

            if [[ $CURRENT_NAME == "db_i" ]]; then
                # Killing Init_helper, so better make sure we have one more sub that can take over as provider
                current_sub_count=$(($current_sub_count + 1))
            else
                if [ "$1" != "-c" ]; then
                    current_sub_count=$(($current_sub_count - 1))
                fi
            fi

            if [ $CURRENT_NAME == "db_i" ] || [ "$1" != "-c" ]; then
                $SSH_CMD root@$MANAGER_NODE "docker service scale pg95_db=$current_sub_count" 1> /dev/null
                break
            fi
        fi
    done
}

kill_subscriber(){
    # TODO make compatible to V10 stack?
    # Kill Subscriber (as harsh as possible) and immediately Scale the subscriber service down by one so Swarm doesn't directly start a new subscriber
    # Test: Should cause no Problems.
    # Test: Provider can work on its own.

    kill_postgres "db.$1" 
    echo Current Count = $current_sub_count
    
    if [ "$2" != "-c" ]; then
        current_sub_count=$(($current_sub_count - 1))
        $SSH_CMD root@$MANAGER_NODE "docker service scale pg95_db=$current_sub_count"
    fi
}

get_log(){
    CURRENT_INFO=$(get_node_and_id_from_name "$1")
    if [ -z $CURRENT_INFO ]; then
        echo "Container $1 was not found, is it really active?"
    else
        IFS=',' read CURRENT_NODE CURRENT_ID <<< "${CURRENT_INFO}"
        $SSH_CMD_TIMEOUT root@$CURRENT_NODE "docker logs $CURRENT_ID"
    fi
}

get_notify_log(){
    $SSH_CMD root@$1 cat /etc/keepalived/notify_log.txt
}

wait_for_all_pg_to_boot(){
    for tuple in $ID_IP_NODEs; do
        container_id=$(get_id "$tuple")
        node=$(get_node "$tuple")
        while true; do
            result="$($SSH_CMD root@$node docker exec $container_id pg_isready)"
            if [[ "$result" == *"- accepting connections"* ]]; then
                printf "."
                break
            fi
            sleep 2s
        done
    done
    echo ""
}

start_new_subscriber(){
    # TODO make compatible to V10 stack?
    # Scale the subscriber service up by one
    # Test: (Re-) Start of Subscribers that creates subscription
    # Test: Subscriber also receives als data before start.
    echo "This may take a few moments and consider deployment-constraints / ports usage which could prevent a success!"
    current_sub_count=$(($current_sub_count + 1))
    $SSH_CMD root@$MANAGER_NODE "docker service scale pg95_db=$current_sub_count" # 1> /dev/null"
    wait_for_all_pg_to_boot
}

return_from_trap(){
    trap - SIGINT
    running_loop
}

observe_container_status(){
    trap return_from_trap SIGINT
    while true; 
    do
        echo "----------- $(date) ----------"
        update_id_ip_nodes
        get_current_node_ips
        echo ""
        print_id_ip_nodes
        sleep 4s 
    done
}
