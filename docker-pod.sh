#!/bin/bash

set -o errexit

help() {
    cat <<EOF
Usage: docker pod <command> <pod_name> [<container_name>] [<options>]

Supported commands:
    create    Create a new pod
    add       Add a new container to the pod
    remove    Remove a container from the pod
    delete    Remove the whole pod
    list      List containers in a pod
    logs      Display logs for a container in the pod
    exec      Enter an existing container to the pod
    run       Run an interactive container in the pod
EOF
}

pod_exists() {
    local pod_name=$1
    
    return $(( 2 - $(docker ps --filter name=pod_${pod_name}_sleeper | wc -l) ))
}

help_create() {
    cat <<EOF
Usage: docker pod create <pod_name> [<options>]

Options:
    --help    Display this message
EOF
}

pod_create() {
    local pod_name=$1
    shift

    case "$1" in
        "")
            :
        ;;
        --help)
            help_create
            exit
        ;;
        *)
            help_create
            exit 1
        ;;
    esac

    if pod_exists "${pod_name}"; then
        >&2 echo "ERROR: Pod ${pod_name} already exists."
        exit 1
    fi

    docker run -d --name pod_${pod_name}_sleeper ubuntu bash -c 'sleep infinity'
}

help_add() {
    cat <<EOF
Usage: docker pod add <pod_name> <container_name> [<docker_options>] <image_name> [<arguments>]

Options:
  -h, --help           Display this message

Docker options:
EOF
docker run --help | tail -n +7 | grep -v -- --help
}

pod_add() {
    local pod_name=$1
    shift
    local container_name=$1
    shift

    case "$1" in
        -h|--help)
            help_add
            exit
        ;;
    esac

    if test "$#" -eq 0; then
        >&2 echo "ERROR: Missing image name."
        help_add
        exit 1
    fi

    if ! pod_exists "${pod_name}"; then
        >&2 echo "ERROR: Pod ${pod_name} does not exist."
        exit 1
    fi

    docker run -d --name pod_${pod_name}_${container_name} --network container:pod_${pod_name}_sleeper --pid container:pod_${pod_name}_sleeper "$@"
}

help_remove() {
    cat <<EOF
Usage: docker pod remove <pod_name> <container_name>

Options:
    --help    Display this message
EOF
}

pod_remove() {
    local pod_name=$1
    shift
    local container_name=$1
    shift

    case "$1" in
        --help)
            help_remove
            exit
        ;;
    esac

    if test "$#" -gt 0; then
        >&2 echo "ERROR: Too many arguments."
        help_remove
        exit 1
    fi

    if ! pod_exists "${pod_name}"; then
        >&2 echo "ERROR: Pod ${pod_name} does not exist."
        exit 1
    fi

    docker rm -f pod_${pod_name}_${container_name}
}

help_delete() {
    cat <<EOF
Usage: docker pod delete <pod_name> [<options>]

Options:
    --help    Display this message
EOF
}

pod_delete() {
    local pod_name=$1
    shift

    case "$1" in
        "")
            :
        ;;
        --help)
            help_delete
            exit
        ;;
        *)
            help_delete
            exit 1
        ;;
    esac

    if ! pod_exists "${pod_name}"; then
        >&2 echo "ERROR: Pod ${pod_name} does not exist."
        exit 1
    fi

    docker ps --filter name=pod_${pod_name} --all --quiet | xargs docker container rm --force
}

help_list() {
    cat <<EOF
Usage: docker pod list <pod_name> [<options>]

Options:
    --help    Display this message

Docker options:
EOF
docker ps --help | tail -n +8
}

pod_list() {
    local pod_name=$1
    shift

    case "$1" in
        "")
            :
        ;;
        --help)
            help_list
            exit
        ;;
        *)
            help_list
            exit 1
        ;;
    esac

    if ! pod_exists "${pod_name}"; then
        >&2 echo "ERROR: Pod ${pod_name} does not exist."
        exit 1
    fi

    docker ps --filter name=pod_${pod_name} --all
}

