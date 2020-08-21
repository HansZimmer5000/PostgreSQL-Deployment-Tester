#!/bin/sh

# Depends on (will be sourced by using script):
# - docker_helper.sh
# - keepalived_helper.sh
# - ssh_scp.sh
# - .env.sh

# get_current_node_ips returns the current Docker Swarm node IPs and the value of the Docker Swarm Label 'pg_ver'
# Context: SETUP, TEST, UPGRADE
get_current_node_ips() {
    index=0
    for current_node in $all_nodes; do
        if ! [ -z "$current_node" ]; then echo "node$index (label=$(get_version_label $index))": $($SSH_CMD root@$current_node hostname -I); fi
        index=$((index+1))
    done
}

#TODO
ssh_into_vm(){
    $SSH_CMD root@$1
}

#TODO
set_cluster_version(){
    ssh_cmd_for_each_node "echo $1 > /etc/keepalived/cluster_version.txt"
}

#TODO
get_cluster_version(){
    ssh_cmd_for_each_node "cat /etc/keepalived/cluster_version.txt"
}

#TODO
get_virtualip_owner(){    
    for current_node in $all_nodes; do
        ping -c 1 $current_node 1> /dev/null
    done
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

# get_index_of_dsn_node returns the index of a given Docker Swarm node ip.
# $1 = Docker Swarm node ip
# Context: SETUP, UPGRADE
get_index_of_dsn_node(){
    index=0
    for current_node in $all_nodes; do
        if [[ "$1" == "$current_node" ]]; then
            echo $index
            break
        fi
        index=$((index+1))
    done
}

# get_hostname returns the Docker Swarm nodes hostname on a given index
# $1 = Node Index according to .env.sh 'all_hostnames' variable
# Context: SETUP, UPGRADE
get_hostname(){
    arr=($all_hostnames)
    echo ${arr[$1]}
}