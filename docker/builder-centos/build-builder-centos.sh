#!/usr/bin/env bash

if [[ -n "${JENKINS_URL}" ]]; then
	export PS4='+ ${BASH_SOURCE##*/}:${LINENO}:(${FUNCNAME[0]:-"?"}):'
else
	export PS4='\[\e[0;33m\]+ ${BASH_SOURCE##*/}:${LINENO}:(${FUNCNAME[0]:-"?"}):\[\e[0m\] '
fi

set -e

script_name="${0##*/}"
DOCKER_TOP=${DOCKER_TOP:-"$(cd "${BASH_SOURCE%/*}/.." && pwd)"}

project_name="builder-centos"
project_from="centos"
project_description="Builds a CentOS based docker image for compiling linux kernel, creating test rootfs, running QEMU."

PROJECT_TOP="${DOCKER_TOP}/${project_name}"
VERSION=${VERSION:-"8.1"}
DOCKER_NAME=${DOCKER_NAME:-"tdd-${project_name}"}

build_on_exit() {
	true
}

docker_build_setup() {
	true
}

host_install_extra() {
	true
}

source ${DOCKER_TOP}/build-common.sh
