#!/bin/sh
# This script is meant to be "sourced"

# id,ip,nodes are not allowed to have spaces in their names!
# Example: "db1(prov):containerid,containerip,vmnode,version db2(sub):..."
ID_IP_NODEs=""

get_name() {
    id_ip_node_tuple="$1"
    IFS=':' read current_name current_info <<<"${id_ip_node_tuple}"
    echo $current_name
}

get_role() {
    id_ip_node_tuple="$1"
    IFS=':' read current_name current_info <<<"${id_ip_node_tuple}"
    IFS=',' read current_role current_id current_ip current_node current_version <<<"${current_info}"
    echo $current_role
}

get_id() {
    id_ip_node_tuple="$1"
    IFS=':' read current_name current_info <<<"${id_ip_node_tuple}"
    IFS=',' read current_role current_id current_ip current_node current_version <<<"${current_info}"
    echo $current_id
}

get_ip() {
    id_ip_node_tuple="$1"
    IFS=':' read current_name current_info <<<"${id_ip_node_tuple}"
    IFS=',' read current_role current_id current_ip current_node current_version <<<"${current_info}"
    echo $current_ip
}

get_node() {
    id_ip_node_tuple="$1"
    IFS=':' read current_name current_info <<<"${id_ip_node_tuple}"
    IFS=',' read current_role current_id current_ip current_node current_version <<<"${current_info}"
    echo $current_node
}

get_version() {
    id_ip_node_tuple="$1"
    IFS=':' read current_name current_info <<<"${id_ip_node_tuple}"
    IFS=',' read current_role current_id current_ip current_node current_version <<<"${current_info}"
    echo $current_version
}

get_tuple_from_name() {
    for tuple in $ID_IP_NODEs; do
        current_name=$(get_name "$tuple")
        if [[ $current_name == $1 ]]; then
            echo $tuple
        fi
    done
}

get_node_and_id_from_name() {
    for tuple in $ID_IP_NODEs; do
        current_name=$(get_name "$tuple")
        if [[ $current_name == $1 ]]; then
            current_node=$(get_node "$tuple")
            current_id=$(get_id "$tuple")
            echo "$current_node,$current_id"
            break
        fi
    done
}

get_all_provider() {
    result=""
    for tuple in $ID_IP_NODEs; do
        current_role=$(get_role "$tuple")
        if [[ $current_role == "prov" ]]; then
            result="$result $tuple"
        fi
    done
    echo $result
}

get_all_subscriber() {
    result=""
    for tuple in $ID_IP_NODEs; do
        current_role=$(get_role "$tuple")
        if [[ $current_role == "sub" ]]; then
            result="$result $tuple"
        fi
    done
    echo $result
}

determine_role() {
    result_raw="$(execute_sql $1 $2 'SELECT * FROM pglogical.pglogical_node_info();' 2>/dev/null)"
    result="sub"
    if [ -z "$result_raw" ]; then
        result="err"
    elif [[ "$result_raw" == *provider* ]]; then
        result="prov"
    fi
    echo $result
}

extract_db_version() {
    arr=($1)
    echo "${arr[3]}"
}

determine_db_version() {
    result_raw="$(execute_sql $1 $2 'SELECT version();' 2>/dev/null)"
    result=$(extract_db_version "$result_raw")
    if [ -z "$result" ]; then
        result="err"
    fi
    echo $result
}

update_id_ip_nodes() {
    ID_IP_NODEs=""
    for node in $ALL_NODES; do
        info_no=0
        running_containers=$(gather_running_containers root@$node)
        for info in $running_containers; do
            if [ "$info_no" -gt "2" ]; then
                if [ $((info_no % 2)) == 1 ]; then
                    current_id=$info
                else
                    current_name=${info:0:9}
                    current_ip=""
                    
                    if [[ $info == pg95_db* ]]; then
                        current_ip=$($SSH_CMD root@$node docker inspect -f '{{.NetworkSettings.Networks.pg95_pgnet.IPAddress}}' $current_id)
                    elif [[ $info == pg10_db* ]]; then
                        current_ip="$($SSH_CMD root@$node docker inspect -f '{{.NetworkSettings.Networks.pg10_pgnet.IPAddress}}' $current_id)"
                    fi

                    if ! [ -z "$current_ip" ]; then
                        current_role=$(determine_role $node $current_id)
                        current_db_version="$(determine_db_version $node $current_id)"
                        ID_IP_NODEs="$ID_IP_NODEs $current_name:$current_role,$current_id,'$current_ip',$node,$current_db_version"
                    fi
                fi
            fi
            info_no=$((info_no + 1))
        done
    done
}

print_id_ip_nodes() {
    # TODO somehow V10 instances ID are check in the wrong context I guess leading to a print out of "Error: no such object: <containerid>"
    # Print Container IP, IP and Node of Provider and Subscribers
    # Test: To Confirm which Containers are running where.

    current_sub_count=0 # Adjust Count, maybe this is executed in a new ./setup.sh process than the one before.

    for tuple in $ID_IP_NODEs; do
        current_name=$(get_name "$tuple")
        if [[ $current_name == *_db.* ]]; then
            current_sub_count=$(($current_sub_count + 1))
        fi
        current_role=$(get_role "$tuple")
        current_id=$(get_id "$tuple")
        current_ip=$(get_ip "$tuple")
        current_node=$(get_node "$tuple")
        current_version=$(get_version "$tuple")
        echo "$current_name: Role($current_role) ID($current_id) IP($current_ip) Node($current_node) Version($current_version)"
    done
    echo "Current instances count: $current_sub_count"
}
