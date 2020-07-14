# Test Scripts

This folder contains scripts to interact and test the deployed postgres containers.
The main logic can be find in test_client_lib.sh. *BEWARE as the mentioned filed is supposed to be sourced from the ../setup.sh file!*

TODO update or better reference to help in setup.sh
Usage:
```
-- Interact with Container 
start:      will start a new postgres container. 
            BEWARE as container expose ports via host mode which limits the container per VM to one!
        
kill:       [0=provider,1=db.1,2=db.2,...] 
            will reduce the replica count of the swarm stack and kill a given container by its number in its name 'db.X'. Also set '-c' to crash-kill a container and not adjust the replica count.
        
reset:      [number]
            will reset the cluster to one provider and a given number of subscribers (default 1)
  
reconnect:  []
            will reconnect all subscriber to the virtual IP (more info about that in ../keepalived/).

-- Interact with VMs

ssh:    [1=dsn1, 2=dsn2, ...]
        will ssh into the given node by its name which was set in the ../.env file.
        

-- Get Info about VMs & Containers

vip:    will return the owner of the virtual IP.
    
status: [-a,-o,-f] 
        will return the status of the containers. Either fast (-f, without update info), verbose (-a, also lists all VM IPs) and continously (-o, as -a but never stops)
        
log:    [1=db.1,2=db.2,...]
        will return the docker log of the given container by its number in its name 'db.X'.
        
notify: [1=db.1,2=db.2,...]
        will return the keepalived 'notify_log.txt' file of a given node by its name which was set in the ../.env file.

table:  [1=db.1,2=db.2,...]
        will return the current content of the 'testtable' in the postgres container by its number in its name 'db.X'.

-- Test Cluster

check:      will check if the shown roles by 'status' are correct and replication works as expected.
    
test:       [1-4]
            will execute the normal integration test(s). Either a single one by providing a number or all by not providing a number.
        
up_test:    [1,4]
            will execute the upgrade integration test(s). Behaves like 'test'.
        
-- Misc.

end:    will exit this script.
```

## Testscenarios

### Normal Tests

1. Check if roles of Postgres are really what they are
2. Check if new subscriber gets old and new data.
3. Check if new provider actually gets recognized as new provider.
4. Check if new provider has old data.

### Major Upgrade Tests

Lower/Default Version: 9.5.18
Higher Major Version: 10.12

0. Done - Major Upgrade of Postgres (in /tests/simple_test.sh)
1. TODO - Major Upgrade of Postgres in Swarm
2. TODO - Major Upgrade of running Subscriber
3. TODO - Higher Provider, lower Subscriber, execute normal tests again? 
4. TODO - Lower Provider, higher Subscriber, execute normal tests again?
5. TODO - Major Update of Cluster (How much downtime?)
    - Update Subscriber
    - Promote Subscriber
    - Update Provider
    - Degrade Provider

## In-Place

Start the Docker container.
```shell
docker run \
    --rm \
    -it \
    -e POSTGRES_PASSWORD=pw \
    -e PGDATA=/var/lib/postgresql/9.5/data \
    postgres:9.5 bash
```

Execute inside the Docker container to upgrade:

```shell
# Start PostgreSQL
su - postgres -c "
PGDATA=/var/lib/postgresql/9.5/data /usr/lib/postgresql/9.5/bin/pg_ctl init
PGDATA=/var/lib/postgresql/9.5/data /usr/lib/postgresql/9.5/bin/pg_ctl start
"
# Fill Database
su - postgres -c "pgbench -i -s 10"
psql -U postgres \postgres -c  "SELECT COUNT (*) FROM pgbench_accounts"
# Install new Major Version
echo "deb http://apt.postgresql.org/pub/repos/apt/ stretch-pgdg main 10" > /etc/apt/sources.list.d/pgdg.list
apt-get update
apt-get install -y --no-install-recommends --no-install-suggests postgresql-10
rm -rf /var/lib/apt/lists/* #There was nothing there. Why is this line here then?
# Upgrade 
su - postgres -c "
export PGBINOLD=/usr/lib/postgresql/9.5/bin
export PGBINNEW=/usr/lib/postgresql/10/bin
export PGDATAOLD=/var/lib/postgresql/9.5/data
export PGDATANEW=/var/lib/postgresql/10/data
mkdir -p "$PGDATAOLD" "$PGDATANEW"
chown -R postgres:postgres /var/lib/postgresql
PGDATA=/var/lib/postgresql/9.5/data /usr/lib/postgresql/9.5/bin/pg_ctl stop
PGDATA=/var/lib/postgresql/10/data /usr/lib/postgresql/10/bin/pg_ctl init
/usr/lib/postgresql/10/bin/pg_upgrade
"
# Start new Postgres
su - postgres -c "
PGDATA=/var/lib/postgresql/10/data /usr/lib/postgresql/10/bin/pg_ctl start
"
psql -U postgres \postgres -c  "SELECT COUNT (*) FROM pgbench_accounts"
```

## Major Upgrade Tests

see /cluster/upgrade/README.md
