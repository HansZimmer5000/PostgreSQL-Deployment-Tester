#!/bin/sh 

ssh_cmd="ssh -i ./swarmWithKeepalived/keys/dsnkey"

setup_firewall(){
    #https://www.rootusers.com/how-to-open-a-port-in-centos-7-with-firewalld/
    #https://iomeweekly.blogspot.com/2014/09/install-keepalived-on-centos-7.html
    $ssh_cmd root@$1 firewall-cmd --direct --permanent --add-rule ipv4 filter INPUT 0 --in-interface eth0 --destination 224.0.0.18 --protocol vrrp -j ACCEPT
    $ssh_cmd root@$1 firewall-cmd --direct --permanent --add-rule ipv4 filter OUTPUT 0 --out-interface eth0 --destination 224.0.0.18 --protocol vrrp -j ACCEPT

    $ssh_cmd root@$1 firewall-cmd --permanent --add-port=2377/tcp

    $ssh_cmd root@$1 firewall-cmd --permanent --add-port=8000/tcp
    $ssh_cmd root@$1 firewall-cmd --permanent --add-port=9000/tcp

    $ssh_cmd root@$1 firewall-cmd --reload
}

setup_packages(){
    $ssh_cmd root@$1 yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

    $ssh_cmd root@$1 yum upgrade -y -q #Also deletes obsolete packages in comparison to 'update'

    $ssh_cmd root@$1 yum install epel-release

    echo "Install keepalived and docker"
    # If docker-compose is needed: https://docs.docker.com/compose/install/
    $ssh_cmd root@$1 yum install -y -q keepalived docker

    $ssh_cmd root@$1 systemctl start docker
    $ssh_cmd root@$1 docker version
}

setup_vm(){

    if [[ "$(ping -a 192.168.99.101 -c 1 -w 1)" = *", 0 received"* ]];  then 
        echo "$1 was not responding. Is it up and running?"
    else 
        setup_firewall $1

        echo "Prepare"
        ping_result="$($ssh_cmd root@$1 ping -a www.google.de -c 1 -w 1 2> /dev/null)" 
        if [[ "$ping_result" = *", 0 received"* ]] || [[ -z "$ping_result" ]];  then 
            echo "www.google.de was not responding. Is this VM connected to the internet?"
        else
            setup_packages
        fi
    fi
}

setup_vm 192.168.99.101
setup_vm 192.168.99.102
