#!/bin/sh
# This script is meant to be "sourced"

# This script represents an internal abstract data type (ADT). 
# It saves the important infos about running Postgres instances in the Cluster in tuples containing:
#   - Postgres Container Name
#   - Postgres Role (prov / sub)
#   - Container ID
#   - Container IP in the 'pgnet' network
#   - Docker Swarm Node the container is running on
#   - Postgres Major Version (9.5 / 10)
# id,ip,nodes are not allowed to have spaces in their names!
# Example: "db1(prov):containerid,containerip,vmnode,version db2(sub):..."

ID_IP_NODEs=""

# get_name returns the Postgres Container name of a given tuple
# $1 = tuple
# Context: TEST, UPGRADE
get_name() {
    id_ip_node_tuple="$1"
    IFS=':' read current_name current_info <<<"${id_ip_node_tuple}"
    echo $current_name
}

# get_role returns the Postgres role of a given tuple
# $1 = tuple
# Context: TEST, UPGRADE
get_role() {
    id_ip_node_tuple="$1"
    IFS=':' read current_name current_info <<<"${id_ip_node_tuple}"
    IFS=',' read current_role current_id current_ip current_node current_version <<<"${current_info}"
    echo $current_role
}

# get_id returns the Postgres Container ID of a given tuple
# $1 = tuple
# Context: TEST, UPGRADE
get_id() {
    id_ip_node_tuple="$1"
    IFS=':' read current_name current_info <<<"${id_ip_node_tuple}"
    IFS=',' read current_role current_id current_ip current_node current_version <<<"${current_info}"
    echo $current_id
}

# get_ip returns the Postgres IP of a given tuple
# $1 = tuple
# Context: TEST, UPGRADE
get_ip() {
    id_ip_node_tuple="$1"
    IFS=':' read current_name current_info <<<"${id_ip_node_tuple}"
    IFS=',' read current_role current_id current_ip current_node current_version <<<"${current_info}"
    echo $current_ip
}

# get_node returns the Docker Swarm node of a given tuple
# $1 = tuple
# Context: TEST, UPGRADE
get_node() {
    id_ip_node_tuple="$1"
    IFS=':' read current_name current_info <<<"${id_ip_node_tuple}"
    IFS=',' read current_role current_id current_ip current_node current_version <<<"${current_info}"
    echo $current_node
}

# get_version returns the Postgres Major Version of a given tuple
# $1 = tuple
# Context: TEST, UPGRADE
get_version() {
    id_ip_node_tuple="$1"
    IFS=':' read current_name current_info <<<"${id_ip_node_tuple}"
    IFS=',' read current_role current_id current_ip current_node current_version <<<"${current_info}"
    echo $current_version
}

# get_tuple_from_name returns the tuple of the given Postgres Container name. Will return "" if none found.
# $1 = tuple
# Context: TEST, UPGRADE
get_tuple_from_name() {
    for tuple in $ID_IP_NODEs; do
        current_name=$(get_name "$tuple")
        if [[ $current_name == $1 ]]; then
            echo $tuple
        fi
    done
}

# get_all_tuples returns all tuples seperated by spaces.
# Context: TEST, UPGRADE
get_all_tuples(){
    echo "$ID_IP_NODEs"
}

# get_tuples_count returns the tuple count.
# Context: TEST, UPGRADE
get_tuples_count(){
    echo "$ID_IP_NODEs" | wc -w
}

# get_all_provider returns all provider tuples seperated by spaces.
# Context: TEST, UPGRADE
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

# get_all_subscriber returns all subscriber tuples seperated by spaces.
# Context: TEST, UPGRADE
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

# determine_role determines the Postgres role (Provider / Subscriber) of a given Container on a given host
# $1 = Docker Swarm Node hostname
# $2 = Postgres Container ID
# Context: SETUP, TEST, UPGRADE
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

# extract_db_version extracts the Postgres major version of a given SQL output.
# $1 = SQL Output for 'SELECT version();'
# Context: SETUP, TEST, UPGRADE
extract_db_version() {
    arr=($1)
    echo "${arr[3]}"
}

# determine_db_version determines the Postgres major version oof a given Container on a given host
# $1 = Docker Swarm Node hostname
# $2 = Postgres Container ID
# Context: SETUP, TEST, UPGRADE
determine_db_version() {
    result_raw="$(execute_sql $1 $2 'SELECT version();' 2>/dev/null)"
    result=$(extract_db_version "$result_raw")
    if [ -z "$result" ]; then
        result="err"
    fi
    echo $result
}

# update_id_ip_nodes updates this ADT to the current state
# Context: SETUP, TEST, UPGRADE
update_id_ip_nodes() {
    ID_IP_NODEs=""
    for node in $all_nodes; do
        info_no=0
        running_containers=$(gather_running_containers root@$node)
        for info in $running_containers; do
            if [ "$info_no" -gt "2" ]; then
                if [ $((info_no % 2)) == 1 ]; then
                    current_id=$info
                else
                    current_name=${info:0:9} #pg_dbVV.X where VV = version (10 / 95) and X = replica number (0-9)
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

# print_id_ip_nodes prints the current state of this ADT.
# Context: SETUP, TEST, UPGRADE
print_id_ip_nodes() {
    current_sub_count=0 
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
