#!/bin/sh

# wait_for_vm waits for a given VM to start up
# $1 = VM IP
# Context: SETUP
wait_for_vm() {
    # Would prefer foot-loop but shell does not has that yet.
    #START_TIME=$(date +%s)
    USER=""
    while [ "$USER" != "root" ]; do
        sleep 1s
        USER=$($SSH_CMD -o ConnectTimeout=1 root@$1 "whoami" 2>/dev/null)
    done
    #END_TIME=$(date +%s)
    #echo "-- Waited $((END_TIME - START_TIME)) seconds for $1 to boot up"
}

# set_scripts copies the neccessary scripts to each Docker Swarm node.
# Context: SETUP
set_scripts() {
    scp_cmd_for_each_node "./postgres/reconnect.sh" /etc/
    scp_cmd_for_each_node "./postgres/demote.sh" /etc/
    scp_cmd_for_each_node "./postgres/sub_setup.sh" /etc/


    ssh_cmd_for_each_node "chmod +x /etc/reconnect.sh"
    ssh_cmd_for_each_node "chmod +x /etc/demote.sh"
    ssh_cmd_for_each_node "chmod +x /etc/sub_setup.sh"
}

# start_machines starts the VMs
# Context: SETUP
start_machines() {
    for vm in "${all_vb_names[@]}"; do
        VBoxManage startvm --type headless "$vm" &
        sleep 5s
    done

    for node in $all_nodes; do
        wait_for_vm $node
        printf "."
    done
    printf "\n"

    echo "-- Running VMs: "
    VBoxManage list runningvms
}

# get_dsn_node returns the Docker Swarm nodes ip on a given index
# $1 = Node Index according to .env.sh 'all_nodes' variable
# Context: SETUP
get_dsn_node(){
    arr=($all_nodes)
    echo ${arr[$1]}
}

# get_hostname returns the Docker Swarm nodes hostname on a given index
# $1 = Node Index according to .env.sh 'all_hostnames' variable
# Context: SETUP
get_hostname(){
    arr=($all_hostnames)
    echo ${arr[$1]}
}

# get_node_count returns hostname count of the .env.sh 'all_hostnames' variable.
# Context: SETUP
get_node_count(){
    arr=($all_hostnames)
    echo ${#arr[@]}
}

# get_index_of_dsn_node returns the index of a given Docker Swarm node ip.
# $1 = Docker Swarm node ip
# Context: SETUP
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