# Setup, test and interact 

## Application

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