help_logs() {
    cat <<EOF
Usage: docker pod logs <pod_name> <container_name> [<options>]

Options:
  -h, --help           Display this message

Docker options:
EOF
docker logs --help | tail -n +7
}

pod_logs() {
    local pod_name=$1
    shift
    local container_name=$1
    shift

    echo "$1"

    case "$1" in
        -h|--help)
            help_logs
            exit
        ;;
    esac

    if ! pod_exists "${pod_name}"; then
        >&2 echo "ERROR: Pod ${pod_name} does not exist."
        exit 1
    fi

    docker logs pod_${pod_name}_${container_name} "$@"
}

help_exec() {
    cat <<EOF
Usage: docker pod exec <pod_name> <container_name> [<options>] <command> [<arguments>]

Options:
  -h, --help           Display this message
EOF
}

pod_exec() {
    local pod_name=$1
    shift
    local container_name=$1
    shift

    case "$1" in
        --help)
            help_exec
            exit
        ;;
    esac

    if test "$#" -eq 0; then
        >&2 echo "ERROR: Missing arguments."
        help_exec
        exit 1
    fi

    if ! pod_exists "${pod_name}"; then
        >&2 echo "ERROR: Pod ${pod_name} does not exist."
        exit 1
    fi

    docker exec -it pod_${pod_name}_${container_name} "$@"
}

help_run() {
    cat <<EOF
Usage: docker pod run <pod_name> [<docker_options>] <image_name> <command> [<arguments>]

Options:
  -h, --help                           Display this message

Docker options:
EOF
docker run --help | tail -n +7 | grep -v -- --help | grep -v -- --interactive | grep -v -- --tty | grep -v -- --network | grep -v -- --pid | grep -v -- --rm
}

pod_run() {
    local pod_name=$1
    shift

    case "$1" in
        -h|--help)
            help_run
            exit
        ;;
    esac

    if test "$#" -lt 2; then
        >&2 echo "ERROR: Missing command line arguments."
        help_run
        exit 1
    fi

    if ! pod_exists "${pod_name}"; then
        >&2 echo "ERROR: Pod ${pod_name} does not exist."
        exit 1
    fi

    docker run -it --rm --network container:pod_${pod_name}_sleeper --pid container:pod_${pod_name}_sleeper "$@"
}

case "${1}" in
    docker-cli-plugin-metadata)
        cat <<-EOF
{
    "SchemaVersion":"0.1.0",
    "Vendor":"Nicholas Dille",
    "Version":"0.7.0",
    "ShortDescription":"Manage pods",
    "URL":"https://github.com/nicholasdille/docker-pod"
}
EOF
    exit
    ;;
esac

# Remove "pod" from arguments
shift

case "$1" in
    install)
        echo TODO: INSTALL
    ;;
    create|add|remove|delete|list|logs|exec|run)
        verb=$1
        shift

        if test "$1" == "--help"; then
            eval "help_${verb}"
        fi

        if test "$#" -eq 0; then
            >&2 echo "ERROR: Missing pod name."
            help
            exit 1
        fi

        pod_name=$1
        shift
    ;;
    *)
        >&2 echo "ERROR: Missing or unsupported verb."
        help
        exit
    ;;
esac

case ${verb} in
    add|remove|logs|exec|run)
        if test "$#" -eq 0; then
            >&2 echo "ERROR: Missing container name."
            help
            exit 1
        fi
        container_name=$1
        shift
    ;;
esac

case "${verb}" in
    create)
        pod_create "${pod_name}" "$@"
    ;;
    add)
        pod_add "${pod_name}" "${container_name}" "$@"
    ;;
    remove)
        pod_remove "${pod_name}" "${container_name}"
    ;;
    delete)
        pod_delete "${pod_name}"
    ;;
    list)
        pod_list "${pod_name}" "$@"
    ;;
    logs)
        pod_logs "${pod_name}" "${container_name}" "$@"
    ;;
    exec)
        pod_exec "${pod_name}" "${container_name}" "$@"
    ;;
    run)
        pod_run "${pod_name}" "${container_name}" "$@"
    ;;
esac