#!/bin/sh

# Depends on (will be sourced by using script):
# - docker_helper.sh
# - keepalived_helper.sh
# - ssh_scp.sh

get_current_node_ips() {
    index=0
    for current_node in $all_nodes; do
        if ! [ -z "$current_node" ]; then echo "node$index (label=$(get_label_version $index))": $($SSH_CMD root@$current_node hostname -I); fi
        index=$((index+1))
    done
}

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

update_all_nodes() {
    update_keepalived_basics
    update_labels
    update_stacks
}

set_scripts() {
    SCP_CMD_FOR_EACH_NODE "./postgres/reconnect.sh" /etc/
    SCP_CMD_FOR_EACH_NODE "./postgres/demote.sh" /etc/
    SCP_CMD_FOR_EACH_NODE "./postgres/sub_setup.sh" /etc/


    SSH_CMD_FOR_EACH_NODE "chmod +x /etc/reconnect.sh"
    SSH_CMD_FOR_EACH_NODE "chmod +x /etc/demote.sh"
    SSH_CMD_FOR_EACH_NODE "chmod +x /etc/sub_setup.sh"
}

prepare_swarm() {
    build_images 1>/dev/null
    set_configs >/dev/null
    set_scripts >/dev/null
}

prepare_machines() {
    update_all_nodes
    echo "Current IPs (each line is a different node):
$(get_current_node_ips)
"
}

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

get_dsn_node(){
    arr=($all_nodes)
    echo ${arr[$1]}
}

get_hostname(){
    arr=($all_hostnames)
    echo ${arr[$1]}
}

get_node_count(){
    arr=($all_hostnames)
    echo ${#arr[@]}
}

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