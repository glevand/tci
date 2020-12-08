#!/usr/bin/env bash

usage () {
	local old_xtrace
	old_xtrace="$(shopt -po xtrace || :)"
	set +o xtrace
	echo "${script_name} - Runs a yocto-builder container.  If no command is provided, runs an interactive container with the current directory as the container's working directory." >&2
	echo "Usage: ${script_name} [flags] -- [command] [args]" >&2
	echo "Option flags:" >&2
	echo "  -h --help           - Show this help and exit." >&2
	echo "  -v --verbose        - Verbose execution." >&2
	echo "  -a --docker-args    - Args for docker run. Default: '${docker_args}'" >&2
	echo "  -n --container-name - Container name. Default: '${container_name}'." >&2
	echo "  -t --docker-tag     - Docker tag. Default: '${docker_tag}'." >&2
	echo "  -r --as-root        - Run as root user." >&2
	echo "Args:" >&2
	echo "  command             - Default: '${user_cmd}'" >&2
	echo "Examples:" >&2
	echo "  ${script_name} -v" >&2
	eval "${old_xtrace}"
}

process_opts() {
	local short_opts="hva:n:t:r"
	local long_opts="help,verbose,docker-args:,container-name:,docker-tag:,as-root"

	local opts
	if ! opts=$(getopt --options ${short_opts} --long ${long_opts} -n "${script_name}" -- "$@"); then
		echo "${script_name}: ERROR: Internal getopt" >&2
		exit 1
	fi

	eval set -- "${opts}"

	while true ; do
		#echo "${FUNCNAME[0]}: @${1}@ @${2}@"
		case "${1}" in
		-h | --help)
			usage=1
			shift
			;;
		-v | --verbose)
			set -x
			#verbose=1
			shift
			;;
		-a | --docker-args)
			docker_args="${2}"
			shift 2
			;;
		-n | --container-name)
			container_name="${2}"
			shift 2
			;;
		-t | --docker-tag)
			docker_tag="${2}"
			shift 2
			;;
		-r | --as-root)
			as_root=1
			shift
			;;
		--)
			shift
			user_cmd="${*}"
			break
			;;
		*)
			echo "${script_name}: ERROR: Internal opts: '${*}'" >&2
			exit 1
			;;
		esac
	done
}

on_exit() {
	local result=${1}

	if [ -d "${tmp_dir}" ]; then
		rm -rf "${tmp_dir}"
	fi

	echo "${script_name}: ${result}" >&2
}

#===============================================================================
export PS4='\[\e[0;33m\]+ ${BASH_SOURCE##*/}:${LINENO}:(${FUNCNAME[0]:-"?"}):\[\e[0m\] '
script_name="${0##*/}"

if [ "${TDD_YOCTO_BUILDER}" ]; then
	echo "${script_name}: ERROR: Already in yocto-builder." >&2
	exit 1
fi

SCRIPTS_TOP=${SCRIPTS_TOP:-"$(cd "${BASH_SOURCE%/*}" && pwd )"}

trap "on_exit 'Done, failed.'" EXIT
set -e

process_opts "${@}"

container_name=${container_name:-"yocto-builder-jessie"}
docker_tag=${docker_tag:-"glevand/yocto-builder-jessie:latest"}
histfile=${histfile:-"$(pwd)/${container_name}--bash_history"}
user_cmd=${user_cmd:-"/bin/bash"}

unset docker_extra_args

if [[ ${usage} ]]; then
	usage
	trap - EXIT
	exit 0
fi

tmp_dir="$(mktemp --tmpdir --directory "${script_name}.XXXX")"

if [[ ! ${SSH_AUTH_SOCK} ]]; then
	echo "${script_name}: ERROR: SSH_AUTH_SOCK not defined." >&2
fi

if ! echo "${docker_args}" | grep -q ' -w '; then
	docker_extra_args+=" -v '$(pwd)':'$(pwd)' -w '$(pwd)'"
fi

ansi_reset='\[\e[0m\]'
ansi_red='\[\e[1;31m\]'
ansi_green='\[\e[0;32m\]'
ansi_blue='\[\e[0;34m\]'
ansi_teal='\[\e[0;36m\]'

cp "${HOME}/.bashrc" "${tmp_dir}/"
echo "PS1='${ansi_red}\h@\${P_HOST}:${ansi_reset}\w\$ '" > "${tmp_dir}/.bashrc"

unset docker_user_args
if [[ ${as_root} ]]; then
	docker_bash_args=" -v ${tmp_dir}/.bashrc:/root/.bashrc"
else
	docker_user_args=" \
	-u $(id --user --real):$(id --group --real) \
	-v ${HOME}/.ssh:${HOME}/.ssh:ro \
	-v /etc/group:/etc/group:ro \
	-v /etc/passwd:/etc/passwd:ro \
	-v /etc/shadow:/etc/shadow:ro \
	"
	docker_bash_args=" -v ${tmp_dir}/.bashrc:${HOME}/.bashrc"
fi

# Use the host's systemd-resolved to get /etc/hosts.
if grep -E '127.0.0.53' /etc/resolv.conf; then
	docker_extra_args+=" --dns 127.0.0.53"
fi

echo "${script_name}: INFO: docker_extra_args = '${docker_extra_args}'" >&2

#xhost + local:docker

unset docker_kvm_args
if [[ -c "/dev/kvm" ]]; then
	docker_kvm_args=" --device /dev/kvm --group-add $(stat --format=%g /dev/kvm)"
fi

eval "docker run \
	--rm \
	-it \
	-v /tmp/.X11-unix:/tmp/.X11-unix \
	-e DISPLAY \
	-e USER \
	-v /dev:/dev \
	--privileged \
	--network host \
	--name ${container_name} \
	--hostname ${container_name} \
	--add-host ${container_name}:127.0.0.1 \
	-v ${SSH_AUTH_SOCK}:/ssh-agent -e SSH_AUTH_SOCK=/ssh-agent \
	--group-add $(stat --format=%g /var/run/docker.sock) \
	--group-add sudo \
	-v /var/run/docker.sock:/var/run/docker.sock \
	-v /dev:/dev \
	-e 'TERM=xterm-256color' \
	-e 'HISTFILE=${histfile}' \
	-e 'P_HOST=$(hostname)' \
	-v /etc/timezone:/etc/timezone:ro \
	-v /etc/localtime:/etc/localtime:ro \
	${docker_bash_args} \
	${docker_kvm_args} \
	${docker_user_args} \
	${docker_extra_args} \
	${docker_args} \
	${docker_tag} \
	${user_cmd}"

trap - EXIT
on_exit 'Done, success.'
