#!/bin/sh

# The following variables make it easier to use SSH as e.g. 'SSH_CMD' and 'SCP_CMD' already include the info where the private ssh key can be found locally. Or if needed, 'SSH_CMD_TIMEOUT' additionally specifies a Connect Timeout of one second. 
SSH_KEY="-i ./keys/dsnkey"
SSH_CMD="ssh $SSH_KEY"
SSH_CMD_TIMEOUT="$SSH_CMD -o ConnectTimeout=1"
SCP_CMD="scp -q $SSH_KEY"

# scp_cmd_for_each_node copies a given local file to a given remote location on each Docker Swarm node.
# $1 = Local file location
# $2 = Remote file location
# Context: SETUP, TEST, UPGRADE
scp_cmd_for_each_node() {
    for node in $all_nodes; do
        $SCP_CMD $1 root@$node:$2
    done
}

# ssh_cmd_for_each_node executed a given command on each Docker Swarm node.
# $1 = Shell command
# Context: SETUP, TEST, UPGRADE
ssh_cmd_for_each_node() {
    for node in $all_nodes; do
        $SSH_CMD_TIMEOUT root@$node $1
    done
}
