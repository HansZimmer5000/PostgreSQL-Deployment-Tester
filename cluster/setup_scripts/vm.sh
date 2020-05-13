#!/bin/sh

get_current_node_ips(){
    echo "$(SSH_CMD_FOR_EACH_NODE 'hostname -I')"
}

wait_for_vm() {
    # Would prefer foot-loop but shell does not has that yet.
    #START_TIME=$(date +%s)
    USER=""
    while [ "$USER" != "root" ]; 
    do
        sleep 1s
        USER=$($SSH_CMD -o ConnectTimeout=1 root@$1 "whoami" 2> /dev/null) 
    done
    #END_TIME=$(date +%s)
    #echo "-- Waited $((END_TIME - START_TIME)) seconds for $1 to boot up"
}

update_all_nodes() {
    update_keepalived_basics
    update_stacks
}

# TODO This mainly copis scripts for docker but also for VM! (e.g. demote.sh)
set_scripts(){
    SCP_CMD_FOR_EACH_NODE "./postgres/reconnect.sh" /etc/
    SCP_CMD_FOR_EACH_NODE "./postgres/demote.sh" /etc/
    SCP_CMD_FOR_EACH_NODE "./postgres/upgrade_to_v10.sh" /etc/

    SSH_CMD_FOR_EACH_NODE "chmod +x /etc/reconnect.sh"
    SSH_CMD_FOR_EACH_NODE "chmod +x /etc/demote.sh"
    SSH_CMD_FOR_EACH_NODE "chmod +x /etc/upgrade_to_v10.sh"
}

prepare_machines() {
    INIT_NODE_DSN_NO=2
    set_init_label $INIT_NODE_DSN_NO 1 2 3

    update_all_nodes

    # Make sure dsn2 = INIT_NODE gets the VIP
    give_vip_to_init_node
}


start_machines(){
    vms=("Docker Swarm Node 1" "Docker Swarm Node 2")
    for vm in "${vms[@]}" ; do
        VBoxManage startvm --type headless "$vm" &
        sleep 5s
    done

    for node in $ALL_NODES ; do
        wait_for_vm $node
        printf "."
    done
    printf "\n"

    echo "-- Running VMs: "
    VBoxManage list runningvms
}
