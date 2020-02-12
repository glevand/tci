#!/usr/bin/env bash

build_on_exit() {
	rm -f "${tmp_image}"
}

docker_build_setup() {

	if [[ ! -f "${tmp_image}" ]]; then
		echo "${script_name}: Building tdd-relay image." >&2

		local builder_tag="$("${DOCKER_TOP}/builder/build-builder.sh" --tag)"

		cp -a "${relay_src}"/* "${tmp_dir}"/

		cat << EOF > "${tmp_dir}/build.sh"
./bootstrap
./configure --enable-debug
make
EOF

		docker run --rm \
			-v ${tmp_dir}:/work -w /work \
			-u $(id --user --real):$(id --group --real) \
			${builder_tag} bash -ex ./build.sh

		cp -vf "${tmp_dir}/tdd-relay" "${tmp_image}"
	fi
}

host_install_extra() {
	sudo cp -vf "${relay_src}/tdd-relay.conf.sample" "/etc/tdd-relay.conf"
}

set -e

script_name="${0##*/}"
DOCKER_TOP="${DOCKER_TOP:-"$(cd "${BASH_SOURCE%/*}/.." && pwd)"}"

project_name="relay"
#project_from="alpine"
project_from="debian" # for debugging
project_description="Builds a docker image that contains the TDD relay service."

PROJECT_TOP="${DOCKER_TOP}/${project_name}"
VERSION="${VERSION:-1}"
DOCKER_NAME="${DOCKER_NAME:-tdd-relay}"

tmp_image="${PROJECT_TOP}/tdd-relay"
relay_src="$(cd "${PROJECT_TOP}/../../${project_name}" && pwd)"

source "${DOCKER_TOP}/build-common.sh"
