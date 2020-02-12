#!/usr/bin/env bash

set -e

script_name="${0##*/}"

DOCKER_TOP=${DOCKER_TOP:-"$( cd "${BASH_SOURCE%/*}" && pwd )"}

if [[ -n "${JENKINS_URL}" ]]; then
	export PS4='+ ${BASH_SOURCE##*/}:${LINENO}:(${FUNCNAME[0]:-"?"}):'
else
	export PS4='\[\e[0;33m\]+ ${BASH_SOURCE##*/}:${LINENO}:(${FUNCNAME[0]:-"?"}):\[\e[0m\] '
fi

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

usage() {
	local old_xtrace="$(shopt -po xtrace || :)"
	set +o xtrace
	echo "${script_name} - Builds all TDD container images." >&2
	echo "Usage: ${script_name} [flags]" >&2
	echo "Option flags:" >&2
	echo "  -h --help     - Show this help and exit." >&2
	echo "  -i --info     - Show project help." >&2
	echo "  -p --purge    - Remove existing docker image and rebuild." >&2
	echo "  -r --rebuild  - Rebuild existing docker image." >&2
	echo "  --install     - Install systemd service files." >&2
	echo "  --start       - Start systemd services." >&2
	echo "  --enable      - Enable systemd services." >&2

	eval "${old_xtrace}"
}

short_opts="hipr"
long_opts="help,info,purge,rebuild,install,start,enable"

opts=$(getopt --options ${short_opts} --long ${long_opts} -n "${script_name}" -- "$@")

if [ $? != 0 ]; then
	echo "${script_name}: ERROR: Internal getopt" >&2
	exit 1
fi

eval set -- "${opts}"

while true ; do
	case "${1}" in
	-h | --help)
		usage=1
		shift
		;;
	-i | --info)
		info=1
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
	--install)
		install=1
		shift
		;;
	--start)
		start=1
		shift
		;;
	--enable)
		enable=1
		shift
		;;
	--)
		shift
		break
		;;
	*)
		echo "${script_name}: ERROR: Internal opts: '${@}'" >&2
		exit 1
		;;
	esac
done

if [[ -n "${usage}" ]]; then
	usage
	exit 0
fi

host_arch=$(get_arch "$(uname -m)")

case ${host_arch} in
amd64|arm64)
	projects='
		builder
		builder-centos
		relay
		jenkins
		tftpd
	'
	;;
*)
	echo "${script_name}: ERROR: Unknown host: '${host_arch}'" >&2
	exit 1
	;;
esac

extra_args=''

if [[ ${info} ]]; then
	extra_args+='--help '
else
	set -x
	extra_args+='--verbose '
fi

if [[ ${purge} ]]; then
	extra_args+='--purge '
elif [[ ${rebuild} ]]; then
	extra_args+='--rebuild '
fi

if [[ ${install} ]]; then
	extra_args+='--install '
fi
if [[ ${start} ]]; then
	extra_args+='--start '
fi
if [[ ${enable} ]]; then
	extra_args+='--enable '
fi


for p in ${projects}; do
	"${DOCKER_TOP}/${p}/build-${p}.sh" ${extra_args}
	echo '===================================' >&2
done

echo "${script_name}: Done, success." >&2

