# !/bin/sh 
# This is meant to be 'sourced' from test_client_lib.sh!

scale_service(){
    if  [ -z "$1" ] || [ -z "$2" ]; then
        echo "Missing Servicename or new replication count!"
    else
        $SSH_CMD root@$MANAGER_NODE "docker service scale $1=$2"
    fi
}

# TODO This variable is intentionally the same as in id_ip_nodes.sh, but this seems very ugly!
current_sub_count=1

kill_postgres(){
    CURRENT_INFO=$(get_node_and_id_from_name "$1")
    IFS=',' read CURRENT_NODE CURRENT_ID <<< "${CURRENT_INFO}"

    $SSH_CMD root@$CURRENT_NODE "docker rm -f $CURRENT_ID"
}

# kill_provider only works under the assumption that there is at most one provider in the system!
# Otherwise it will kill all providers.
kill_provider(){
    for tuple in $(get_all_tuples); do
        current_role=$(get_role "$tuple")
        if [[ $current_role == "prov" ]]; then
            current_name=$(get_name "$tuple")

            kill_subscriber "$current_name" "$1"
        fi
    done
}

# Kill Subscriber (as harsh as possible) and immediately Scale the subscriber service down by one so Swarm doesn't directly start a new subscriber
kill_subscriber(){
    # TODO make it possible via parameter to shutdown "smart"
    # TODO rename function since it basically can kill subscriber and provider instances.

    kill_postgres "$1" 
    echo Current Count = $current_sub_count
    
    if [ "$2" != "-c" ]; then
        current_sub_count=$(($current_sub_count - 1))
        if [ "$current_sub_count" -lt 0 ]; then
            current_sub_count=0
        fi
        IFS='.' read service_name replic_number <<< "$1"
        scale_service $service_name $current_sub_count
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
    for tuple in $(get_all_tuples); do
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
    # Scale the subscriber service up by one
    # Test: (Re-) Start of Subscribers that creates subscription
    # Test: Subscriber also receives als data before start.
    echo "This may take a few moments and consider deployment-constraints / ports usage which could prevent a success!"
    current_sub_count=$(($current_sub_count + 1))
    scale_service "$1" $current_sub_count
    wait_for_all_pg_to_boot
}

return_from_trap(){
    echo "Aborting Observation"
    trap - SIGINT
    $0 # Restart script.
}

#observe=true
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
