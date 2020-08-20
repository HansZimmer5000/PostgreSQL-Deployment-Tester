# !/bin/sh 
# This is meant to be 'sourced'!

# execute_sql will execute an SQL statement on a given Postgres container on a given Docker Swarm node in the database 'testdb'
# $1 = Docker Sawrm nodes IP
# $2 = Container ID 
# $3 = SQL statement
# Context: SETUP, TEST, UPGRADE
execute_sql() {
    $SSH_CMD root@$1 docker exec $2 "psql -v ON_ERROR_STOP=1 --username postgres --dbname testdb -c '$3'"
}
