#!/bin/sh

# Depends on (will be sourced by using script):
# - ssh_scp.sh

allow_keepalived_selinux() {
    # Additionally in current configuration:
    # in "/etc/sysconfig/selinux" is: SELINUX=disabled (needed restart)
    SSH_CMD_FOR_EACH_NODE "setenforce 0"
}

update_keepalived_basics() {
    allow_keepalived_selinux

    SCP_CMD_FOR_EACH_NODE ./keepalived/check.sh /etc/keepalived/
    SCP_CMD_FOR_EACH_NODE ./keepalived/promote.sh /etc/keepalived/

    SCP_CMD_FOR_EACH_NODE ./keepalived/notify.sh /etc/keepalived/
    SCP_CMD_FOR_EACH_NODE ./keepalived/keepalived.conf /etc/keepalived/keepalived.conf

    SSH_CMD_FOR_EACH_NODE "chmod +x /etc/keepalived/check.sh"
    SSH_CMD_FOR_EACH_NODE "chmod +x /etc/keepalived/promote.sh"
    SSH_CMD_FOR_EACH_NODE "chmod +x /etc/keepalived/notify.sh"
    SSH_CMD_FOR_EACH_NODE "> /etc/keepalived/notify_log.txt"
    SSH_CMD_FOR_EACH_NODE "echo 9.5.18 > /etc/keepalived/cluster_version.txt"
    SSH_CMD_FOR_EACH_NODE "systemctl restart keepalived"
}

start_keepalived() {
    SSH_CMD_FOR_EACH_NODE "systemctl start keepalived"
}
