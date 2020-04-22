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