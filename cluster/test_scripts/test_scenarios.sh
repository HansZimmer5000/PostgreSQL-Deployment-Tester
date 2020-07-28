# !/bin/sh
# This is meant to be 'sourced' from test_client_lib.sh!

test_log(){
    echo "$(date) $@"
}

# TESTSCENARIOS
# Expecting 1 Provider 1 and Subscriber"
################

# Param 1 = v95 Instances
# Param 2 = v10 Instances
reset_labels(){
    current_v95_node_num=1
    while [ "$current_v95_node_num" -le "$1" ]; do
        set_label_version $current_v95_node_num 9.5
        current_v95_node_num=$(($current_v95_node_num+1))
    done

    node_num_offset=$(($current_v95_node_num-1))
    current_v10_node_num=1
    while [ "$current_v10_node_num" -le "$2" ]; do
        set_label_version $(($current_v10_node_num+$node_num_offset)) 10
        current_v10_node_num=$(($current_v10_node_num+1))
    done
}

# Expecting v9.5 Subscriber count as Param1, default is 1
# Expecting v10 Subscriber count as Param2, default is 0
# Expecting if Provider should be v10, default is false (v9.5)
reset_cluster(){
    update_id_ip_nodes

    v95_instances=0
    v10_instances=0
    cluster_version="9.5.18"

    if [ "$3" == "true" ]; then
        cluster_version="10.13"
        v10_instances=1
    else
        v95_instances=1
    fi
    set_cluster_version "$cluster_version"

    if ! [ -z "$1" ]; then
        v95_instances=$(($v95_instances+$1))
    fi

    if ! [ -z "$2" ]; then
        v10_instances=$(($v10_instances+$2))
    fi

    if [ $(($v95_instances + $v10_instances)) -gt $(echo $ALL_NODES | wc -w) ]; then
        test_log "Aborting due to more instances wanted ($v95_instances + $v10_instances) than nodes $(echo $ALL_NODES | wc -w)"!
        exit 1
    fi

    reset_labels $v95_instances $v10_instances

    kill_provider -c

    scale_service "pg95_db" $v95_instances 1> /dev/null
    scale_service "pg10_db" $v10_instances 1> /dev/null
    
    # Wait till everything is up. 30s is an abitrary number!
    sleep 30s

    update_id_ip_nodes
    clear_all_local_tables
    reconnect_all_subscriber
}

# TODO add extra reset tests with params
#   - 0 0 false
#   - 1 0 false
#   - 0 1 false
#   - 0 0 true
#   - 1 0 true
#   - 0 1 true
#   - 1 1 true -> In a environment with only two nodes, this should fail because instance_count > node_count!
# TODO change normal tests ("test_*" functions) so, that they can get executed on the current running environment and then combine multiple environments (see above) with all the normal tests.

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


