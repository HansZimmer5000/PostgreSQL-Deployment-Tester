#!/bin/sh -x
# This File is supposed to be included ('source') from setup.sh so it can use some function from it, do not execute on its own!

ssh_into_vm(){
    $SSH_CMD root@$1
}

set_cluster_version(){
    SSH_CMD_FOR_EACH_NODE "echo $1 > /etc/keepalived/cluster_version.txt"
}
get_cluster_version(){
    SSH_CMD_FOR_EACH_NODE "cat /etc/keepalived/cluster_version.txt"
}

get_virtualip_owner(){    
    ping -c 1 $dsn1_node 1> /dev/null
    ping -c 1 $dsn2_node 1> /dev/null
    ping -c 1 $dsn3_node 1> /dev/null
    ping -c 1 192.168.99.149 1> /dev/null

    virtualip_entry=($(arp -n 192.168.99.149))
    IFS=', ' read -r -a array <<< "$virtualip_entry"
    virtualip_mac="${array[3]}"

    for entry in $(arp -a | grep "docker") ; do
        IFS=', ' read -r -a array <<< "$entry"
        if [ "${array[3]}" == "$virtualip_mac" ]; then
            echo "$entry"
            break
        fi
    done
}

source ./helper_scripts/id_ip_nodes.sh
source ./helper_scripts/test_scenarios.sh
source ./helper_scripts/postgres_helper.sh

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
                kill_subscriber $PARAM1 $PARAM2 1>  /dev/null
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
        "log") 
            if [ -z "$PARAM1" ]; then
                echo "-- Missing Name"
            else
                echo "-- Get Log of $PARAM1"
                get_log "$PARAM1"
            fi
            ;;
        "notify")          
            if [ -z "$PARAM1" ]; then
                echo "-- Missing node"
            else
                if [ "$PARAM1" == "1" ]; then
                    get_notify_log $dsn1_node
                elif [ "$PARAM1" == "2" ]; then
                    get_notify_log $dsn2_node
                elif [ "$PARAM1" == "3" ]; then
                    get_notify_log $dsn3_node
                fi
            fi
            ;;
        "check")
            print_id_ip_nodes
            clear_all_local_tables 1> /dev/null
            check_roles
            ;;
        "vip")
            get_virtualip_owner
            ;;
        "ssh")
            if [ "$PARAM1" == "1" ]; then
                ssh_into_vm $dsn1_node
            elif [ "$PARAM1" == "2" ]; then
                ssh_into_vm $dsn2_node
            elif [ "$PARAM1" == "3" ]; then
                ssh_into_vm $dsn3_node
            fi
            ;;
        "cl_vr")
            if ! [ -z "$PARAM1" ]; then
                set_cluster_version $PARAM1
            fi
            echo "Current Cluster Versions:"
            get_cluster_version
            ;;
        "lb_vr")
            if ! [ -z "$PARAM1" ]; then
                if ! [ -z "$PARAM2" ]; then
                    set_label_version $PARAM1 $PARAM2
                fi
                get_label_version $PARAM1
            else
                echo "Please Enter Node number to see the current label, also enter new Version number to set label"
            fi
            ;;
        "table") 
            if [ -z $PARAM1 ]; then
                echo "-- Missing Name"
            elif ! [ -z "$PARAM1" ]; then
                echo "-- Get TestTable Entries from $PARAM1"
                get_table "$PARAM1"
            fi
            ;;
        "reconnect")
            echo "Reconnecting all subscribers"
            reconnect_all_subscriber
            ;;
        "test")
            if [[ $PARAM1 -gt 0 && $PARAM1 -le 4 ]]; then
                echo "-- Executing Test $PARAM1"
                test_$PARAM1
            elif [[ -z $PARAM1 ]]; then
                echo "-- Executing all Tests: Next Test 1 of 4"
                test_1
                echo "-- Executing all Tests: Next Test 2 of 4"
                test_2
                echo "-- Executing all Tests: Next Test 3 of 4"
                test_3
                echo "-- Executing all Tests: Next Test 4 of 4"
                test_4
            else
                echo "$PARAM1 was not between 1 and 4!"
            fi
            ;;
        "up_test")
            max_number=2
            if [[ $PARAM1 -gt 0 && $PARAM1 -le $max_number ]]; then
                echo "-- Executing Upgrade Test $PARAM1"
                upgrade_test_$PARAM1
            elif [[ -z $PARAM1 ]]; then
                echo "-- Executing all Upgrade Tests: Next Test 1 of $max_number"
                upgrade_test_1
            else
                echo "$PARAM1 was not between 1 and $max_number!"
            fi
            ;;
        "end")
            echo "-- Live long and prosper"
            LOOP=false
            ;;
        *) 
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
  
reconnect:  []
            will reconnect all subscriber to the virtual IP (more info about that in ../keepalived/).

-- Interact with VMs

ssh:    [1=dsn1, 2=dsn2, ...]
        will ssh into the given node by its name which was set in the ../.env file.

cl_vr:  [number]
        if given, will set the Cluster Version according to the exact input which is mandatory.
        If no input is given, current versions will be shown.       

lb_vr:  [number (1=dsn1, 2=dsn2, ...)] [number (version)]
        if given, will set the version number to the specified node as a docker swarm node label.
        If no input is given, current labels will be shown.

-- Get Info about VMs & Containers

vip:    will return the owner of the virtual IP.
    
status: [-a,-o,-f] 
        will return the status of the containers. Either fast (-f, without update info), verbose (-a, also lists all VM IPs) and continously (-o, as -a but never stops)
        
log:    [dbname]
        will return the docker log of the given name.
        
notify: [1=db.1,2=db.2,...]
        will return the keepalived 'notify_log.txt' file of a given node by its name which was set in the ../.env file.

table:  [dbname]
        will return the current content of the 'testtable' in the postgres container by its name.

-- Test Cluster

check:      will check if the shown roles by 'status' are correct and replication works as expected.
    
test:       [1-4]
            will execute the normal integration test(s). Either a single one by providing a number or all by not providing a number.
        
up_test:    [1-2]
            will execute the upgrade integration test(s). Behaves like 'test'.
        
-- Misc.

end:    will exit this script.

"
            ;;
        esac
    done
}

