#!/bin/sh -x
# This File is supposed to be included ('source') from setup.sh so it can use some function from it, do not execute on its own!

ssh_into_vm(){
    $SSH_CMD root@$1
}

get_virtualip_owner(){    
    ping -c 1 $dsn1_node 1> /dev/null
    ping -c 1 $dsn2_node 1> /dev/null
    ping -c 1 $dsn3_node 1> /dev/null
    ping -c 1 192.168.1.149 1> /dev/null

    virtualip_entry=($(arp -n 192.168.1.149))
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

    while $LOOP
    do
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
            reset_cluster 1
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
                get_notify_log "$PARAM1"
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
        "end")
            echo "-- Live long and prosper"
            LOOP=false
            ;;
        *) 
            echo "' $COMMAND $PARAM1 ' is not a valid command:"
            echo "COMMAND=[
    kill, start, reset, log, status, end, check, vip, ssh, table]"
            echo "
    PARAM1=[
        kill: [0=provider,1=sub1,2=sub2,...]
        status: [-a,-o,-f], 
        log: [0=provider,1=sub1,2=sub2,...]
        notify: [node url], 
        ssh: [1,2,3 for vm of dsn 1 2 or 3]
        table: [0=provider,1=sub1,...]
        test: [1-4]
    ]"
            echo "
    PARAM2=[
        kill: [-c]
    ]"
            ;;
        esac
    done
}

