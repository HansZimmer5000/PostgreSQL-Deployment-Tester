#!/bin/sh
# This script is meant to be "sourced"
# TODO: Currently this does not work if not sourced by setup.sh (directly or indirectly)!

# id,ip,nodes are not allowed to have spaces in their names!
# Example: "db1(prov):containerid,containerip,vmnode db2(sub):..."
ID_IP_NODEs="" 

get_name(){
    id_ip_node_tuple="$1"
    IFS=':' read CURRENT_NAME CURRENT_INFO <<< "${id_ip_node_tuple}"
    echo $CURRENT_NAME
}

get_role(){
    id_ip_node_tuple="$1"
    IFS=':' read CURRENT_NAME CURRENT_INFO <<< "${id_ip_node_tuple}"
    IFS=',' read CURRENT_ROLE CURRENT_ID CURRENT_IP CURRENT_NODE <<< "${CURRENT_INFO}"
    echo $CURRENT_ROLE
}

get_id(){
    id_ip_node_tuple="$1"
    IFS=':' read CURRENT_NAME CURRENT_INFO <<< "${id_ip_node_tuple}"
    IFS=',' read CURRENT_ROLE CURRENT_ID CURRENT_IP CURRENT_NODE <<< "${CURRENT_INFO}"
    echo $CURRENT_ID
}

get_ip(){
    id_ip_node_tuple="$1"
    IFS=':' read CURRENT_NAME CURRENT_INFO <<< "${id_ip_node_tuple}"
    IFS=',' read CURRENT_ROLE CURRENT_ID CURRENT_IP CURRENT_NODE <<< "${CURRENT_INFO}"
    echo $CURRENT_IP
}

get_node(){
    id_ip_node_tuple="$1"
    IFS=':' read CURRENT_NAME CURRENT_INFO <<< "${id_ip_node_tuple}"
    IFS=',' read CURRENT_ROLE CURRENT_ID CURRENT_IP CURRENT_NODE <<< "${CURRENT_INFO}"
    echo $CURRENT_NODE
}

get_tuple_from_name(){
    for tuple in $ID_IP_NODEs 
    do
        CURRENT_NAME=$(get_name "$tuple")
        if [[ $CURRENT_NAME == $1 ]]; then
            echo $tuple
        fi
    done
}

get_node_and_id_from_name(){
    for tuple in $ID_IP_NODEs 
    do
        CURRENT_NAME=$(get_name "$tuple")
        if [[ $CURRENT_NAME == $1 ]]; then
            CURRENT_NODE=$(get_node "$tuple")
            CURRENT_ID=$(get_id "$tuple")
            echo "$CURRENT_NODE,$CURRENT_ID"
            break
        fi
    done
}

get_all_provider(){
    result=""
    for tuple in $ID_IP_NODEs 
    do
        current_role=$(get_role "$tuple")
        if [[ $current_role == "prov" ]]; then
            result="$result $tuple"
        fi
    done
    echo $result
}

get_all_subscriber(){
    result=""
    for tuple in $ID_IP_NODEs 
    do
        current_role=$(get_role "$tuple")
        if [[ $current_role == "sub" ]]; then
            result="$result $tuple"
        fi
    done
    echo $result
}

determine_role(){
    # pglogical.show_subscription_status() --> if >0 shows that subscriber
    # SELECT * FROM pg_replication_slots; --> if >0 shows that provider
    # pglogical.pglogical_node_info() --> shows what nodes are active, if "provider" -> provider
    
    res="$(execute_sql $1 $2 'SELECT * FROM pglogical.pglogical_node_info();')"
    rows=$( echo "$res" | grep "provider")
    if [[ "$rows" == *provider* ]]; then
        echo "prov"
    else 
        echo "sub"
    fi
}

update_id_ip_nodes(){
    ID_IP_NODEs=""
    for node in $ALL_NODES; do 
        INFO_NO=0
        RUNNING_CONTAINERS=$(gather_running_containers root@$node)
        for info in $RUNNING_CONTAINERS; do
            if [ "$INFO_NO" -gt "2" ]; then
                if [ $((INFO_NO % 2)) == 1 ]; then
                    CURRENT_ID=$info
                else 
                    if [[ $info == pg_db* ]]; then
                        CURRENT_NAME=${info:3:4}
                        CURRENT_IP=$($SSH_CMD root@$node docker inspect -f '{{.NetworkSettings.Networks.pg_pgnet.IPAddress}}' $CURRENT_ID)
                        if [ "$CURRENT_IP" == "<no value>" ]; then
                            # This happens only for the init_helper instance as it has no ingress port! And init_helper must be provider so, set the Virtual IP.
                            CURRENT_IP="192.168.99.149"
                        fi
                        CURRENT_ROLE=$(determine_role $node $CURRENT_ID)
                        ID_IP_NODEs="$ID_IP_NODEs $CURRENT_NAME:$CURRENT_ROLE,$CURRENT_ID,$CURRENT_IP,$node"
                    fi
                fi
            fi
            INFO_NO=$((INFO_NO+1))
        done
    done
}

print_id_ip_nodes(){
    # Print Container IP, IP and Node of Provider and Subscribers
    # Test: To Confirm which Containers are running where.

    CURRENT_SUB_COUNT=0 # Adjust Count, maybe this is executed in a new ./setup.sh process than the one before.

    for tuple in $ID_IP_NODEs 
    do
        CURRENT_NAME=$(get_name "$tuple")
        if [[ $CURRENT_NAME == db.* ]]; then
            CURRENT_SUB_COUNT=$(($CURRENT_SUB_COUNT + 1))
        fi
        CURRENT_ROLE=$(get_role "$tuple")
        CURRENT_ID=$(get_id "$tuple")
        CURRENT_IP=$(get_ip "$tuple")
        CURRENT_NODE=$(get_node "$tuple")
        echo "$CURRENT_NAME: Role($CURRENT_ROLE) ID($CURRENT_ID) IP($CURRENT_IP) Node($CURRENT_NODE)"
    done
    echo "Current subscriber count: $CURRENT_SUB_COUNT"
}
