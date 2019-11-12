#!/usr/bin/env bash

usage () {
	local old_xtrace
	local old_xtrace="$(shopt -po xtrace || :)"
	set +o xtrace
	echo "${script_name} - ${project_description}" >&2
	echo "Usage: ${script_name} [flags]" >&2
	echo "Option flags:" >&2
	echo "  -h --help     - Show this help and exit." >&2
	echo "  -p --purge    - Remove existing docker image and rebuild." >&2
	echo "  -r --rebuild  - Rebuild existing docker image." >&2
	echo "  -t --tag      - Print Docker tag to stdout and exit." >&2
	echo "  -v --verbose  - Verbose execution." >&2
	echo "  --install     - Install systemd service files." >&2
	echo "  --start       - Start systemd services." >&2
	echo "  --enable      - Enable systemd services." >&2
	echo "Environment:" >&2
	echo "  DOCKER_FILE   - Default: '${DOCKER_FILE}'" >&2
	echo "  DOCKER_FROM   - Default: '${DOCKER_FROM}'" >&2
	echo "  DOCKER_TAG    - Default: '${DOCKER_TAG}'" >&2
	if [[ -n ${JENKINS_USER} ]];then
	echo "  JENKINS_USER  - Default: '${JENKINS_USER}'" >&2
	fi
	echo "Examples:" >&2
	echo "  ${script_name} -v"

	eval "${old_xtrace}"
}

process_opts() {
	local short_opts="chvprt"
	local long_opts="check,help,verbose,purge,rebuild,tag,install,start,enable"

	local opts
	opts=$(getopt --options ${short_opts} --long ${long_opts} -n "${script_name}" -- "$@")

	eval set -- "${opts}"

	while true ; do
		case "${1}" in
		-c | --check)
			check=1
			shift
			;;
		-h | --help)
			usage=1
			shift
			;;
		-v | --verbose)
			verbose=1
			set -x
			shift
			;;
		-p | --purge)
			purge=1
			shift
			;;
		-r | --rebuild)
			rebuild=1
			shift
			;;
		-t | --tag)
			tag=1
			shift
			;;
		--install)
			install=1
			shift
			;;
		--start)
			install=1
			start=1
			shift
			;;
		--enable)
			install=1
			enable=1
			shift
			;;
		--)
			shift
			if [[ "${1}" ]]; then
				echo "${script_name}: ERROR: Got extra args: '${*}'" >&2
				usage
				exit 1
			fi
			break
			;;
		*)
			echo "${script_name}: ERROR: Internal opts: '${@}'" >&2
			exit 1
			;;
		esac
	done
}

on_exit() {
	local result=${?}

	if [[ -d "${tmp_dir}" ]]; then
		rm -rf "${tmp_dir}"
	fi

	build_on_exit ${result}
	set +x
	echo "${script_name}: Done: ${result}" >&2
}

version () {
	echo "$@" | awk -F. '{ printf("%d%03d%03d%03d\n", $1,$2,$3,$4); }'
}

get_arch() {
	local a=${1}

	case "${a}" in
	arm64|aarch64) echo "arm64" ;;
	amd64|x86_64)  echo "amd64" ;;
	*)
		echo "${script_name}: ERROR: Bad arch '${a}'" >&2
		exit 1
		;;
	esac
}

arch_tag() {
	local a="$(get_arch $(uname -m))"

	case "${a}" in
		*)     echo "-${a}" ;;
	esac
}

docker_from_alpine() {
	local a="$(get_arch $(uname -m))"

	case "${a}" in
		amd64) echo "alpine:latest" ;;
		arm64) echo "arm64v8/alpine:latest" ;;
		*)
			echo "${script_name}: ERROR: Unknown arch ${a}" >&2
			exit 1
			;;
	esac
}

docker_from_centos() {
	local a="$(get_arch $(uname -m))"

	case "${a}" in
		amd64) echo "centos:8" ;;
		arm64) echo "centos:8" ;;
		*)
			echo "${script_name}: ERROR: Unknown arch ${a}" >&2
			exit 1
			;;
	esac
}

docker_from_debian() {
	local a="$(get_arch $(uname -m))"

	case "${a}" in
		amd64) echo "debian:buster" ;;
		arm64) echo "arm64v8/debian:buster" ;;
		*)
			echo "${script_name}: ERROR: Unknown arch ${a}" >&2
			exit 1
			;;
	esac
}

docker_from_debian_jessie() {
	local a="$(get_arch $(uname -m))"

	case "${a}" in
		amd64) echo "debian:jessie" ;;
		*)
			echo "${script_name}: ERROR: Unknown arch ${a}" >&2
			exit 1
			;;
	esac
}

docker_from_jenkins() {
	local a="$(get_arch $(uname -m))"

	case "${a}" in
		amd64) echo "jenkins/jenkins:lts" ;;
		arm64)
			echo "arm64 not available"
			exit 1
			;;
		*)
			echo "${script_name}: ERROR: Unknown arch ${a}" >&2
			exit 1
			;;
	esac
}

docker_from_openjdk() {
	local a="$(get_arch $(uname -m))"

	case "${a}" in
		amd64) echo "openjdk:8-jdk" ;;
		arm64) echo "arm64v8/openjdk:8-jdk" ;;
		*)
			echo "${script_name}: ERROR: Unknown arch ${a}" >&2
			exit 1
			;;
	esac
}

docker_from_opensuse() {
	local a="$(get_arch $(uname -m))"

	case "${a}" in
		amd64) echo "opensuse/leap:15.1" ;;
		arm64) echo "arm64v8/opensuse/leap:15.1" ;;
		*)
			echo "${script_name}: ERROR: Unknown arch ${a}" >&2
			exit 1
			;;
	esac
}

