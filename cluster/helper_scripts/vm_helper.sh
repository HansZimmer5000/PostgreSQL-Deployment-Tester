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
