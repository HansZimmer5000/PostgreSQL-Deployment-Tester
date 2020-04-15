PG_OLD_MAJOR_VERSION="$1"
PG_NEW_MAJOR_VERSION="$2"

# Set Default Value for Variable, mainly here to be able to set a global var from inside a function
Dockerfile=UpgradeFrom9.dockerfile 

new_version_is_higher() {
    if [ $(bc <<< "$PG_OLD_MAJOR_VERSION < $PG_NEW_MAJOR_VERSION") -eq 1 ]; then
        echo true
    else 
        echo false
    fi
}

select_dockerfile() {
    if [ $(bc <<< "$PG_OLD_MAJOR_VERSION >= 10") -eq 1 ]; then
        Dockerfile=UpgradeFromAbove9.dockerfile
    else
        Dockerfile=UpgradeFrom9.dockerfile
    fi
}

build_image() {
    docker build \
        -f ./$Dockerfile \
        --build-arg PG_NEW_MAJOR_VERSION=$PG_NEW_MAJOR_VERSION \
        --build-arg PG_OLD_MAJOR_VERSION=$PG_OLD_MAJOR_VERSION \
        -t pg_vol_upgrader:$PG_OLD_MAJOR_VERSION-$PG_NEW_MAJOR_VERSION \
        .
}

# Currently unused
show_images() {
    docker images
}

if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Err: Need two versions!"
    exit 1
fi

echo # For new Line
echo "Create Image to Upgrade PostgresV$PG_OLD_MAJOR_VERSION to PostgresV$PG_NEW_MAJOR_VERSION"
if $(new_version_is_higher); then
    select_dockerfile
    echo "Building file with $Dockerfile"
    build_image
else
    echo "$PG_NEW_MAJOR_VERSION was not higher than $PG_OLD_MAJOR_VERSION"
    echo "Downgrade is not possible with this tool (pg_upgrade)"
fi
echo # For new line