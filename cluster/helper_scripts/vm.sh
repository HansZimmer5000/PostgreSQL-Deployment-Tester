#!/bin/sh

# Depends on (will be sourced by using script):
# - docker_helper.sh
# - keepalived_helper.sh
# - ssh_scp.sh

get_current_node_ips() {
    if ! [ -z "$dsn1_node" ]; then echo "dsn1 (label=$(get_label_version 1))": $($SSH_CMD root@$dsn1_node hostname -I); fi
    if ! [ -z "$dsn2_node" ]; then echo "dsn2 (label=$(get_label_version 2))": $($SSH_CMD root@$dsn2_node hostname -I); fi
    if ! [ -z "$dsn3_node" ]; then echo "dsn3 (label=$(get_label_version 3))": $($SSH_CMD root@$dsn3_node hostname -I); fi
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

# TODO This mainly copies scripts for docker but also for VM! (e.g. demote.sh)
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
    vms=("Docker Swarm Node 1" "Docker Swarm Node 2")
    for vm in "${vms[@]}"; do
        VBoxManage startvm --type headless "$vm" &
        sleep 5s
    done

    for node in $ALL_NODES; do
        wait_for_vm $node
        printf "."
    done
    printf "\n"

    echo "-- Running VMs: "
    VBoxManage list runningvms
}
