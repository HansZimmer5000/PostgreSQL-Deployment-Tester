#!/bin/sh

check_vm(){
    if [[ "$(ping -a $1 -c 1 -w 1)" = *", 0 received"* ]];  then 
        echo "$1 was not responding. Is it up and running?"
    else
        echo "$1 was responding"
    fi
}

check_vm 192.168.99.101
check_vm 192.168.99.102
check_vm 192.168.99.103