docker_from_ubuntu() {
	local a="$(get_arch $(uname -m))"

	case "${a}" in
		amd64) echo "ubuntu:18.04" ;;
		arm64) echo "arm64v8/ubuntu:18.04" ;;
		*)
			echo "${script_name}: ERROR: Unknown arch ${a}" >&2
			exit 1
			;;
	esac
}

docker_from() {
	local from=${1}

	case "${from}" in
	alpine)
		docker_from_alpine;;
	centos)
		docker_from_centos;;
	debian)
		docker_from_debian;;
	debian_jessie)
		docker_from_debian_jessie;;
	jenkins)
		docker_from_jenkins;;
	openjdk)
		docker_from_openjdk;;
	opensuse)
		docker_from_opensuse;;
	ubuntu)
		docker_from_ubuntu;;
	*)
		echo "${script_name}: ERROR: Bad project_from: '${from}'" >&2
		exit 1
	esac
}

show_tag () {
	echo "${DOCKER_TAG}"
}

run_shellcheck() {
	local file=${1}

	shellcheck="${shellcheck:-shellcheck}"

	if ! test -x "$(command -v "${shellcheck}")"; then
		echo "${script_name}: ERROR: Please install '${shellcheck}'." >&2
		exit 1
	fi

	"${shellcheck}" "${file}"
}

#===============================================================================
if [[ ${JENKINS_URL} ]]; then
	export PS4='+ ${BASH_SOURCE##*/}:${LINENO}:(${FUNCNAME[0]:-"?"}):'
else
	export PS4='\[\e[0;33m\]+ ${BASH_SOURCE##*/}:${LINENO}:(${FUNCNAME[0]:-"?"}):\[\e[0m\] '
fi

trap "on_exit 'Failed.'" EXIT

if [[ ${TDD_BUILDER} && "${project_name}" == "builder"  ]]; then
	echo "${script_name}: ERROR: Building builder in builder not supported." >&2
	exit 1
fi

PROJECT_TOP="${DOCKER_TOP}/${project_name}"
ARCH_TAG="${ARCH_TAG:-$(arch_tag)}"
DOCKER_TAG="${DOCKER_TAG:-${DOCKER_NAME}:${VERSION}${ARCH_TAG}}"

DOCKER_FILE="${DOCKER_FILE:-${PROJECT_TOP}/Dockerfile.${project_name}}"
SERVICE_FILE="${SERVICE_FILE:-${PROJECT_TOP}/tdd-${project_name}.service}"

process_opts "${@}"

DOCKER_FROM="${DOCKER_FROM:-$(docker_from ${project_from})}"

if [[ ${usage} ]]; then
	usage
	exit 0
fi

if [[ ${check} ]]; then
	run_shellcheck "${0}"
	trap "on_exit 'Success'" EXIT
	exit 0
fi

if ! test -x "$(command -v docker)"; then
	echo "${script_name}: ERROR: Please install docker." >&2
	exit 1
fi

if [[ ${tag} ]]; then
	show_tag
	trap - EXIT
	exit 0
fi

tmp_dir="$(mktemp --directory --tmpdir "tdd-${script_name}-XXXX")"

# Support for docker versions older than 17.05.
# See https://github.com/moby/moby/issues/32457
if [[ $(version "$(docker version --format '{{.Server.Version}}')") < $(version "17.05") ]]; then
	tmp_file="${DOCKER_FILE}.tmp"
	trap "rm -f ${tmp_file}" EXIT

	cp -f "${DOCKER_FILE}" "${tmp_file}"
	DOCKER_FILE="${tmp_file}"
	sed --in-place "s|ARG DOCKER_FROM||" "${tmp_file}"
	sed --in-place "s|\${DOCKER_FROM}|${DOCKER_FROM}|" "${tmp_file}"
fi

do_build=1

if [[ ${purge} ]] && docker inspect --type image "${DOCKER_TAG}" &>/dev/null; then
	echo "Removing docker image: ${DOCKER_TAG}" >&2
	docker rmi --force ${DOCKER_TAG}
elif [[ ! ${rebuild} ]] && docker inspect --type image "${DOCKER_TAG}" &>/dev/null; then
	echo "Docker image exists: ${DOCKER_TAG}" >&2
	show_tag
	do_build=
fi

cd "${PROJECT_TOP}"

if [[ ${do_build} ]]; then
	echo "${script_name}: Building docker image: ${DOCKER_TAG}" >&2

	docker_build_setup

	echo "${script_name}: extra_build_args='${extra_build_args}'" >&2

	docker build \
		--file "${DOCKER_FILE}" \
		--build-arg DOCKER_FROM=${DOCKER_FROM} \
		--build-arg http_proxy=${http_proxy} \
		--build-arg https_proxy=${https_proxy} \
		--tag ${DOCKER_TAG} \
		--network=host \
		${extra_build_args} \
		.
fi

if [[ ${install} ]]; then
	host_install_extra
fi

if [[ -f ${SERVICE_FILE} ]]; then
	service_name="${SERVICE_FILE##*/}"
	
	if [[ ${install} ]]; then
		tmp_file="${tmp_dir}/${service_name}"

		cp -f "${SERVICE_FILE}" "${tmp_file}"
		sed --in-place "s/@@docker-tag@@/${DOCKER_TAG}/g" "${tmp_file}"
		sudo cp -f ${tmp_file} /etc/systemd/system/
	fi

	if [[ ${enable} ]]; then
		sudo systemctl reenable "${service_name}"
	fi

	if [[ ${start} ]]; then
		sudo systemctl daemon-reload
		sudo systemctl restart "${service_name}"
		docker ps
		systemctl --no-pager status "${service_name}"
	fi
fi

show_tag

trap "on_exit 'Success.'" EXIT
exit 0
