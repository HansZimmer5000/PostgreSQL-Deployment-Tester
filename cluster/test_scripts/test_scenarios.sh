# !/bin/sh
# This is meant to be 'sourced' from test_client_lib.sh!

test_log(){
    echo "$(date) $@"
}

# TESTSCENARIOS
# Expecting 1 Provider 1 and Subscriber"
################

reset_provider(){
    prov_version="9.5"

    if [ "$1" == "true" ]; then
            prov_version="10"
    fi

    test_log "Reseting Cluster with a provider of version $prov_version"

    provider_exists=false

    for tuple in $(get_all_tuples) 
    do
        current_role=$(get_role "$tuple")
        current_version=$(get_version "$tuple")
        if [[ $current_role == "prov" ]] && ! $provider_exists && [[ "$current_version" == "$prov_version"* ]]; then
            test_log Found Provider $(get_name "$tuple")
            provider_exists=true
        elif [[ $current_role == "prov" ]] && $provider_exists; then
            # In case this is an additional provider 
            # In case this is a provider with the wrong version
            current_name=$(get_name "$tuple")
            test_log "removing $current_name"
            kill_subscriber "$current_name" 1> /dev/null
        fi
    done

    if ! $provider_exists; then
        if [ "$prov_version" == "10" ]; then
            start_new_subscriber "pg10_db"
        else
            start_new_subscriber "pg95_db"
        fi
    fi
}

reset_subscriber(){
    v95_sub_count=1
    v10_sub_count=0

    if ! [ -z "$1" ] && [ "$1" -ge 0 ]; then
            v95_sub_count=$1
    fi

    if ! [ -z "$2" ] && [ "$2" -ge 0 ]; then
            v10_sub_count=$2
    fi

    test_log "Reseting Cluster with $v95_sub_count v9.5 Subscriber and $v10_sub_count v10 Subscriber"

    v95_sub_exists_count=0
    v10_sub_exists_count=0

    for tuple in $(get_all_tuples) 
    do
        current_role=$(get_role "$tuple")
        current_version=$(get_version "$tuple")
        if [[ $current_role == "sub" ]] && [ $v95_sub_exists_count -lt $v95_sub_count ] && [[ "$current_version" == "9.5"* ]]; then
            test_log Found Subscriber $(get_name "$tuple")
            sv95_sub_exists_count=$(($v95_sub_exists_count+1))
        elif [[ $current_role == "sub" ]] && [ $v10_sub_exists_count -lt $v10_sub_count ] && [[ "$current_version" == "10"* ]]; then
            test_log Found Subscriber $(get_name "$tuple")
            v10_sub_exists_count=$(($v10_sub_exists_count+1))
        elif [[ $current_role == "sub" ]]; then
            # In case this is a subscriber and the v95_sub_count was already reached
            # In case this is a subscriber and the v10_sub_count was already reached
            # In case this is not a v9.5 or v10 subscriber
            current_name=$(get_name "$tuple")
            test_log "removing $current_name"
            kill_subscriber "$current_name" 1> /dev/null
        fi
    done

    while [ $v95_sub_exists_count -lt $v95_sub_count ]; do
        start_new_subscriber "pg95_db"
        sleep 15s #Wait for older Hardware to start subscriber
        v95_sub_exists_count=$(($v95_sub_exists_count+1))
    done

    while [ $v10_sub_exists_count -lt $v10_sub_count ]; do
        start_new_subscriber "pg10_db"
        sleep 15s #Wait for older Hardware to start subscriber
        v10_sub_exists_count=$(($v10_sub_exists_count+1))
    done
}

