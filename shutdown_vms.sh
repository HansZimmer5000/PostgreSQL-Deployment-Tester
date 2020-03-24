#!/bin/sh

shutdown_vm(){
    echo "Shutting Down $1"
    VBoxManage controlvm "$1" poweroff 2> /dev/null
}

shutdown_vm "Docker Swarm Node 1"
shutdown_vm "Docker Swarm Node 2"
shutdown_vm "Docker Swarm Node 3"
