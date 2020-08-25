#!/bin/sh

# extract_token extracts and returns the Docker Swarm Join Token from a given text.
# $1 = The text that the Docker Swarm Manager outputs when a new Docker Swarm is created which includes the Join Token
# Context: SETUP
extract_token_failure_text="NOT FOUND"
extract_token() {
    result="$extract_token_failure_text"

    token_raw=($(echo $1 | grep -o "SWMTKN.*"))
    if [ "${#token_raw[@]}" -gt 0 ]; then
        result=${token_raw[0]}
    fi

    echo $result
}

# prepare_swarm prepares the Docker Swarm Nodes to properly deploy the postgres cluster
# Context: SETUP
prepare_swarm() {
    set_docker_files
    build_images 1>/dev/null
    set_v95_and_v10_labels $(get_node_count) 0
}

# set_docker_files copies the neccessary docker files onto the Docker Swarm Nodes.
# Context: SETUP
set_docker_files(){
    set_stacks
    set_configs
    set_scripts
}

# set_stacks copies the neccessary stack files onto the Docker Swarm Nodes.
# Context: SETUP
set_stacks() {
    scp_cmd_for_each_node ./stacks/stack95.yml /root/
    scp_cmd_for_each_node ./stacks/stack10.yml /root/
    scp_cmd_for_each_node ./stacks/portainer-agent-stack.yml /root/
}


# build_images copies the needed files and builds the images on the Docker Swarm nodes.
# Context: SETUP
build_images() {
    scp_cmd_for_each_node "../custom_image/9.5.18.dockerfile" /etc/
    scp_cmd_for_each_node "../custom_image/10.13.dockerfile" /etc/
    scp_cmd_for_each_node "../custom_image/docker-entrypoint.sh" /etc/
    ssh_cmd_for_each_node "chmod +x /etc/docker-entrypoint.sh"

    ssh_cmd_for_each_node "docker build /etc/ -f /etc/9.5.18.dockerfile -t mypglog:9.5"
    ssh_cmd_for_each_node "docker build /etc/ -f /etc/10.13.dockerfile -t mypglog:10"
}

# set_configs resets two Docker Swarm configs and their files.
# Context: SETUP
set_configs() {
    reset_config "tables" "./postgres/table_setup.sql" "/etc/table_setup.sql"
    reset_config "sub_config" "./postgres/sub_postgresql.conf" "/etc/sub_postgresql.conf"
}

# clean_docker will delete stacks, running containers and prune the volumes with force on the Docker Swarm nodes.
# Context: SETUP
clean_docker() {
    $SSH_CMD root@$manager_node "docker stack rm pg95"
    $SSH_CMD root@$manager_node "docker stack rm pg10"
    sleep 10s #Wait till everything is deleted

    ssh_cmd_for_each_node "docker rm $(docker ps -aq) -f"
    ssh_cmd_for_each_node "docker volume prune -f"
}

# deploy_stack will deploy the stacks.
# Context: SETUP
deploy_stack() {
    $SSH_CMD root@$manager_node "docker stack deploy -c stack95.yml pg95"
    $SSH_CMD root@$manager_node "docker stack deploy -c stack10.yml pg10"
    $SSH_CMD root@$manager_node "docker stack deploy -c portainer-agent-stack.yml portainer"
    sleep 15s #Wait till everything has started

    echo "-- Connect to Portainer at: http://$manager_node:9000/"
}

# start_swarm will start docker and create the Docker Swarm
# Context: SETUP
start_swarm() {
    ssh_cmd_for_each_node "systemctl start docker"
    ssh_cmd_for_each_node "docker swarm leave -f"

    full_init_msg=$($SSH_CMD root@$manager_node "docker swarm init --advertise-addr $manager_node")
    TOKEN=$(extract_token "$full_init_msg")

    for current_node in $other_nodes; do
        $SSH_CMD root@$current_node "docker swarm join --token $TOKEN $manager_node:2377"
    done
}

# check_swarm will check if any node delcared in the .env.sh file is existent in the Docker Swarm.
# Context: SETUP
check_swarm() {
    nodes=$($SSH_CMD root@$manager_node "docker node ls")
    if [ -z "$nodes" ]; then
        echo "Is Manager Node ready? Aborting"
        exit 1
    else
        for current_hostname in $all_hostnames; do
            if [[ "$nodes" != *"$current_hostname"* ]]; then
                echo "Is $current_hostname ready? Aborting"
                exit 1
            fi
        done
    fi

    echo "Both Nodes are up!"
}
