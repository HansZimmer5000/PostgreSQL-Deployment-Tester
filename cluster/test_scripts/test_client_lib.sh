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

set_label_version() {
    # TODO May refactor with similar commands (--label-add) in docker.sh
    $SSH_CMD root@$MANAGER_NODE docker node update --label-add pg.ver=$2 docker-swarm-node$1.localdomain
}

get_label_version(){
    # TODO For each node and todo finalize
    $SSH_CMD root@$MANAGER_NODE docker inspect --format '{{ index .Config.Labels "pg.ver"}}' todo_container_id
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

source "./test_scripts/id_ip_nodes.sh"
source "./test_scripts/test_scenarios.sh"
source "./test_scripts/docker_cmds.sh"
source "./test_scripts/pg_cmds.sh"

running_loop() {
    LOOP=true

    update_id_ip_nodes
    print_id_ip_nodes

    while $LOOP; do
        read -p ">> input command: " COMMAND PARAM1 PARAM2
        case "$COMMAND" in
        "kill") 
            if [ -z $PARAM1 ]; then
                echo "-- Missing Number"
            elif [ "$PARAM1" == "0" ]; then
                echo "-- Killing Provider"
                kill_provider $PARAM2
            elif [ "$PARAM1" -gt 0 ]; then
                echo "-- Killing Subscriber $PARAM1"
                kill_subscriber $PARAM1 $PARAM2 1>  /dev/null
            fi
            update_id_ip_nodes
            ;;
        "start") 
            echo "-- Starting new Subscriber"
            start_new_subscriber 1> /dev/null
            update_id_ip_nodes
            ;;
        "reset") 
            echo "-- Reseting Cluster"
            reset_cluster "$PARAM1"
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
                echo "-- Missing Number"
            elif [ "$PARAM1" == "0" ]; then
                echo "-- Get Log of Provider"
                get_log "provider"
            elif [ "$PARAM1" -gt 0 ]; then
                echo "-- Get Log of Subscriber $PARAM1"
                get_log "db.$PARAM1"
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
            if ! [ -z "$PARAM1" ] && ! [ -z "$PARAM2" ]; then
                set_label_version $PARAM1 $PARAM2
            else
                echo "Please Enter Node number AND new Version number"
            fi
            ;;
        "table") 
            if [ -z $PARAM1 ]; then
                echo "-- Missing Number"
            elif [ "$PARAM1" == "0" ]; then
                echo "-- Get TestTable Entries from Provider"
                get_table "provider"
            elif [ "$PARAM1" -gt 0 ]; then
                echo "-- Get TestTable Entries from Subscriber $PARAM1"
                get_table "db.$PARAM1"
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
            max_number=4
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
start:      will start a new postgres container (TODO V9.5 or V10 Stack?). 
            BEWARE as container expose ports via host mode which limits the container per VM to one!
        
kill:       [0=provider,1=db.1,2=db.2,...] 
            will reduce the replica count of the swarm stack (TODO V9.5 or V10 Stack?) and kill a given container by its number in its name 'db.X'. Also set '-c' to crash-kill a container and not adjust the replica count.
        
reset:      [number]
            will reset the cluster (TODO V9.5 or V10 Stack?) to one provider and a given number of subscribers (default 1)
  
reconnect:  []
            will reconnect all subscriber to the virtual IP (more info about that in ../keepalived/).

-- Interact with VMs

ssh:    [1=dsn1, 2=dsn2, ...]
        will ssh into the given node by its name which was set in the ../.env file.

cl_vr:  [number]
        will set the Cluster Version according to input which is mandatory!        

lb_vr:  [number (1=dsn1, 2=dsn2, ...)] [number (version)]
        will set the version number to the specified node as a docker swarm node label.

-- Get Info about VMs & Containers

vip:    will return the owner of the virtual IP.
    
status: [-a,-o,-f] 
        will return the status of the containers. Either fast (-f, without update info), verbose (-a, also lists all VM IPs) and continously (-o, as -a but never stops)
        
log:    [1=db.1,2=db.2,...]
        will return the docker log of the given container by its number in its name 'db.X'.
        
notify: [1=db.1,2=db.2,...]
        will return the keepalived 'notify_log.txt' file of a given node by its name which was set in the ../.env file.

table:  [1=db.1,2=db.2,...]
        will return the current content of the 'testtable' in the postgres container by its number in its name 'db.X'.

-- Test Cluster

check:      will check if the shown roles by 'status' are correct and replication works as expected.
    
test:       [1-4]
            will execute the normal integration test(s). Either a single one by providing a number or all by not providing a number.
        
up_test:    [1,4]
            will execute the upgrade integration test(s). Behaves like 'test'.
        
-- Misc.

end:    will exit this script.

"
            ;;
        esac
    done
}

