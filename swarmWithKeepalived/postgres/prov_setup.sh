#!/bin/bash

#ls -a /etc/
#ls -a /etc/postgresql 
#cat /etc/postgresql/postgresql.conf

set -e

echo "host  replication  all  0.0.0.0/0  md5" >> /var/lib/postgresql/data/pg_hba.conf

show_status() {
    sleep 20s
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -c "
        SELECT * FROM pg_replication_slots;
    "
}

init_provider() {
    # Alternativly add tables with: 
    # SELECT pglogical.replication_set_add_table('default', 'testtable', true);
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -c "
        -- PG LOGICAL

        CREATE EXTENSION pglogical;

        SELECT pglogical.create_node(
            node_name := 'provider95',
            dsn := 'host=196.168.99.149 port=5433 dbname=testdb password=pass user=primaryuser'
        );


        SELECT pglogical.replication_set_add_all_tables('default', ARRAY['public']);

        SELECT pglogical.show_subscription_status();"
}

init_provider

show_status &
