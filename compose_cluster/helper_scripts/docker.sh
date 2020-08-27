#!/bin/sh

gather_running_containers() {
    docker ps --format "table {{.ID}}\t{{.Names}}"
}

# $1 = Container name
kill_pg_by_name(){
    if [ "$2" == "smart" ] || [ "$3" == "smart" ]; then
        stop_pg_container "$1" smart
    else 
        stop_pg_container "$1"
    fi
    
    # Old Idea via Scale
    #if [ "$2" != "-c" ]; then
    #    old_scale=$(get_service_scale)
    #    scale_service_with_timeout "$1" $(($old_scale-1))
    #fi
}

# $1 = major version according to naming in stackfile and servicename in stackfile.
start_new_subscriber(){
    # Scale the subscriber service up by one
    # Test: (Re-) Start of Subscribers that creates subscription
    # Test: Subscriber also receives als data before start.
    echo "This may take a few moments and consider deployment-constraints / ports usage which could prevent a success!"
    old_scale=$(get_service_scale)
    new_scale=$(($old_scale + 1))
    scale_service_with_timeout "$1" $new_scale
    echo scale
    wait_for_all_pg_to_boot
    echo "done"
}

wait_for_all_pg_to_boot(){
    for tuple in $(get_all_tuples); do
        container_id=$(get_id "$tuple")
        node=$(get_node "$tuple")
        while true; do
            result="$(docker exec $container_id pg_isready)"
            if [[ "$result" == *"- accepting connections"* ]]; then
                printf "."
                break
            fi
            sleep 2s
        done
    done
    echo ""
}

stop_pg_container(){
    tuple=$(get_tuple_from_name $1)
    id=$(get_id $tuple)
    echo $tuple
    
    if [ "$2" == "smart" ]; then
        docker exec $id pg_ctl stop -m smart
    else
        docker rm -f $id
    fi
}

get_service_scale(){
    scale=0
    for tuple in $(get_all_tuples); do
        if [[ "$tuple" == *"$1"* ]]; then
            scale=$(($scale+1))
        fi
    done
    echo $scale
}

# $1 = major version according to naming in stackfile and servicename in stackfile.
scale_service_with_timeout(){
    if  [ -z "$1" ]; then
        echo "Missing Version!"
    else
        timeout 25s docker-compose -f stacks/stack$1_compose.yml up --scale db$1=$2 -d #--remove-orphans
        exit_code="$?"
        if [ "$exit_code" -gt 0 ]; then
            echo "Could not scale the service! Exit Code was: $exit_code"
        fi
    fi
}

