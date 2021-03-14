#!/usr/bin/env bash

usage() {
	local old_xtrace
	old_xtrace="$(shopt -po xtrace || :)"
	set +o xtrace
	echo "${script_name} (tdd) - Create an EFI Linux bootloader program from a systemd EFI bootloader stub." >&2
	echo "Usage: ${script_name} [flags]" >&2
	echo "Option flags:" >&2
	echo "  -s --efi-stub    - EFI bootloader stub. Default: '${efi_stub}'." >&2
	echo "  -l --linux       - Linux kernel file. Default: '${linux}'." >&2
	echo "  -c --cmdline     - Optional Linux kernel cmdline. Default: '${cmdline}'." >&2
	echo "  -i --initrd      - Optional Linux initrd file. Default: '${initrd}'." >&2
	echo "  -p --splash      - Optional splash screen bitmap file. Default: '${splash}'." >&2
	echo "  -f --config      - Optional configuration file. Default: '${config_file}'." >&2
	echo "  -o --output-file - EFI bootloader output file. Default: '${out_file}'." >&2
	echo "  -h --help        - Show this help and exit." >&2
	echo "  -v --verbose     - Verbose execution." >&2
	echo "  -g --debug       - Extra verbose execution." >&2
	echo "Send bug reports to: Geoff Levand <geoff@infradead.org>." >&2
	eval "${old_xtrace}"
}

process_opts() {
	local short_opts="s:l:c:i:p:f:o:hvg"
	local long_opts="efi-stub:,linux:,cmdline:,initrd:,splash:,config:,output-file:,help,verbose,debug"

	local opts
	opts=$(getopt --options ${short_opts} --long ${long_opts} -n "${script_name}" -- "$@")

	eval set -- "${opts}"

	while true ; do
		#echo "${FUNCNAME[0]}: @${1}@ @${2}@"
		case "${1}" in
		-s | --efi-stub)
			efi_stub="${2}"
			shift 2
			;;
		-l | --linux)
			linux="${2}"
			shift 2
			;;
		-c | --cmdline)
			cmdline="${2}"
			shift 2
			;;
		-i | --initrd)
			initrd="${2}"
			shift 2
			;;
		-p | --splash)
			splash="${2}"
			shift 2
			;;
		-f | --config)
			config_file="${2}"
			shift 2
			;;
		-o | --output-file)
			out_file="${2}"
			shift 2
			;;
		-h | --help)
			usage=1
			shift
			;;
		-v | --verbose)
			verbose=1
			shift
			;;
		-g | --debug)
			set -x
			verbose=1
			debug=1
			shift
			;;
		--)
			shift
			if [[ ${*} ]]; then
				set +o xtrace
				echo "${script_name}: ERROR: Got extra args: '${*}'" >&2
				usage
				exit 1
			fi
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

	if [[ -d ${tmp_dir} ]]; then
		rm -rf ${tmp_dir}
	fi

	set +x
	echo "${script_name}: Done: ${result}." >&2
}

#===============================================================================
export PS4='\[\e[0;33m\]+ ${BASH_SOURCE##*/}:${LINENO}:(${FUNCNAME[0]:-"?"}):\[\e[0m\] '
script_name="${0##*/}"
SCRIPTS_TOP=${SCRIPTS_TOP:-"$(cd "${BASH_SOURCE%/*}/.." && pwd)"}

start_time="$(date +%Y.%m.%d-%H.%M.%S)"
SECONDS=0

trap "on_exit" EXIT
set -o pipefail
set -e

source "${SCRIPTS_TOP}/lib/util.sh"

process_opts "${@}"

if [[ ${config_file} ]]; then
	if [[ ! -f "${config_file}" ]]; then
		echo "${script_name}: ERROR: File config not found: '${config_file}'" >&2
		usage
		exit 1
	fi
	config_file="$(realpath "${config_file}")"
	source "${config_file}"
fi

cmdline_start="${cmdline_start:-0x30000}"
splash_start="${splash_start:-0x40000}"
linux_start="${linux_start:-0x50000}"
initrd_start="${initrd_start:-0x3000000}"

objcopy="${objcopy:-objcopy}"
objdump="${objdump:-objdump}"

cmdline="${cmdline:-console=ttyS0,115200 console=tty0}"
out_file="${out_file:-/tmp/${script_name%.sh}-${start_time}.efi}"

if [[ ${usage} ]]; then
	usage
	trap - EXIT
	exit 0
fi

check_progs "${objcopy}"
check_progs "${objdump}"

tmp_dir="$(mktemp --tmpdir --directory ${script_name}.XXXX)"

out_dir="${out_file%/*}"
mkdir -p "${out_dir}"
out_dir="$(realpath "${out_dir}")"

out_file="${out_dir}/${out_file##*/}"
rm -f "${out_file}"

cmdline_file="${tmp_dir}/cmdline"
echo "${cmdline}" > "${cmdline_file}"

check_opt 'linux' ${linux}
check_file "${linux}"

check_opt 'efi-stub' ${efi_stub}
check_file "${efi_stub}"

if [[ ${initrd} ]]; then
	check_file "${initrd}"
fi

objcopy_args=""

objcopy_args+=" --add-section .cmdline='${cmdline_file}'"
objcopy_args+=" --change-section-vma .cmdline='${cmdline_start}'"

objcopy_args+=" --add-section .linux='${linux}'"
objcopy_args+=" --change-section-vma .linux='${linux_start}'"

if [[ ${splash} ]]; then
	check_file "${splash}"
	objcopy_args+=" --add-section .splash='${splash}'"
	objcopy_args+=" --change-section-vma .splash='${splash_start}'"
fi

if [[ ${initrd} ]]; then
	check_file "${initrd}"
	objcopy_args+=" --add-section .initrd='${initrd}'"
	objcopy_args+=" --change-section-vma .initrd='${initrd_start}'"
fi

echo "${script_name}: INFO: Preparing '${out_file}'" >&2

eval "${objcopy} ${objcopy_args} ${efi_stub} ${out_file}"

"${objdump}" -h "${out_file}"

echo '' >&2
echo "${script_name}: INFO: Output in '${out_file}'" >&2

trap "on_exit 'Success'" EXIT
exit 0
