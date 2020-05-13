# Test Scripts

This folder contains scripts to interact and test the deployed postgres containers.
The main logic can be find in test_client_lib.sh. *BEWARE as the mentioned filed is supposed to be sourced from the ../setup.sh file!*

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

see /cluster/upgrade/README.md

## Major Upgrade Tests

see /cluster/upgrade/README.md