# Expecting v9.5 Subscriber count as Param1, default is 1
# Expecting v10 Subscriber count as Param2, default is 0
# Expecting if Provider should be v10, default is false (v9.5)
reset_cluster(){
    update_id_ip_nodes

    v95_instances=0
    v10_instances=0

    if [ "$3" == "true" ]; then
        set_cluster_version 10.13
        v10_instances=1
    else
        set_cluster_version 9.5.18
        v95_instances=1
    fi

    if ! [ -z "$1" ]; then
        v95_instances=$(($v95_instances+$1))
    fi

    if ! [ -z "$2" ]; then
        v10_instances=$(($v10_instances+$2))
    fi

    if [ $((v95_instances + v10_instances)) -gt $(echo $ALL_NODES | wc -w) ]; then
        test_log Aborting due to more instances wanted ($v95_instances + $v10_instances) than nodes $(echo $ALL_NODES | wc -w)!
        exit 1
    fi

    current_v95_node_num=1
    while [ "$current_v95_node_num" -le $v95_instances ]; do
        set_label_version $current_v95_node_num 9.5
        current_v95_node_num=$(($current_v95_node_num+1))
    done

    node_num_offset=$(($current_v95_node_num-1))
    current_v10_node_num=1
    while [ "$current_v10_node_num" -le $v10_instances ]; do
        set_label_version $(($current_v10_node_num+$node_num_offset)) 10
        current_v10_node_num=$(($current_v10_node_num+1))
    done

    # TODO maybe only scale services according to v*_instances count but kill provider with "-c".
    reset_provider $3
    reset_subscriber $1 $2

    update_id_ip_nodes
    clear_all_local_tables
    reconnect_all_subscriber
}

test_1(){
    # Check if roles and replications are set correctly
    # 0. Reset Cluster
    # 1. Add Data via provider
    # 2. Check that all instances have same state
    # 3. Remove all data from all instances
    # 4. For each subscriber: 
    #   1. Add Data via subscriber
    #   2. Check that only this subscriber has new data

    # 0.
    test_log "0. Reset Cluster"
    reset_cluster 1 1> /dev/null

    # 1. - 4.
    test_log "1.-4. Check instance roles"
    check_roles
}

test_2(){
    # Check if new subscriber gets old and new data.
    # 0. Reset Cluster
    # 1. Add Data via provider
    # 2. Start new subscriber
    # 3. Add Data via provider
    # 4. Check if subscriber has both datasets

    # 0.
    test_log "0. Reset Cluster"
    reset_cluster 0 1> /dev/null

    # 1.
    test_log "1. Add Data via provider"
    provider_tuple="$(get_all_provider)"
    PROVIDER_NODE=$(get_node "$provider_tuple")
    PROVIDER_ID=$(get_id "$provider_tuple")

    FIRST_INSERTED_ID=1
    add_entry $PROVIDER_NODE $PROVIDER_ID $FIRST_INSERTED_ID 1> /dev/null

    # 2.
    test_log "2. Start new subscriber"
    start_new_subscriber "pg95_db" 1> /dev/null
    sleep 15s # For older Hardware
    update_id_ip_nodes

    # 3.
    test_log "3. Add Data via provider"
    SECOND_INSERTED_ID=2
    add_entry $PROVIDER_NODE $PROVIDER_ID $SECOND_INSERTED_ID 1> /dev/null
    sleep 5s # For older hardware

    # 4.
    test_log "4. Check if subscriber has both datasets"
    result=$(check_tables true)
    if [[ $result == true ]]; then
        test_log "Test 2 was successfull"
    else
        >&2 test_log "$result"
    fi
}

test_3(){
    # Check if new provider actually gets recognized as new provider
    # 0. Reset Cluster
    # 1. Add Data via provider
    # 2. Check that all instances have same state
    # 3. Remove all data from subscribers 
    # 4. Kill Provider
    # 5. Let Docker Swarm start new provider 
    # 6. Add Data via provider
    # 7. Check that all instances have the new data

    test_log "0. Reset Cluster"
    reset_cluster 1 1> /dev/null

    test_log "1. Add Data via provider"
    provider_tuple="$(get_all_provider)"
    PROVIDER_NODE=$(get_node "$provider_tuple")
    PROVIDER_ID=$(get_id "$provider_tuple")
    FIRST_INSERTED_ID=1

    add_entry $PROVIDER_NODE $PROVIDER_ID $FIRST_INSERTED_ID 1> /dev/null

    test_log "2. Check that all instances have same state"
    result=$(check_tables true)
    if [[ $result != true ]]; then
        >&2 test_log "$result"
        exit 1
    fi

    test_log "3. Remove all data from subscribers"
    clear_all_local_tables 1> /dev/null

    test_log "4. Kill Provider"
    kill_provider -c
    sleep 75s #Let slow hardware handle the "killing" and give time to docker & keepalived reevalute 
    update_id_ip_nodes 

    test_log "5. Let Docker Swarm start new provider"
    wait_for_all_pg_to_boot
    reconnect_all_subscriber

    test_log "6. Add Data via provider"
    provider_tuple="$(get_all_provider)"
    PROVIDER_NODE=$(get_node "$provider_tuple")
    PROVIDER_ID=$(get_id "$provider_tuple")
    
    SECOND_INSERTED_ID=2
    add_entry $PROVIDER_NODE $PROVIDER_ID $SECOND_INSERTED_ID 1> /dev/null

    test_log "7. Check that all instances have the new data"
    result=$(check_tables true)
    if [[ $result == true ]]; then
        test_log "Test 3 was successfull"
    else
        >&2 test_log "$result"
    fi
}

