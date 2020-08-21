#!/bin/sh

# ssh_into_vm starts a ssh connection to the given IP
# $1 = Host IP
# Context: TEST
ssh_into_vm(){
    $SSH_CMD root@$1
}

# get_cluster_version returns the set value in the cluster_version.txt on the Docker Swarm nodes
# Context: TEST
get_cluster_version(){
    ssh_cmd_for_each_node "cat /etc/keepalived/cluster_version.txt"
}

# get_virtualip_owner returns which Docker Swarm node has the Virtual IP (= is the Keepalived Master)
# Context: TEST
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