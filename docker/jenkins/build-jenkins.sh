#!/usr/bin/env bash

set -e

name="${0##*/}"
DOCKER_TOP=${DOCKER_TOP:-"$(cd "${BASH_SOURCE%/*}/.." && pwd)"}

project_name="jenkins"
project_from="openjdk"
project_description="Builds a docker image that contains Jenkins for the TDD Project."

PROJECT_TOP="${DOCKER_TOP}/${project_name}"
VERSION=${VERSION:-"1"}
DOCKER_NAME=${DOCKER_NAME:-"tdd-jenkins"}

JENKINS_USER=${JENKINS_USER:-'tdd-jenkins'}

if ! getent passwd ${JENKINS_USER} &> /dev/null; then
	echo "${script_name}: WARNING: User '${JENKINS_USER}' not found." >&2
	echo "${script_name}: WARNING: Run useradd-jenkins.sh to add." >&2
fi

extra_build_args="\
	--build-arg user=$(id --user --real --name ${JENKINS_USER}) \
	--build-arg uid=$(id --user --real ${JENKINS_USER}) \
	--build-arg group=$(id --group --real --name ${JENKINS_USER}) \
	--build-arg gid=$(id --group --real ${JENKINS_USER}) \
	--build-arg host_docker_gid=$(stat --format=%g /var/run/docker.sock) \
"

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
