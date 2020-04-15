# Seperate Container

## Problem

To upgrade from one PostgreSQL Version to another this solution uses a seperate container to upgrade the postgresql data. 

## Folder content

This folder contains following contents:
- Folder "gen_docker": Contains files to build a specific docker image to update a docker volume from one version to another.
- Folder "tests": Contains the files necessary for testing the solution

## Testscenarios

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


