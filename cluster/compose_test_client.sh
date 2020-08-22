#!/bin/sh

gather_running_containers() {
    docker ps --format "table {{.ID}}\t{{.Names}}"
}

execute_sql() {
    docker exec $1 psql -v ON_ERROR_STOP=1 --username postgres --dbname testdb -c "$2"
}

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

stop_pg_container(){
    tuple=$(get_tuple_from_name $1)
    id=$(get_id $tuple)
    echo $tuple
    
    if [ "$2" == "smart" ]; then
        docker exec $id pg_ctl stop -m smart
    else
        docker rm -f $id
    fi
}

get_all_tuples(){
    echo "$ID_IP_NODEs"
}

get_service_scale(){
    scale=0
    for tuple in $(get_all_tuples); do
        if [[ "$tuple" == *"$1"* ]]; then
            scale=$(($scale+1))
        fi
    done
    echo $scale
}

# $1 = major version according to naming in stackfile and servicename in stackfile.
scale_service_with_timeout(){
    if  [ -z "$1" ]; then
        echo "Missing Version!"
    else
        timeout 25s docker-compose -f stacks/stack$1_compose.yml up --scale db$1=1 -d #--remove-orphans
        exit_code="$?"
        if [ "$exit_code" -gt 0 ]; then
            echo "Could not scale the service! Exit Code was: $exit_code"
        fi
    fi
}

# $1 = Container name
kill_pg_by_name(){
    if [ "$2" == "smart" ] || [ "$3" == "smart" ]; then
        stop_pg_container "$1" smart
    else 
        stop_pg_container "$1"
    fi
    
    #if [ "$2" != "-c" ]; then
    #    old_scale=$(get_service_scale)
    #    scale_service_with_timeout "$1" $(($old_scale-1))
    #fi
}

# $1 = major version according to naming in stackfile and servicename in stackfile.
start_new_subscriber(){
    # Scale the subscriber service up by one
    # Test: (Re-) Start of Subscribers that creates subscription
    # Test: Subscriber also receives als data before start.
    echo "This may take a few moments and consider deployment-constraints / ports usage which could prevent a success!"
    old_scale=$(get_service_scale)
    new_scale=$(($old_scale + 1))
    scale_service_with_timeout "$1" $new_scale
    echo scale
    wait_for_all_pg_to_boot
    echo "done"
}

wait_for_all_pg_to_boot(){
    for tuple in $(get_all_tuples); do
        container_id=$(get_id "$tuple")
        node=$(get_node "$tuple")
        while true; do
            result="$(docker exec $container_id pg_isready)"
            if [[ "$result" == *"- accepting connections"* ]]; then
                printf "."
                break
            fi
            sleep 2s
        done
    done
    echo ""
}

#############
################
#############

print_test_client_help(){
    echo "' $COMMAND $PARAM1 ' is not a valid command:"
    echo "
-- Interact with Container 
start:      [major version number without dots]
            will start a new postgres container within the specified composfile (e.g. 95 or 10). 
            BEWARE as container expose ports via host mode which limits the container per host to one!
        
kill:       [container name] 
            will kill a given container by its name. May execute with 'smart' to shutdown postgres smart.
        
reset:      [number] [number] [bool]
            will reset the cluster to the given v9.5 replication count (first param), v10 replication count (second param) and a boolean if the provider should be in version 10 (false = v9.5).

-- Get Info about VMs & Containers

status: [-o,-f] 
        will return the status of the containers. Either fast (-f, without update info) and continously (-o never stops)
        
-- Test Cluster

check:      will check if the shown roles by 'status' are correct and replication works as expected.
        
-- Misc.

end:    will exit this script.

"
}

if [ "$1" == "-h" ]; then
    print_test_client_help
    exit 0
fi

running_loop() {
    LOOP=true

    update_id_ip_nodes
    print_id_ip_nodes

    while $LOOP; do
        read -p ">> input command: " COMMAND PARAM1 PARAM2 PARAM3
        case "$COMMAND" in
        "kill") 
            if [ -z $PARAM1 ]; then
                echo "-- Missing Name"
            elif ! [ -z "$PARAM1" ]; then
                echo "-- Killing Subscriber $PARAM1"
                kill_pg_by_name $PARAM1 $PARAM2 1> /dev/null
            fi
            update_id_ip_nodes
            ;;
        "start") 
            echo "-- Starting new Subscriber"
            if [ -z "$PARAM1" ]; then
                echo "-- Missing Service name"
            else
                start_new_subscriber $PARAM1 1> /dev/null
                update_id_ip_nodes
            fi
            ;;
        "reset") 
            echo "-- Reseting Cluster"
            reset_cluster "$PARAM1" "$PARAM2" "$PARAM3"
            update_id_ip_nodes
            ;;
        "status") 
            echo "-- Container Status"
            if [ "$PARAM1" == "-o" ]; then
                observe_container_status
            elif [ "$PARAM1" == "-f" ]; then
                print_id_ip_nodes
            else
                update_id_ip_nodes
                print_id_ip_nodes
            fi
            ;;
        "check")
            print_id_ip_nodes
            clear_all_local_tables 1> /dev/null
            check_roles
            ;;
        "end")
            echo "-- Live long and prosper"
            LOOP=false
            ;;
        *) 
            print_test_client_help
            ;;
        esac
    done
}

running_loop