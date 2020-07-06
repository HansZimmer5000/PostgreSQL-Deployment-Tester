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
    SSH_CMD_FOR_EACH_NODE "echo 9.5.18 > /etc/keepalived/cluster_version.txt" # TODO how to set version dynamically? Neccessary?
    SSH_CMD_FOR_EACH_NODE "systemctl restart keepalived"
}

give_vip_to_init_node() {
    SSH_CMD_FOR_EACH_NODE "systemctl stop keepalived"

    $SSH_CMD root@$INIT_NODE systemctl start keepalived
    sleep 5s #Wait for the INIT_NODEs keepalived to grap the VIP
    SSH_CMD_FOR_EACH_NODE "systemctl start keepalived"
}

start_keepalived() {
    SSH_CMD_FOR_EACH_NODE "systemctl start keepalived"
}
