#!/usr/bin/env bash

usage () {
	local old_xtrace
	old_xtrace="$(shopt -po xtrace || :)"
	set +o xtrace
	echo "${script_name} - Enter a running yocto-builder container." >&2
	echo "Usage: ${script_name} [flags] -- [command] [args]" >&2
	echo "Option flags:" >&2
	echo "  -h --help           - Show this help and exit." >&2
	echo "  -v --verbose        - Verbose execution." >&2
	echo "  -n --container-name - Container name. Default: '${container_name}'." >&2
	echo "  -p --as-privileged  - Run command as privileged." >&2
	echo "Args:" >&2
	echo "  command             - Default: '${user_cmd}'" >&2
	eval "${old_xtrace}"
}

process_opts() {
	local short_opts="hvn:p"
	local long_opts="help,verbose,container-name:,as-privileged"

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
		-n | --container-name)
			container_name="${2}"
			shift 2
			;;
		-p | --as-privileged)
			as_privileged=1
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

SCRIPTS_TOP=${SCRIPTS_TOP:-"$(cd "${BASH_SOURCE%/*}" && pwd )"}

if [ "${TDD_YOCTO_BUILDER}" ]; then
	echo "${script_name}: ERROR: Already in yocto-builder." >&2
	exit 1
fi

trap "on_exit 'Done, failed.'" EXIT
set -e

process_opts "${@}"

container_name=${container_name:-"yocto-builder"}
user_cmd=${user_cmd:-"/bin/bash"}

unset docker_extra_args

if [[ ${usage} ]]; then
	usage
	trap - EXIT
	exit 0
fi

if [[ ${as_privileged} ]]; then
	docker_extra_args=" --privileged"
fi

eval "docker exec -it ${docker_extra_args} ${container_name} ${user_cmd}"

trap - EXIT
on_exit 'Done, success.'
