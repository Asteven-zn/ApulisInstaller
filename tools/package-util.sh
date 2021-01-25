#!/bin/bash
#
set -o nounset
set -o errexit
#set -o xtrace

DOCKER_CMD=docker

function usage() {
    cat <<EOF
Usage: package-util COMMAND [args]

installation package operation:
    sys-pkg		To extract system dependency packages

Use "package-util help <command>" for more information about a given command.
EOF
}

function help-info() {
    case "$1" in
        (sys-pkg)
            echo -e "Usage: package-util sys-pkg\n\n"
            ;;
        (py2-pkg)
            echo -e "Usage: package-util py2-pkg\n\n"
            ;;
        (py3-pkg)
            echo -e "Usage: package-util py3-pkg\n\n"
            ;;
        (*)
            usage
            return 0
            ;;
    esac
}

function process_cmd() {
    echo -e "[INFO] \033[33m$ACTION\033[0m : $CMD"
    $CMD || { echo -e "[ERROR] \033[31mAction failed\033[0m : $CMD"; return 1; }
    echo -e "[INFO] \033[32mAction successed\033[0m : $CMD"
}

### package operation functions ##############################

function sys-pkg() {
    # check new node's address regexp
    [[ -f $BASEPATH/resources/apt/Dockerfile ]] || { echo "[ERROR] Missing docker file!"; return 1; }

    echo "[INFO] build a temporary image" && \
    $DOCKER_CMD build $BASEPATH/resources/apt -t apulis-sys-pkg:v1.0.0 && \
    echo "[INFO] run a temporary container" && \
    $DOCKER_CMD run -d --name temp_sys_bin apulis-sys-pkg:v1.0.0 && \
    echo "[INFO] cp system deb files" && \
    mkdir -p $HOME/Downloads/ && \
    $DOCKER_CMD cp temp_sys_bin:/packages $HOME/Downloads/ && \
    echo "[INFO] stop&remove temporary container" && \
    $DOCKER_CMD rm -f temp_sys_bin
}

### Main Lines ##################################################

BASEPATH=$(dirname $(readlink -f "$0"))/../

[ "$#" -gt 0 ] || { usage >&2; exit 2; }

case "$1" in
    ### in-cluster operations #####################
    (sys-pkg)
        [ "$#" -gt 0 ] || { usage >&2; exit 2; }
        ACTION="Action: prepare system dependency package"
        CMD="sys-pkg ${@:2}"
        ;;
    (py-pkg)
        [ "$#" -gt 0 ] || { usage >&2; exit 2; }
        ACTION="Action: prepare python dependency package"
        CMD="py-pkg ${@:2}"
        ;;
    (help)
        [ "$#" -gt 1 ] || { usage >&2; exit 2; }
        help-info $2
        exit 0
        ;;
    (*)
        usage
        exit 0
        ;;
esac

process_cmd

