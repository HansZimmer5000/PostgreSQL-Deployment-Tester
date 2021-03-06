#!/bin/sh

remove_old_subscription(){
    docker exec $1 psql -e -v ON_ERROR_STOP=1 --username postgres --dbname testdb -c "SELECT pglogical.drop_subscription('$2');"

    docker exec $1 psql -e -v ON_ERROR_STOP=1 --username postgres --dbname testdb -c "SELECT pglogical.drop_node('subscriber95');"
}

enable_providing(){
    #TODO have some dynamic way to set dbname, password and user
    docker exec $1 psql -e -v ON_ERROR_STOP=1 --username postgres --dbname testdb -c "SELECT pglogical.create_node(node_name := 'provider95', dsn := 'host=$2 port=5432 dbname=testdb password=pass user=postgres');"

    docker exec $1 psql -e -v ON_ERROR_STOP=1 --username postgres --dbname testdb -c "SELECT pglogical.replication_set_add_all_tables('default', ARRAY['public']);"
}

container_id=$1
subscription_id=$2
virtual_ip="192.168.99.149"

echo "Promoting with:
container_id($container_id)
subscription_id($subscription_id)
virtual_ip($virtual_ip)
"

echo $(remove_old_subscription $container_id $subscription_id)
echo $(enable_providing $container_id $virtual_ip)
