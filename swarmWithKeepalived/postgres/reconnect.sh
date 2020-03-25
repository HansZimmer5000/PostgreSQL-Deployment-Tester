echo "Next line may fail if database was not able to start right in the first place"

docker exec $1 psql -e -v ON_ERROR_STOP=1 --username primaryuser --dbname testdb -c "SELECT pglogical.drop_subscription('$2');"

docker exec $1 psql -e -v ON_ERROR_STOP=1 --username primaryuser --dbname testdb -c "SELECT pglogical.create_subscription(subscription_name := '$2',provider_dsn := 'host=192.168.1.149 port=5433 dbname=testdb password=pass user=primaryuser');"

docker exec $1 psql -e -v ON_ERROR_STOP=1 --username primaryuser --dbname testdb -c "SELECT pglogical.wait_for_subscription_sync_complete('$2');"

docker exec $1 psql -e -v ON_ERROR_STOP=1 --username primaryuser --dbname testdb -c "SELECT pglogical.show_subscription_status('$2');"
