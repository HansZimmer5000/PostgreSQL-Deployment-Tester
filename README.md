# PostgreSQL-Deployment-Tester

This program does two things:
1. The program deploys a PostgreSQL cluster via Docker Swarm onto VirtualBox VMs.
2. The program can interact with the deployed cluster. 
  - To manually force failure and see how the deployment reacts to that
  - To execute the pre defined automated tests
  
## TODO

As this is a Work in Progress there are currently alot of limitations. Each of them will be addressed if there is time according to their priority (MUST > SHOULD > NICE-to-have)

- Deployment
  - (SHOULD) Reseach Docker Swarm Health checks and their use for this project
  - (NICE) Only works fully with VirtualBox
  - (NICE) Only works with Docker Swarm
- Testing
  - (MUST) There are only four pre defined tests
  - (SHOULD) Only can interact and test with current configuration
- Implementations
  - (SHOULD) There are alot of fixed IPs, hostname and magic numbers
  - (SHOULD) The code is in a bad shape in terms of test coverage (none), readability and flakiness

## VM Setup

- Downloaded vdi from [osboxes](https://www.osboxes.org/centos/#centos-1908-vbox) (Password: osboxes.org)
- Set Name according to "Docker Swarm Node 0", replace 0 with number (1 ... n)
- Set three Networks: NAT, Host-Only and Internal-Network
- ssh
  - via NAT Network:
    - Set Port Forwarding (VirtualBox -> VM Settings -> Network -> Advanced -> GuestPort=22 HostPort=49022)
    - ssh via `ssh -p 49022 root@localhost` (Password osboxes.org)
  - via Host-Only Network (preferred):
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
    - TODO alos open up ports for keepalived and portainer
    - `firewall-cmd --permanent --add-port=2377/tcp`
    - `firewall-cmd --reload`

  #VBoxManage controlvm "Docker Swarm Node 2" acpipowerbutton; VBoxManage controlvm "Docker Swarm Node 1" acpipowerbutton