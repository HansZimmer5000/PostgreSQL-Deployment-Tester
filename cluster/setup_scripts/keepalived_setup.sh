#!/bin/sh

# Depends on (will be sourced by using script):
# - ssh_scp.sh

# prepare_keepalived will prepare Keepalived for the Postgres Cluster
# Context: SETUP
prepare_keepalived(){
    set_keepalived_files
    allow_keepalived_selinux
}

# allow_keepalived_selinux will allow Keepalived execution in selinux
# Context: SETUP
allow_keepalived_selinux() {
    # Additionally in current configuration:
    # in "/etc/sysconfig/selinux" is: SELINUX=disabled (needed restart)
    ssh_cmd_for_each_node "setenforce 0"
}

# set_keepalived_files will copy neccessary files to the Docker Swarm nodes.
# Context: SETUP
set_keepalived_files() {
    scp_cmd_for_each_node ./keepalived/check.sh /etc/keepalived/
    scp_cmd_for_each_node ./keepalived/promote.sh /etc/keepalived/

    scp_cmd_for_each_node ./keepalived/notify.sh /etc/keepalived/
    scp_cmd_for_each_node ./keepalived/keepalived.conf /etc/keepalived/keepalived.conf

    ssh_cmd_for_each_node "chmod +x /etc/keepalived/check.sh"
    ssh_cmd_for_each_node "chmod +x /etc/keepalived/promote.sh"
    ssh_cmd_for_each_node "chmod +x /etc/keepalived/notify.sh"
    ssh_cmd_for_each_node "> /etc/keepalived/notify_log.txt"
    ssh_cmd_for_each_node "echo 9.5.18 > /etc/keepalived/cluster_version.txt"
    ssh_cmd_for_each_node "systemctl restart keepalived"
}

# start_keepalived will start Keepalived on all Docker Swarm nodes.
# Context: SETUP
start_keepalived() {
    ssh_cmd_for_each_node "systemctl start keepalived"
}
