# !/bin/sh
# This is meant to be 'sourced' from test_client_lib.sh!

# Expecting Subscriber count as Param1, default is 1
reset_cluster(){
    sub_count=1
    if ! [ -z "$1" ]; then
        if [ "$1" -ge 0 ]; then
            sub_count=$1
        fi
    fi

    echo "Reseting Cluster with $sub_count Subscriber"
    update_id_ip_nodes

    # check if provider exists
    provider_exists=false
    sub_exists_count=0

    for tuple in $ID_IP_NODEs 
    do
        current_role=$(get_role "$tuple")
        if [[ $current_role == "prov" ]] && ! $provider_exists; then
            provider_exists=true
        elif [[ $current_role == "prov" ]] && $provider_exists; then
            echo "There are multiple providers in the cluster!"
            exit 1
        elif [[ $current_role == "sub" ]] && [ $sub_exists_count -lt $sub_count ]; then
            sub_exists_count=$((sub_exists_count+1))
        else
            current_name=$(get_name "$tuple")
            current_number=${current_name:3:1}
            echo "removing db.$current_number"
            kill_subscriber "$current_number" 1> /dev/null
        fi
    done

    if ! $provider_exists; then
        start_new_subscriber
    fi

    while [ $sub_exists_count -lt $sub_count ]; do
        start_new_subscriber
        sleep 15s #Wait for older Hardware to start subscriber
        sub_exists_count=$((sub_exists_count+1))
    done

    update_id_ip_nodes
    clear_all_local_tables
    reconnect_all_subscriber
}

test_log(){
    test_log "$1"
}

# TESTSCENARIOS
# Expecting 1 Provider 1 and  Subscriber with name "subscriber.1"
################

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
    start_new_subscriber 1> /dev/null
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
        echo "Test 2 was successfull"
    else
        >&2 echo "$result"
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
        >&2 echo "$result"
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
        echo "Test 3 was successfull"
    else
        >&2 echo "$result"
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
        >&2 echo "$result"
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
        echo "Test 4 was successfull"
    else
        >&2 echo "$result"
    fi
}

####### UPGRADE_TESTS

upgrade_test_1(){
    # Major Upgrade of running Subscriber
    # 0. Reset Cluster
    # 1. Add Data via provider
    # 2. Check that all instances have same state
    # 3. Stop Subscriber
    # 4. Update Subscriber
    # 5. Restart updated Subscriber
    # 6. Check that Subscriber still has old data
    # 7. Add Data via provider
    # 8. Check that all instances have same state

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

    test_log "3. Stop Subscriber"
    # We can do the following command since after "reset_cluster" only one sub is active.
    sub_tuple=$(get_all_subscriber)
    sub_name=$(get_name "$sub_tuple")
    sub_number=${sub_name:3}
    sub_node=$(get_node "$sub_tuple")
    kill_subscriber $sub_number 1> /dev/null

    $SSH_CMD root@$MANAGER_NODE "docker stack deploy -c stack_upgraded.yml pgup"

    test_log "4. Update Subscriber"
    todo
    # Label all nodes so that sub_node will be updated
    # Check that volume paths from both stacks file match what volume update expects!
    # Execute volume updater on sub_node

    test_log "5. Restart updated Subscriber"
    todo
    # Start new Subscriber on sub_node

    test_log "6. Check that Subscriber still has old data"
    result=$(check_tables true)
    if [[ $result != true ]]; then
        >&2 echo "$result"
        exit 1
    fi

    test_log "7. Add Data via provider"
    todo

    test_log "8. Check that all instances have same state"
    result=$(check_tables true)
    if [[ $result != true ]]; then
        >&2 echo "$result"
        exit 1
    fi

    echo "0"
}

upgrade_test_2(){
    # Higher Provider, lower Subscriber, execute normal tests again? 
    echo "0"
}

upgrade_test_3(){
    # Lower Provider, higher Subscriber, execute normal tests again?
    echo "0"
}

upgrade_test_4(){
    # Major Update of Cluster (How much downtime?)
    #   - Update Subscriber
    #   - Promote Subscriber
    #   - Update Provider
    #   - Degrade Provider
    echo "0"
}

 



