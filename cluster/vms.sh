#!/bin/sh

source ./.env.sh

print_vms_help(){
    echo "
This script shutsdown or checks the VMs.
--------------------
Flags:
-s  will shutdown all VMs
-c  will check all VMs if reacheable
-h  will print this help
"
}

shutdown_vm(){
    echo "Shutting Down $1"
    VBoxManage controlvm "$1" poweroff 2> /dev/null
}

check_vm(){
    if [[ "$(ping -a $1 -c 1 -w 1)" = *", 1 received"* ]];  then 
        echo "$1 was responding"
    else
        echo "$1 was not responding. Is it up and running?"
    fi
}


if [ -z "$1" ]; then
    print_vms_help
fi

while getopts 'hsc' opts; do
    case ${opts} in 
        h)  print_vms_help 
            exit 0 ;;
        s)      
            for vm in "${all_vb_names[@]}"; do
                shutdown_vm "$vm"
            done
            ;;
        c)  
            for current_node in $all_nodes; do
                check_vm $current_node
            done
            ;;
    esac
done

