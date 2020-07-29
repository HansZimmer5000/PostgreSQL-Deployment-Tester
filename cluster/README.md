# Executables

## Rolling Upgrade

To perform a rolling upgrade, execute rolling_upgrade.sh.

How to use:
- Execute with normal shell in this folder `./rolling_upgrade.sh`
- Phase 1: Then you will be prompted to enter a subscriber name, it is in the form like `pg95_db.1`. This subscriber will be the first that is upgraded to the new version (v10).
- Phase 2: After you pressed `enter` to continue, the other subscriber will be upgraded.
- Phase 3: After you pressed `enter` to continue, the provider will be upgraded and the rolling upgrade comes to an end.

Following the configuration and how to adjust it:
- old version is 9.5.18 | TODO
- new version is 10.13 | TODO
- there are three hosts | TODO
- hostnames | TODO
- hosts are reachable via ssh on port 22 | TODO
- The swarm manager node is reachable via ssh on port 22 | TODO
- The script is only tested in linux | TODO
- hosts IPs | Adjustable in the .env file
- old version stack is deployed with the name `pg95` and the postgres service is called `db` and the network is called `` | TODO
- new version stack is deployed with the name `pg10` and the postgres service is called `db` and the network is called `pgnet` | TODO
- Postgres Images need to have pglogical2 installed | No way around that without massive changes
- There is only one provider per Cluster | TODO
- There are 0 or more subscriber per Cluster | TODO
- Scripts expect the provider to be the last instance that is upgraded. | TODO
- Scripts uses the docker node label `pg_ver` to mark where to run which version | TODO
- Keepaliveds VIP & interface and `sub_setup.sh:get_ip` must be matched with what is running on the postgres machines! | TODO
- Tested version does only include anonymous mounts! | TODO
- The script will expect certain scripts at certain locations, have a look at 'TODO.png'! | TODO
- (only Setup.sh?) Scripts will expect to be root on the host machines | TODO
- (Setup.sh) Must match existing virtualbox instance names | TODO

## Setup, Testing, Developing

The logical center of execution is the setup.sh script.

Usage (setup.sh -h):
```
This script sets up the environment (machines and docker swarm) to start a PostgreSQL Cluster for certain experiments.
--------------------
Flags:
-m  will start the VMs first (Only works on MacOS and Linux with VirtualBoxManager so far).
-s  will initialize the swarm cluster ontop of the running VMS.
-p  will start the postgres cluster <als letztes>.
-h  will print this help
```

To start up the full cluster execute `setup.sh -msp`, to only e.g. reset Postgres container only execute `setup.sh -p`. This will setup & start the VMs, Docker Swarm, Keepalived and Postgres containers. The full execution `-msp` may take a few minutes, the most time is needed when the `-p` flag is set.

After the start setup.sh will source test_scripts/test_client_lib.sh. For more info on that have a look into test_scripts/README.md

## Virtual Machines

The VMs in use are setup by the `vm_setup.sh` script, that may be replaced with configuration tooling in the future. It e.g. sets firewall rules, sets certain hostnames and checks connectivity to the internet. This script is more of collection of notes in bash form. 

More interesting is the `vms.sh` script which is e.g. able to check if the VMs are started and shut them down. More detailed information including flags, have a look at `vms.sh -h`.

## Testing

Tests are written in [bats](https://github.com/sstephenson/bats).
