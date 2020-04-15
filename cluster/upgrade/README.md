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

0. Major Upgrade of Postgres (in /upgrade/tests/simple_test.sh)
1. Major Upgrade of running Subscriber
2. Higher Provider, lower Subscriber, execute normal tests again? 
3. Lower Provider, higher Subscriber, execute normal tests again?
4. Major Update of Cluster (How much downtime?)
    - Update Subscriber
    - Promote Subscriber
    - Update Provider
    - Degrade Provider


