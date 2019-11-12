#!/usr/bin/env bash

set -e

script_name="${0##*/}"
DOCKER_TOP=${DOCKER_TOP:-"$(cd "${BASH_SOURCE%/*}/.." && pwd)"}

project_name="rmt"
project_from="opensuse"
project_description="Builds a docker image that contains the SUSE RMT Repository Mirroring Tool server."

PROJECT_TOP="${DOCKER_TOP}/${project_name}"
VERSION=${VERSION:-"1"}
DOCKER_NAME=${DOCKER_NAME:-"rmt-server"}

curr_dir="$(pwd)"

build_on_exit() {
	true
}

docker_build_setup() {
	true
}

host_install_extra() {
	sudo cp -vf ${curr_dir}/rmt.conf /etc/rmt.conf
}

source ${DOCKER_TOP}/build-common.sh
