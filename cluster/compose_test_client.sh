#!/bin/sh

gather_running_containers() {
    docker ps --format "table {{.ID}}\t{{.Names}}"
}

update_id_ip_nodes() {
    ID_IP_NODEs=""
    running_containers=$(gather_running_containers)
    for info in $running_containers; do
        if [ "$info_no" -gt "2" ]; then
            if [ $((info_no % 2)) == 1 ]; then
                current_id=$info
            else
                current_name=${info:0:9} #stacks_dbVV.X where VV = version (10 / 95) and X = replica number (0-9) # TODO name ggf. ganz anders und länger!
                current_ip=""
                
                if [[ $info == pg95_db* ]]; then
                    current_ip=$(docker inspect -f '{{.NetworkSettings.Networks.pg95_pgnet.IPAddress}}' $current_id)
                elif [[ $info == pg10_db* ]]; then
                    current_ip="$(docker inspect -f '{{.NetworkSettings.Networks.pg10_pgnet.IPAddress}}' $current_id)"
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
}

#############
################
#############

print_test_client_help(){
    echo "' $COMMAND $PARAM1 ' is not a valid command:"
    echo "
-- Interact with Container 
start:      [servicename]
            will start a new postgres container within the specified service (e.g. pg95_db or pg10_db). 
            BEWARE as container expose ports via host mode which limits the container per VM to one!
        
kill:       [dbname] 
            will reduce the replica count of the swarm stack and kill a given container by its name as printed by status. Also set '-c' to crash-kill a container and not adjust the replica count.
        
reset:      [number] [number] [bool]
            will reset the cluster to the given v9.5 replication count (first param), v10 replication count (second param) and a boolean if the provider should be in version 10 (false = v9.5).

-- Get Info about VMs & Containers

status: [-a,-o,-f] 
        will return the status of the containers. Either fast (-f, without update info), verbose (-a, also lists all VM IPs) and continously (-o, as -a but never stops)
        
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
                kill_pg_by_name $PARAM1 $PARAM2 1>  /dev/null
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
            if [ "$PARAM1" == "-a" ]; then 
                echo "-- Node IPs"
                get_current_node_ips
            fi

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