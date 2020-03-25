#!/bin/sh

check_vm(){
    if [[ "$(ping -a $1 -c 1 -w 1)" = *", 1 received"* ]];  then 
        echo "$1 was responding"
    else
        echo "$1 was not responding. Is it up and running?"
    fi
}

source ./.env

check_vm $dsn1_node
check_vm $dsn2_node
check_vm $dsn3_node