test_4(){
    # Check if new provider has old data
    # 0. Reset Cluster
    # 1. Add Data via provider
    # 2. Check that all instances have same state
    # 3. Kill Provider
    # 4. Let Docker Swarm start new provider 
    # 5. Add Data via provider
    # 6. Check that all instances have same state

    test_log "0. Reset Cluster"
    reset_cluster 1 1> /dev/null

    test_log "1. Add Data via provider"
    provider_tuple="$(get_all_provider)"
    PROVIDER_NODE=$(get_node "$provider_tuple")
    PROVIDER_ID=$(get_id "$provider_tuple")
    
    FIRST_INSERTED_ID=1
    add_entry $PROVIDER_NODE $PROVIDER_ID $FIRST_INSERTED_ID 1> /dev/null

    test_log "2. Check that all instances have same state"
    result=$(check_tables true)
    if [[ $result != true ]]; then
        >&2 test_log "$result"
        exit 1
    fi

    test_log "3. Kill Provider"
    kill_provider -c
    sleep 75s #Let slow hardware handle the "killing" and give time to docker & keepalived reevalute 
    update_id_ip_nodes

    test_log "4. Let Docker Swarm start new provider"
    wait_for_all_pg_to_boot
    reconnect_all_subscriber 

    test_log "5. Add Data via provider"
    provider_tuple="$(get_all_provider)"
    PROVIDER_NODE=$(get_node "$provider_tuple")
    PROVIDER_ID=$(get_id "$provider_tuple")

    SECOND_INSERTED_ID=2
    add_entry $PROVIDER_NODE $PROVIDER_ID $SECOND_INSERTED_ID 1> /dev/null

    test_log "6. Check that all instances have the new data"
    result=$(check_tables true)
    if [[ $result == true ]]; then
        test_log "Test 4 was successfull"
    else
        >&2 test_log "$result"
    fi
}

####### UPGRADE_TESTS


upgrade_provider(){
    # 1. Shutdown Provider Smart
    prov_tuple="$(get_all_provider)"
    prov_node=$(get_node "$prov_tuple")
    prov_id=$(get_id "$prov_tuple")
    $SSH_CMD root@$prov_node "docker exec $prov_id pg_ctl stop -m smart"
    # TODO expects that the provider is the last v9.5 db!
    scale_service "pg95_db" 0 1> /dev/null

    # 2. Adjust Cluster & Node Labels
    set_cluster_version 10.13

    # Beware that this only changes the node label of the provider node! 
    # This code,again, expects that the provider is the last v9.5 db!
    if [ "$prov_node" == "$dsn1_node" ]; then
        set_label_version 1 10
    elif [ "$prov_node" == "$dsn2_node" ]; then
        set_label_version 2 10
    elif [ "$prov_node" == "$dsn3_node" ]; then
        set_label_version 3 10
    fi

    # 3. Increase v10 Instance count by one.
    # TODO contains fixed number of 2!
    scale_service "pg10_db" 2
    update_id_ip_nodes
    sleep 30s
}

upgrade_subscriber(){
    sub=$(get_all_subscriber)
    sub_name=$(get_name "$sub")
    kill_subscriber "$sub_name" 
    sleep 5s
    sub_node=$(get_node "$sub")
    if [ "$sub_node" == "$dsn1_node" ]; then
        set_label_version 1 10
    elif [ "$sub_node" == "$dsn2_node" ]; then
        set_label_version 2 10
    elif [ "$sub_node" == "$dsn3_node" ]; then
        set_label_version 3 10
    fi
    update_id_ip_nodes
    sleep 30s
}

