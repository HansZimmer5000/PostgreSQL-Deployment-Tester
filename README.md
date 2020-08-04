# PostgreSQL-Deployment-Tester

This program (setup.sh & rolling_upgrade.sh) does two things:
- The program deploys a PostgreSQL cluster via Docker Swarm onto VirtualBox VMs.
- The program can interact with the deployed cluster:
  - To manually force failure and see how the deployment reacts to that
  - To execute the pre defined tests
  - To get current logs and stats
  - To perform a rolling upgrade
  
The main logic is implemented in cluster/setup.sh and cluster/rolling_upgrade.sh.
See cluster/REAMDE.md for more info.

## TODO

As this is a Work in Progress there are currently alot of limitations. Each of them will be addressed if there is time according to their priority (MUST > SHOULD > NICE-to-have)

- Deployment
  - (NICE) Only is used and tested with VirtualBox
  - (NICE) Only works with Docker Swarm
- Testing
  - (MUST) There are hardly any Unit Tests
- Implementations
  - (MUST) refactor placement and names of functions, files, folders.
  - (SHOULD) Map out which kind of configuration is expected and how to change that.
  - (SHOULD) The code is in a bad shape in terms of test coverage (none), readability and flakiness
- Setup
  - (NICE) Setup / configure (see following section) the VMs via Ansible or similar.

TODOs from Meetings:
- Usability
  - Make working with script intuitive
- Tutorial incl. common errors for:
  - test_client.sh 
  - rolling_upgrade.sh
  - setup.sh
    - "-s" Option sometimes fails when executed for the 1st time due to "context timeout". Just re-execute the "-s" option.
  - vm_setup.sh
- Documentation
  - Change Mounts & PGDATA
    - Use standard PGDATA
    - via ENV vars set "old" folder location and via mount set "old" folder (preperation for pg_upgrade)
  - Hints on further development (e.g. switch to python or Upgrade from v10 to v12)

## VM Setup

### Via Vagrant
- The Testbed VM is available as a [vagrant box](https://app.vagrantup.com/hanszimmer5000/boxes/pdt-testbed)
- Needs vagrant to get the virtualbox instance from it.
- After that, the virtualbox instance is usable without vagrant if desired.

### Raw
- Downloaded vdi from [osboxes](https://www.osboxes.org/centos/#centos-1908-vbox) (Password: osboxes.org)
- Set VirtualBox Name according to "Docker Swarm Node 0", replace 0 with number (1 ... n). Change hostname via "hostname 'docker-swarm-node1'".
- Networks: 
  - First Try: NAT, Host-Only and Internal-Network (works but Flaky)
  - Second Try: Bridged Network (doesn't have 192.168.99.10* IPs but works, Current Setting!)
  - Third Try: Host-Only and Bridged Network (does have 192.168.99.10* IPs and internet connection = win!)
- ssh
  - via NAT Network:
    - Set Port Forwarding (VirtualBox -> VM Settings -> Network -> Advanced -> GuestPort=22 HostPort=49022)
    - ssh via `ssh -p 49022 root@localhost` (Password osboxes.org)
  - via Host-Only or Bridged Network (preferred):
    - get IP via Guest: hostname -I
    - ssh via `ssh root@<guest-ip>`
  - Set ssh key:
    - Insert content of own dsn_public_key into `~/.ssh/authorized_keys` of intended remote user in guest (e.g. root)
    - `chmod 400 ./path/to/dsn_private_key`
    - `ssh -i /path/to/dsn_private_key root@<guest-ip>`
- Further Software installs (do once, copy vdi files later)
  - `yum install upgrade -y`
  - `yum install keepalived docker`
  - Open Ports
    - also open up ports for keepalived and portainer
    - `firewall-cmd --permanent --add-port=2377/tcp`
    - `firewall-cmd --reload`
    - Or More "Durch die Wand" approach:
      - iptables-save
      - service firewalld stop
      - systemctl disable firewalld
  - Check that the keepalived.conf uses the same interface as the 192.168.99.XXX address range is on the VMs!

