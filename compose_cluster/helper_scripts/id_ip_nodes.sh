#!/bin/sh

determine_role() {
    result_raw="$(execute_sql $1 'SELECT * FROM pglogical.pglogical_node_info();' 2>/dev/null)"
    result="sub"
    if [ -z "$result_raw" ]; then
        result="err"
    elif [[ "$result_raw" == *provider* ]]; then
        result="prov"
    fi
    echo $result
}

determine_db_version() {
    result_raw="$(execute_sql $1 'SELECT version();' 2>/dev/null)"
    result=$(extract_db_version "$result_raw")
    if [ -z "$result" ]; then
        result="err"
    fi
    echo $result
}

extract_db_version() {
    arr=($1)
    echo "${arr[3]}"
}

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

get_version() {
    id_ip_node_tuple="$1"
    IFS=':' read current_name current_info <<<"${id_ip_node_tuple}"
    IFS=',' read current_role current_id current_ip current_node current_version <<<"${current_info}"
    echo $current_version
}

update_id_ip_nodes() {
    ID_IP_NODEs=""
    running_containers=$(gather_running_containers)
    info_no=0
    for info in $running_containers; do
        if [ "$info_no" -gt "2" ]; then
            if [ $((info_no % 2)) == 1 ]; then
                current_id=$info
            elif [[ $info == stacks_db* ]]; then
                current_name=${info:0:13} #stacks_dbVV.X where VV = version (10 / 95) and X = replica number (0-9) # TODO name ggf. ganz anders und länger! 
                current_ip=""
                
                # TODO BEWARE network name changed from pgVV_pgnet to stacks_pgnet! Important for f.e. update_id_ip_nodes to get IP 
                current_ip=$(docker inspect -f '{{.NetworkSettings.Networks.stacks_pgnet.IPAddress}}' $current_id)

                if ! [ -z "$current_ip" ]; then
                    current_role=$(determine_role $current_id)
                    current_db_version="$(determine_db_version $current_id)"
                    ID_IP_NODEs="$ID_IP_NODEs $current_name:$current_role,$current_id,'$current_ip',$node,$current_db_version"
                fi
            fi
        fi
        info_no=$((info_no + 1))
    done
}

print_id_ip_nodes() {
    for tuple in $ID_IP_NODEs; do
        current_name=$(get_name "$tuple")
        current_role=$(get_role "$tuple")
        current_id=$(get_id "$tuple")
        current_ip=$(get_ip "$tuple")
        current_version=$(get_version "$tuple")
        echo "$current_name: Role($current_role) ID($current_id) IP($current_ip) Version($current_version)"
    done
}

get_tuple_from_name() {
    for tuple in $ID_IP_NODEs; do
        current_name=$(get_name "$tuple")
        if [[ $current_name == $1 ]]; then
            echo $tuple
        fi
    done
}

get_all_tuples(){
    echo "$ID_IP_NODEs"
}

# get_tuples_count returns the tuple count.
# Context: TEST, UPGRADE
get_tuples_count(){
    echo "$ID_IP_NODEs" | wc -w
}