upgrade_test_1(){
    # Major Upgrade of running Subscriber
    # 0. Reset Cluster
    # 1. Add Data via provider
    # 2. Check that all instances have same state
    # 3. Upgrade Subscriber
    # 4. Check that Subscriber still has old data
    # 5. Add Data via provider
    # 6. Check that all instances have same state

    test_log "0. Reset Cluster"
    reset_cluster 1 1> /dev/null

    test_log "1. Add Data via provider"
    provider_tuple="$(get_all_provider)"
    PROVIDER_NODE=$(get_node "$provider_tuple")
    PROVIDER_ID=$(get_id "$provider_tuple")

    FIRST_INSERTED_ID=1
    add_entry $PROVIDER_NODE $PROVIDER_ID $FIRST_INSERTED_ID 1> /dev/null

    test_log "2. Check that all instances have same state"
    result=$(check_tables true)
    if [[ $result != true ]]; then
        >&2 echo "$result"
        exit 1
    fi

    test_log "3. Upgrade Subscriber"
    upgrade_subscriber

    test_log "4. Check that Subscriber has old data"
    result=$(check_tables true)
    if [[ $result != true ]]; then
        >&2 echo "$result"
        exit 1
    fi

    test_log "5. Add Data via provider"    
    SECOND_INSERTED_ID=2
    add_entry $PROVIDER_NODE $PROVIDER_ID $SECOND_INSERTED_ID 1> /dev/null

    test_log "6. Check that all instances have same state"
    result=$(check_tables true)
    if [[ $result == true ]]; then
        echo "Upgrade Test 1 was successfull"
    else
        >&2 echo "$result"
    fi
}

upgrade_test_2(){
    # Higher Provider, lower Subscriber, execute normal tests again? 
    echo "0"
}

upgrade_test_3(){
    # Lower Provider, higher Subscriber, execute normal tests again?
    echo "0"
}

update_cluster_version(){
    SSH_CMD_FOR_EACH_NODE "echo $1 > /etc/keepalived/cluster_version.txt"
}

upgrade_test_4(){
    # Major Update of Cluster
    #   - Phase 1
    #       - Decrease V9.5 service replica by one
    #       - Change a nodes label to "PG-V10-Node"
    #       - Insert new V10 Cluster Stack Service with 1 Replicas
    #       - Check if new V10 Instance in ready
    #   - Phase 2 <Skipped in this environment since we only have 1 Subscriber that is already V10>
    #   - Phase 3 
    #       - Decrease V9.5 service replica by one
    #       - Increase V10 service replicy by one
    #       - Change a nodes label to "PG-V10-Node"
    #       - Let Keepalived handle the failover
    #       - Let Docker handle the replica start
    #       - Reconnect all other subscribers <Skipped in this environment since we only have 1 Subscriber that became the provider and other replica already starting as subscriber with up-to-date connection>
    #       - Change the Keepalivd Dominate-Cluster-Version file to V10.

    test_log "0. Reset Cluster"
    reset_cluster 1 1> /dev/null

    test_log "1. Add Data via provider"
    provider_tuple="$(get_all_provider)"
    PROVIDER_NODE=$(get_node "$provider_tuple")
    PROVIDER_ID=$(get_id "$provider_tuple")

    FIRST_INSERTED_ID=1
    add_entry $PROVIDER_NODE $PROVIDER_ID $FIRST_INSERTED_ID 1> /dev/null

    test_log "2. Check that all instances have same state"
    result=$(check_tables true)
    if [[ $result != true ]]; then
        >&2 echo "$result"
        exit 1
    fi

    test_log "3. Upgrade Subscriber"
    upgrade_subscriber

    test_log "4. Check that all instances have same state"
    result=$(check_tables true)
    if [[ $result != true ]]; then
        >&2 echo "$result"
        exit 1
    fi

    test_log "5. Upgrade Provider"
    upgrade_provider

    test_log "6. Add Sample data via new provider"
    provider_tuple="$(get_all_provider)"
    PROVIDER_NODE=$(get_node "$provider_tuple")
    PROVIDER_ID=$(get_id "$provider_tuple")

    FIRST_INSERTED_ID=2
    add_entry $PROVIDER_NODE $PROVIDER_ID $FIRST_INSERTED_ID 1> /dev/null

    test_log "7. Check that all instances have same state"
    get_table $(get_name "$provider_tuple")
    result=$(check_tables true)
    if [[ $result == true ]]; then
        echo "Upgrade Test 4 was successfull"
    else
        >&2 echo "$result"
    fi
}


