# Test Scripts

This folder contains scripts to interact and test the deployed postgres containers.
The main logic can be find in test_client.sh. *These scripts are meant to be "sourced" from test_client.sh and not executed on their own!*

## Testscenarios

### Normal Tests

1. Check if roles of Postgres are really what they are
2. Check if new subscriber gets old and new data.
3. Check if new provider actually gets recognized as new provider.
4. Check if new provider has old data.

### Major Upgrade Tests

Lower/Default Version: 9.5.18
Higher Major Version: 10.13

1. Major Upgrade of running Subscriber
2. Major Upgrade of running Cluster

## Upgrading Variation In-Place (not implemented, here as an archived info)

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


