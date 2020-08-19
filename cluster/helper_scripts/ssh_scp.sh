#!/bin/sh

SSH_KEY="-i ./keys/dsnkey"
SSH_CMD="ssh $SSH_KEY"
SSH_CMD_TIMEOUT="$SSH_CMD -o ConnectTimeout=1"
SCP_CMD="scp -q $SSH_KEY"

SCP_CMD_FOR_EACH_NODE() {
    for node in $all_nodes; do
        $SCP_CMD $1 root@$node:$2
    done
}

SSH_CMD_FOR_EACH_NODE() {
    for node in $all_nodes; do
        $SSH_CMD_TIMEOUT root@$node $1
    done
}
