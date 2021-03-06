# !/bin/sh
# This is meant to be 'sourced' from test_client.sh!

test_log(){
    echo "$(date) $@"
}

get_node_count(){
    echo $all_nodes | wc -w
}

# TESTSCENARIOS
# Expecting 1 Provider 1 and Subscriber"
################

# Expecting v9.5 Subscriber count as Param1, default is 1
# Expecting v10 Subscriber count as Param2, default is 0
# Expecting if Provider should be v10, default is false
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

    if [ $(($v95_instances + $v10_instances)) -gt $(get_node_count) ]; then
        test_log "Aborting due to more instances wanted ($v95_instances + $v10_instances) than nodes $(get_node_count)"!
        exit 1
    fi

    test_log Reset Cluster with $v95_instances v9.5 instances and $v10_instances v10 instances
    set_v95_and_v10_labels $v95_instances $v10_instances

    # Make sure the provider will be in the right version (docker swarm does not differentiate which version the postgres is running and changing of cluster version currently does not intefere with the running instances)
    kill_provider 1> /dev/null

    test_log Setting v9.5 service to $v95_instances replicas
    scale_service_with_timeout "pg95_db" $v95_instances 1> /dev/null

    test_log Setting v10 service to $v10_instances replicas
    scale_service_with_timeout "pg10_db" $v10_instances 1> /dev/null
    
    # Wait till everything is up. 30s is an abitrary number!
    sleep 30s

    update_id_ip_nodes
    if ! [ $(get_tuples_count) -eq $(($v95_instances+$v10_instances)) ]; then
        test_log Error, not the expected amount of instances is active!
        exit 1
    fi
    clear_all_local_tables
    reconnect_all_subscriber
}

# TODO change normal tests ("test_*" functions) so, that they can get executed on the current running environment and then combine multiple environments (see above) with all the normal tests. But Beware, not every environment may be suited for specific test scenarios!
# TODO paint success / fail in green / red after test.
# TODO make logging of tests more abstract (f.e. "scenario (1) reset params (0 0 false): success") and may add a log file for further debugging
# TODO when there were 1 v95 sub and 1 v95 prov, both had VIP, eventhough one notify_log showed that it did everything correctly. What happened?
all_reset_params=("0 0 false" "1 0 false" "0 1 false" "0 0 true" "1 0 true" "0 1 true")
all_reset_params_with_subscriber=("1 0 false" "0 1 false" "1 0 true" "0 1 true")

execute_test_scenario_for_all_clusters(){
    for reset_param in "${all_reset_params[@]}"; do
        test_log Testscenario "'$1'" with reset params: $reset_param
        reset_cluster $reset_param
        $1
    done
}

execute_test_scenario_for_subscriber_clusters(){
    for reset_param in "${all_reset_params_with_subscriber[@]}"; do
        test_log Testscenario "'$1'" with reset params: $reset_param
        reset_cluster $reset_param
        $1
    done
}

test_1(){
    execute_test_scenario_for_all_clusters test_scenario_1
}

test_2(){
    execute_test_scenario_for_subscriber_clusters test_scenario_2
}

test_3(){
    execute_test_scenario_for_subscriber_clusters test_scenario_3
}

test_4(){
    execute_test_scenario_for_subscriber_clusters test_scenario_4
}

test_scenario_1(){
    # Check if roles and replications are set correctly
    # 1. Add Data via provider
    # 2. Check that all instances have same state
    # 3. Remove all data from all instances
    # 4. For each subscriber: 
    #   1. Add Data via subscriber
    #   2. Check that only this subscriber has new data

    # 1. - 4.
    test_log "1.-4. Check instance roles"
    # TODO add success checking!
    check_roles
}

test_scenario_2(){
    # Check if new subscriber gets old and new data.
    # 0. Reset Cluster
    # 1. Add Data via provider
    # 2. Start new subscriber
    # 3. Add Data via provider
    # 4. Check if subscriber has both datasets

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

test_scenario_3(){
    # Check if new provider actually gets recognized as new provider
    # 0. Reset Cluster
    # 1. Add Data via provider
    # 2. Check that all instances have same state
    # 3. Remove all data from subscribers 
    # 4. Kill Provider
    # 5. Let Docker Swarm start new provider 
    # 6. Add Data via provider
    # 7. Check that all instances have the new data

    #test_log "0. Reset Cluster"
    #reset_cluster 1 1> /dev/null

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

test_scenario_4(){
    # Check if new provider has old data
    # 0. Reset Cluster
    # 1. Add Data via provider
    # 2. Check that all instances have same state
    # 3. Kill Provider
    # 4. Let Docker Swarm start new provider 
    # 5. Add Data via provider
    # 6. Check that all instances have same state

    #test_log "0. Reset Cluster"
    #reset_cluster 1 1> /dev/null

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
    sub=$(get_all_subscriber)
    sub_name=$(get_name "$sub")
    upgrade_subscriber $sub_name 1

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
    sub=$(get_all_subscriber)
    sub_name=$(get_name "$sub")
    upgrade_subscriber $sub_name 1

    test_log "4. Check that all instances have same state"
    result=$(check_tables true)
    if [[ $result != true ]]; then
        >&2 echo "$result"
        exit 1
    fi

    test_log "5. Upgrade Provider"
    upgrade_provider 2

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
        echo "Upgrade Test 2 was successfull"
    else
        >&2 echo "$result"
    fi
}


