#!/bin/sh 

source ./.env.sh
source helper_scripts/ssh_scp.sh

# setup_firewall adds rules to the firewall on a given VM.
# $1 = VM ip
# Context: SETUP
setup_firewall(){
    #https://www.rootusers.com/how-to-open-a-port-in-centos-7-with-firewalld/
    #https://iomeweekly.blogspot.com/2014/09/install-keepalived-on-centos-7.html
    $SSH_CMD root@$1 firewall-cmd --direct --permanent --add-rule ipv4 filter INPUT 0 --in-interface eth0 --destination 224.0.0.18 --protocol vrrp -j ACCEPT
    $SSH_CMD root@$1 firewall-cmd --direct --permanent --add-rule ipv4 filter OUTPUT 0 --out-interface eth0 --destination 224.0.0.18 --protocol vrrp -j ACCEPT

    $SSH_CMD root@$1 firewall-cmd --permanent --add-port=2377/tcp

    $SSH_CMD root@$1 firewall-cmd --permanent --add-port=8000/tcp
    $SSH_CMD root@$1 firewall-cmd --permanent --add-port=9000/tcp

    $SSH_CMD root@$1 firewall-cmd --reload
}

# setup_packages updates the packages and starts docker on a given VM.
# $1 = VM ip
# Context: SETUP
setup_packages(){
    $SSH_CMD root@$1 yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

    $SSH_CMD root@$1 yum upgrade -y -q #Also deletes obsolete packages in comparison to 'update'

    $SSH_CMD root@$1 yum install epel-release

    echo "Install keepalived and docker"
    # If docker-compose is needed: https://docs.docker.com/compose/install/
    $SSH_CMD root@$1 yum install -y -q keepalived docker

    $SSH_CMD root@$1 systemctl start docker
    $SSH_CMD root@$1 docker version
}

# set_hostname sets the hostname on a given VM to a given name
# $1 = VM ip
# $2 = new hostname
# Context: SETUP
set_hostname(){
    $SSH_CMD root@$1 hostnamectl set-hostname $2

    if [[ "$($SSH_CMD root@$1 hostname)" != *"$2"* ]]; then
        echo "hostname '$2' could not be set at '$1' and was "
    fi
}

# setup_vm setups the given VM for the Docker Swarm
# $1 = VM ip
# $2 = new hostname
# Context: SETUP
setup_vm(){

    set_hostname $1 $2

    if [[ "$(ping -a $1 -c 1 -w 1)" = *", 0 received"* ]];  then 
        echo "$1 was not responding. Is it up and running?"
    else 
        setup_firewall $1

        echo "Prepare"
        ping_result="$($SSH_CMD root@$1 ping -a www.google.de -c 1 -w 1 2> /dev/null)" 
        if [[ "$ping_result" = *", 0 received"* ]] || [[ -z "$ping_result" ]];  then 
            echo "www.google.de was not responding. Is this VM connected to the internet?"
        else
            setup_packages $1
        fi
    fi
}

# setup_vm setups all VMs for the Docker Swarm
# Context: SETUP
setup_all_vms(){
    current_index=$(get_node_count)
    for [ current_index -ge 0 ]; do
        current_node=$(get_dsn_node $current_index)
        current_hostname=$(get_hostname $current_index)
        setup_vm $current_node $current_hostname
    done
}

setup_all_vms
