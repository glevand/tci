#!/usr/bin/env bash

docker_build_setup() {
	echo "${script_name}: Building unicornscan." >&2

	rm -rf "${PROJECT_TOP}/u-install"

	local builder_tag="$("${DOCKER_TOP}/builder/build-builder.sh" --tag)"

		cat << EOF > "${tmp_dir}/build.sh"
export PS4='\[\e[0;32m\]+ tdd-build-script:\${LINENO}:\[\e[0m\] '
set -x

top_dir="/work"

rm -rf "\${top_dir}/u-build" "\${top_dir}/u-install"
mkdir -p "\${top_dir}/u-build"

pushd "\${top_dir}/u-build"
curl --location --output unicornscan-0.4.7-2.tar.bz2 https://sourceforge.net/projects/osace/files/unicornscan/unicornscan%20-%200.4.7%20source/unicornscan-0.4.7-2.tar.bz2
tar -xf unicornscan-0.4.7-2.tar.bz2
ls -l ./unicornscan-0.4.7
pushd ./unicornscan-0.4.7

sed --in-place 's/inline tsc_t get_tsc/tsc_t get_tsc/g' src/unilib/tsc.c

./configure CFLAGS='-D_GNU_SOURCE' -prefix=/
make
mkdir -p "\${top_dir}/u-install"
make DESTDIR="\${top_dir}/u-install" install

popd
file "\${top_dir}/u-install/bin/unicornscan"
EOF

	docker run --rm \
		--network=host \
		-v ${tmp_dir}:/work -w /work \
		-u $(id --user --real):$(id --group --real) \
		${builder_tag} bash -ex ./build.sh

	cp -av "${tmp_dir}/u-install" "${PROJECT_TOP}/"
}

host_install_extra() {
	true
}

build_on_exit() {
	rm -rf "${PROJECT_TOP}/u-install"
}

set -e

script_name="${0##*/}"
DOCKER_TOP="${DOCKER_TOP:-"$(cd "${BASH_SOURCE%/*}/.." && pwd)"}"

project_name="net-scanner"
project_from="debian"
project_description="Builds a docker image that contains tools for gathering information about a network."

PROJECT_TOP="${DOCKER_TOP}/${project_name}"
VERSION="${VERSION:-1}"
DOCKER_NAME="${DOCKER_NAME:-tdd-net-scanner}"

source "${DOCKER_TOP}/build-common.sh"
