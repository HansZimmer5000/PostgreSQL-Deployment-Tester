#!/bin/sh

# TODOS

echo "
----- TODOs:
1. Keepalived master ist dort wo Provider ist
2. Keepalived promoted subscriber zu provider
3. Wieder ein Init-node für den initalen Provider gebraucht, dieses Mal mit Script automatisieren
4. Weitere Tests mit logischer Replikation mit verschiedenen Versionen
5. Test 4 klappt aktuell noch nicht weil neugestarteter Provider aktuell mit leerer DB anfängt -> keepalived implementieren, dann sollte es klappen.
"

# VARIABLES & CONSTANTS
################

source ../.env

SSH_KEY="-i ./keys/dsnkey"
SSH_CMD="ssh $SSH_KEY"
SSH_CMD_TIMEOUT="$SSH_CMD -o ConnectTimeout=1"
SCP_CMD="scp -q $SSH_KEY"


# LEVEL 4 SCRIPTS
# Should only return Echos to return info
################

SCP_CMD_FOR_EACH_NODE() {
    for node in $ALL_NODES; do
        $SCP_CMD $1 root@$node:$2
    done
}

SSH_CMD_FOR_EACH_NODE() {
    for node in $ALL_NODES; do
        $SSH_CMD_TIMEOUT root@$node $1
    done
}

allow_keepalived_selinux() {
    # Additionally in current configuration: 
    # in "/etc/sysconfig/selinux" is: SELINUX=disabled (needed restart)
    SSH_CMD_FOR_EACH_NODE "setenforce 0"
}

# LEVEL 3 SCRIPTS
# Should only return Echos to return info
################

update_keepalived_basics(){
    allow_keepalived_selinux

    SCP_CMD_FOR_EACH_NODE ./keepalived/check.sh /etc/keepalived/
    SCP_CMD_FOR_EACH_NODE ./keepalived/promote.sh /etc/keepalived/
    SCP_CMD_FOR_EACH_NODE ./keepalived/notify.sh /etc/keepalived/
    SCP_CMD_FOR_EACH_NODE ./keepalived/keepalived.conf /etc/keepalived/keepalived.conf

    SSH_CMD_FOR_EACH_NODE "chmod +x /etc/keepalived/check.sh"
    SSH_CMD_FOR_EACH_NODE "chmod +x /etc/keepalived/promote.sh"
    SSH_CMD_FOR_EACH_NODE "chmod +x /etc/keepalived/notify.sh"
    SSH_CMD_FOR_EACH_NODE "> /etc/keepalived/notify_log.txt"
    SSH_CMD_FOR_EACH_NODE "systemctl restart keepalived"
}

update_stacks(){
    SCP_CMD_FOR_EACH_NODE ./stack.yml /root/
    SCP_CMD_FOR_EACH_NODE ./portainer-agent-stack.yml /root/
}

gather_id() {
    $SSH_CMD $1 docker ps -f "name=$2" -q
}

gather_ip() {
    $SSH_CMD $1 docker inspect -f '{{.NetworkSettings.Networks.pg_pgnet.IPAddress}}' $2
}

gather_running_containers(){
    $SSH_CMD $1 'docker ps --format "table {{.ID}}\t{{.Names}}"'
}

# $1 = name // $2 = local location // $3 = remote location
reset_config(){
    $SSH_CMD root@$MANAGER_NODE "docker config rm $1" 2> /dev/null
    $SCP_CMD $2 root@$MANAGER_NODE:$3
    $SSH_CMD root@$MANAGER_NODE "docker config create $1 $3"
}

get_current_node_ips(){
    echo "$(SSH_CMD_FOR_EACH_NODE 'hostname -I')"
}

# LEVEL 2 SCRIPTS
# Should only return Echos to return info
################

# $1 = DSN Zahl des Init Nodes, $2-4 sind alle DSN Zahlen
set_init_label() {
    $SSH_CMD root@$MANAGER_NODE docker node update --label-add init_node=false docker-swarm-node$2.localdomain
    $SSH_CMD root@$MANAGER_NODE docker node update --label-add init_node=false docker-swarm-node$3.localdomain
    $SSH_CMD root@$MANAGER_NODE docker node update --label-add init_node=false docker-swarm-node$4.localdomain

    $SSH_CMD root@$MANAGER_NODE docker node update --label-add init_node=true docker-swarm-node$1.localdomain
}

update_all_nodes() {
    update_keepalived_basics
    update_stacks
}

give_vip_to_init_node() {
    SSH_CMD_FOR_EACH_NODE "systemctl stop keepalived"

    $SSH_CMD root@$INIT_NODE systemctl start keepalived
    sleep 5s #Wait for the INIT_NODEs keepalived to grap the VIP
    SSH_CMD_FOR_EACH_NODE "systemctl start keepalived"

    echo "Current IPs (each line is a different node):
$(get_current_node_ips)
"
}

build_images() {
    SCP_CMD_FOR_EACH_NODE "../customimage/raw.dockerfile" /etc/
    SSH_CMD_FOR_EACH_NODE "docker build /etc/ -f /etc/raw.dockerfile -t mypglog:9.5-raw" 
}

