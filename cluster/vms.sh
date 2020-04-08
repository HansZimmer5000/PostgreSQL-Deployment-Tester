#!/bin/sh

source ./.env

print_help(){
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
    print_help
fi

while getopts 'hsc' opts; do
    case ${opts} in 
        h)  print_help 
            exit 0 ;;
        s)  shutdown_vm "Docker Swarm Node 1"
            shutdown_vm "Docker Swarm Node 2"
            shutdown_vm "Docker Swarm Node 3"
            ;;
        c)  check_vm $dsn1_node
            check_vm $dsn2_node
            check_vm $dsn3_node
            ;;
    esac
done

