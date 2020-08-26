#!/bin/sh

source ./.env.sh
source ./helper_scripts/docker.sh
source ./helper_scripts/id_ip_nodes.sh
source ./helper_scripts/postgres.sh

print_test_client_help(){
    echo "' $COMMAND $PARAM1 ' is not a valid command:"
    echo "
-- Interact with Container 
start:      [major version number without dots]
            will start a new postgres container within the specified composfile (e.g. 95 or 10). 
            BEWARE as container expose ports via host mode which limits the container per host to one!
        
kill:       [container name] 
            will kill a given container by its name. May execute with 'smart' to shutdown postgres smart.
        
promote:    [container name]
            will promote a given subscriber to provider.

-- Get Info about VMs & Containers

status: [-f] 
        will return the status of the containers. Fast ,-f, without update info.
        
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
        "promote")
            echo "-- Upgrading $PARAM1"
            promote_sub $PARAM1
            ;;
        "reset") 
            echo "-- Reseting Cluster"
            reset_cluster "$PARAM1" "$PARAM2" "$PARAM3"
            update_id_ip_nodes
            ;;
        "status") 
            echo "-- Container Status"
            if [ "$PARAM1" == "-f" ]; then
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