set_scripts(){
    SCP_CMD_FOR_EACH_NODE "./postgres/reconnect.sh" /etc/
    SSH_CMD_FOR_EACH_NODE "chmod +x /etc/reconnect.sh"
}

set_configs(){
    reset_config "tables" "./postgres/table_setup.sql" "/etc/table_setup.sql"
    
    reset_config "prov_config" "./postgres/prov_postgresql.conf" "/etc/prov_postgresql.conf"
    reset_config "prov_setup" "./postgres/prov_setup.sh" "/etc/prov_setup.sh"

    reset_config "sub_config" "./postgres/sub_postgresql.conf" "/etc/sub_postgresql.conf"
    reset_config "sub_setup" "./postgres/sub_setup.sh" "/etc/sub_setup.sh"

    reset_config "reconnect" "./postgres/reconnect.sh" "/etc/reconnect.sh"
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

# LEVEL 1 SCRIPTS
# Contains Echos
################

remove_stack_and_volumes() {
    $SSH_CMD root@$MANAGER_NODE "docker stack rm pg"
    sleep 10s #Wait till everything is deleted

    SSH_CMD_FOR_EACH_NODE "docker volume prune -f"
}

prepare_machines() {
    INIT_NODE_DSN_NO=2
    set_init_label $INIT_NODE_DSN_NO 1 2 3

    update_all_nodes

    # Make sure dsn2 = INIT_NODE gets the VIP
    give_vip_to_init_node
}

prepare_swarm() {
    build_images 1> /dev/null
    set_configs > /dev/null
    set_scripts > /dev/null
}

deploy_stack() {
    $SSH_CMD root@$MANAGER_NODE "docker stack deploy -c stack.yml pg"
    $SSH_CMD root@$MANAGER_NODE "docker stack deploy -c portainer-agent-stack.yml portainer"
    sleep 15s #Wait till everything has started 
    
    echo "-- Connect to Portainer at: http://$dsn1_node:9000/"
}

start_keepalived() {
    SSH_CMD_FOR_EACH_NODE "systemctl start keepalived"
}

start_swarm() {
    SSH_CMD_FOR_EACH_NODE "systemctl start docker"
    SSH_CMD_FOR_EACH_NODE "docker swarm leave -f"
    
    full_init_msg=$($SSH_CMD root@$MANAGER_NODE "docker swarm init --advertise-addr $dsn1_node")
    echo "$full_init_msg" | grep "SWMTKN"
    read -p "-- Please enter Token: " TOKEN
    $SSH_CMD root@$dsn2_node "docker swarm join --token $TOKEN $dsn1_node:2377"
    #ADJUSTMENT: $SSH_CMD root@dsn3 "docker swarm join --token $TOKEN $dsn1_node:2377"
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
    # TODO Loop through vms
    #echo "-- Booting VMs: "
    #VBoxManage startvm --type headless "Docker Swarm Node 1"&
    #sleep 5s
    #VBoxManage startvm --type headless "Docker Swarm Node 2"&
    #sleep 5s
    # ADJUSTMENT: VBoxManage startvm "Docker Swarm Node 3"&
    #sleep 5s

    #echo "-- Wait for VMs to boot up"
    #wait_for_vm $dsn1_node
    #printf "."
    #wait_for_vm $dsn2_node
    #printf "."
    # ADJUSTMENT: wait_for_vm dsn3
    #printf ".\n"

    echo "-- Running VMs: "
    VBoxManage list runningvms
}

print_help(){
    echo "
This script sets up the environment (machines and docker swarm) to start a PostgreSQL Cluster for certain experiments.
--------------------
Inuts:
1. (true (default) /false) is needed to determine if the VMs are already started (Only works on MacOS with VirtualBoxManager so far).
2. (true (default) /false) is needed to determine if keepalived and docker swarm (with 'dsn1' as Manager) is already running and set up.
3. (true (default) /false) is needed to determine if stack is already running and set up.
"
}

# SCRIPT START
##############

# TODOs define flags instead of fixed variables (true/false)

if [ "$1" == "-h" ]; then
    print_help
else 
    if ! $1; then
        echo "-- Starting VMs"
        start_machines
        sleep 10s
    else
        echo "-- Using already started VMs"
    fi

    if ! $2; then
        echo "-- Starting Keepalived"
        start_keepalived
        echo "-- Starting Docker"
        echo "$ALL_NODES"
        start_swarm
    else
        echo "-- Skipping Docker Swarm and Keepalived setup"
    fi

    if ! $3; then

        # CleanUp
        echo "-- Cleaning Up Old Stuff"
        remove_stack_and_volumes

        # Prepare 
        echo "-- Preparing Machines and Swarm"
        prepare_machines
        prepare_swarm

        # Start Stack
        deploy_stack
    else
        echo "-- Using existing stack deployment"
    fi

    source "./test_scripts/test_client_lib.sh"
    running_loop
fi

