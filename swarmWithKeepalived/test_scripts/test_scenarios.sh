# !/bin/sh
# This is meant to be 'sourced' from test_client_lib.sh!

# TESTSCENARIOS
# Expecting 1 Provider 1 and  Subscriber with name "subscriber.1"
################

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
        # TODO What if there are two Providers? Check that case too
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
        sub_exists_count=$((sub_exists_count+1))
    done

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
    reset_cluster 1 1> /dev/null

    # 1. - 4.
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
    echo "0. Reset Cluster"
    reset_cluster 0 1> /dev/null

    # 1.
    echo "1. Add Data via provider"
    provider_tuple="$(get_all_provider)"
    PROVIDER_NODE=$(get_node "$provider_tuple")
    PROVIDER_ID=$(get_id "$provider_tuple")

    #CURRENT_INFO=$(get_node_and_id_from_name db_i)
    #IFS=',' read PROVIDER_NODE PROVIDER_ID <<< "${CURRENT_INFO}"
    FIRST_INSERTED_ID=1
    add_entry $PROVIDER_NODE $PROVIDER_ID $FIRST_INSERTED_ID 1> /dev/null

    # 2.
    echo "2. Start new subscriber"
    start_new_subscriber 1> /dev/null
    update_id_ip_nodes

    # 3.
    echo "3. Add Data via provider"
    SECOND_INSERTED_ID=2
    add_entry $PROVIDER_NODE $PROVIDER_ID $SECOND_INSERTED_ID 1> /dev/null
    sleep 5s # For older hardware

    # 4.
    echo "4. Check if subscriber has both datasets"
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
    # 3. Remove all data from subscribers #TODO neccessary to have more than one sub?
    # 4. Kill Provider
    # 5. Let Docker Swarm start new provider #TODO and keepalived
    # 6. Add Data via provider
    # 7. Check that all instances have the new data

    echo "0. Reset Cluster"
    reset_cluster 1 1> /dev/null

    echo "1. Add Data via provider"
    provider_tuple="$(get_all_provider)"
    PROVIDER_NODE=$(get_node "$provider_tuple")
    PROVIDER_ID=$(get_id "$provider_tuple")

    add_entry $PROVIDER_NODE $PROVIDER_ID $FIRST_INSERTED_ID 1> /dev/null

    echo "2. Check that all instances have same state"
    result=$(check_tables true)
    if [[ $result != true ]]; then
        >&2 echo "$result"
        exit 1
    fi

    echo "3. Remove all data from subscribers"
    clear_all_local_tables 1> /dev/null

    echo "4. Kill Provider"
    kill_provider -c
    update_id_ip_nodes

    echo "5. Let Docker Swarm start new provider"
    wait_for_all_pg_to_boot
    reconnect_all_subscriber

    echo "6. Add Data via provider"
    provider_tuple="$(get_all_provider)"
    PROVIDER_NODE=$(get_node "$provider_tuple")
    PROVIDER_ID=$(get_id "$provider_tuple")
    
    #CURRENT_INFO=$(get_node_and_id_from_name db_i)
    #IFS=',' read PROVIDER_NODE PROVIDER_ID <<< "${CURRENT_INFO}"
    SECOND_INSERTED_ID=2
    add_entry $PROVIDER_NODE $PROVIDER_ID $SECOND_INSERTED_ID 1> /dev/null

    echo "7. Check that all instances have the new data"
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
    # 4. Let Docker Swarm start new provider #TODO and keepalived
    # 5. Add Data via provider
    # 6. Check that all instances have same state

    echo "0. Reset Cluster"
    reset_cluster 1 1> /dev/null

    echo "1. Add Data via provider"
    provider_tuple="$(get_all_provider)"
    PROVIDER_NODE=$(get_node "$provider_tuple")
    PROVIDER_ID=$(get_id "$provider_tuple")
    
    #CURRENT_INFO=$(get_node_and_id_from_name db_i)
    #IFS=',' read PROVIDER_NODE PROVIDER_ID <<< "${CURRENT_INFO}"
    FIRST_INSERTED_ID=1
    add_entry $PROVIDER_NODE $PROVIDER_ID $FIRST_INSERTED_ID 1> /dev/null

    echo "2. Check that all instances have same state"
    result=$(check_tables true)
    if [[ $result != true ]]; then
        >&2 echo "$result"
        exit 1
    fi

    echo "3. Kill Provider"
    kill_provider -c

    echo "4. Let Docker Swarm start new provider"
    wait_for_all_pg_to_boot
    reconnect_all_subscriber

    echo "5. Add Data via provider"
    provider_tuple="$(get_all_provider)"
    PROVIDER_NODE=$(get_node "$provider_tuple")
    PROVIDER_ID=$(get_id "$provider_tuple")

    #CURRENT_INFO=$(get_node_and_id_from_name db_i)
    #IFS=',' read PROVIDER_NODE PROVIDER_ID <<< "${CURRENT_INFO}"
    SECOND_INSERTED_ID=2
    add_entry $PROVIDER_NODE $PROVIDER_ID $SECOND_INSERTED_ID 1> /dev/null

    echo "6. Check that all instances have the new data"
    result=$(check_tables true)
    if [[ $result == true ]]; then
        echo "Test 4 was successfull"
    else
        >&2 echo "$result"
    fi
}