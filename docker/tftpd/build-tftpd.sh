#!/usr/bin/env bash

set -e

script_name="${0##*/}"
DOCKER_TOP=${DOCKER_TOP:-"$(cd "${BASH_SOURCE%/*}/.." && pwd)"}

project_name="tftpd"
project_from="alpine"
project_description="Builds a minimal docker image that contains tftpd-hpa."

PROJECT_TOP="${DOCKER_TOP}/${project_name}"
VERSION=${VERSION:-"1"}
DOCKER_NAME=${DOCKER_NAME:-"tdd-tftpd"}

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
