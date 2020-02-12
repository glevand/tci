#!/usr/bin/env bash

usage () {
	local old_xtrace
	old_xtrace="$(shopt -po xtrace || :)"
	set +o xtrace
	echo "${script_name} - Generate user keys for UEFI secure boot." >&2
	echo "Usage: ${script_name} [flags]" >&2
	echo "Option flags:" >&2
	echo "  -f --force               - Overwrite existing keys." >&2
	echo "  -h --help                - Show this help and exit." >&2
	echo "  -o --out-dir <directory> - Output directory. Default: '${out_dir}'." >&2
	echo "  -s --cert-subject <text> - Certificate subject. Default: '${cert_subject}'." >&2
	echo "  -v --verbose             - Verbose execution." >&2
	eval "${old_xtrace}"
}

process_opts() {
	local short_opts="fho:s:v"
	local long_opts="force,help,out-dir:,cert-subject:,verbose"

	local opts
	opts=$(getopt --options ${short_opts} --long ${long_opts} -n "${script_name}" -- "$@")

	eval set -- "${opts}"

	while true ; do
		#echo "${FUNCNAME[0]}: @${1}@ @${2}@"
		case "${1}" in
		-f | --force)
			force=1
			shift
			;;
		-h | --help)
			usage=1
			shift
			;;
		-o | --out-dir)
			out_dir="${2}"
			shift 2
			;;
		-s | --cert-subject)
			cert_subject="${2}"
			shift 2
			;;
		-v | --verbose)
			set -x
			verbose=1
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
}

on_exit() {
	local result=${1}

	set +x
	echo "${script_name}: Done: ${result}" >&2
}

print_cert_der() {
	local cert=${1}

	${openssl} x509 -in ${cert} -inform der -text -noout
}

print_cert_pem() {
	local cert=${1}

	${openssl} x509 -in ${cert} -text -noout
}

generate_user_keys() {
	local out_dir=${1}
	local cert_subject=${2}

	local uefi_certs="${out_dir}/uefi-certs"
	local log_file="${out_dir}/${script_name}.log"

	if [[ -d ${out_dir} ]]; then
		if [[ ! ${force} ]]; then
			echo "${script_name}: ERROR: Output directory '${out_dir}' exists.  Will not overwrite." >&2
			usage
			exit 1
		else
			bak_dir="${out_dir}-$(date +%Y.%m.%d-%H.%M.%S)"
			mv ${out_dir} ${bak_dir}
			echo "${script_name}: INFO: Old keys saved to '${bak_dir}'." >&2
		fi
	fi

	mkdir -p ${out_dir}

	${openssl} genrsa -out ${out_dir}/pk_key.pem 2048 >> ${log_file}
	${openssl} req -new -x509 -days 365 -sha256 -subj "${cert_subject}/CN=PK-KEY" -key ${out_dir}/pk_key.pem -out ${out_dir}/pk_cert.pem 2>&1 | tee --append ${log_file}
	${openssl} x509 -in ${out_dir}/pk_cert.pem -inform PEM -out ${out_dir}/pk_cert.der -outform DER 2>&1 | tee --append ${log_file}
	echo "PK:"| tee --append ${log_file}
	print_cert_der ${out_dir}/pk_cert.der | tee --append ${log_file}

	${openssl} genrsa -out ${out_dir}/kek_key.pem 2048 >> ${log_file}
	${openssl} req -new -x509 -days 365 -sha256 -subj "${cert_subject}/CN=KEK-KEY" -key ${out_dir}/kek_key.pem -out ${out_dir}/kek_cert.pem 2>&1 | tee --append ${log_file}
	${openssl} x509 -in ${out_dir}/kek_cert.pem -inform PEM -out ${out_dir}/kek_cert.der -outform DER 2>&1 | tee --append ${log_file}
	echo "KEK:"| tee --append ${log_file}
	print_cert_der ${out_dir}/kek_cert.der | tee --append ${log_file}

	${openssl} genrsa -out ${out_dir}/db_key.pem 2048 >> ${log_file}
	${openssl} req -new -x509 -days 365 -sha256 -subj "${cert_subject}/CN=DB-KEY" -key ${out_dir}/db_key.pem -out ${out_dir}/db_cert.pem 2>&1 | tee --append ${log_file}
	${openssl} x509 -in ${out_dir}/db_cert.pem -inform PEM -out ${out_dir}/db_cert.der -outform DER 2>&1 | tee --append ${log_file}
	echo "DB:"| tee --append ${log_file}
	print_cert_der ${out_dir}/db_cert.der | tee --append ${log_file}

	${openssl} genrsa -out ${out_dir}/mok_key.pem 2048 >> ${log_file}
	${openssl} req -new -x509 -days 365 -sha256 -subj "${cert_subject}/CN=MOK-KEY" -key ${out_dir}/mok_key.pem -out ${out_dir}/mok_cert.pem 2>&1 | tee --append ${log_file}
	${openssl} x509 -in ${out_dir}/mok_cert.pem -inform PEM -out ${out_dir}/mok_cert.der -outform DER 2>&1 | tee --append ${log_file}
	echo "MOK:"| tee --append ${log_file}
	print_cert_der ${out_dir}/mok_cert.der | tee --append ${log_file}

	mkdir -p ${uefi_certs}
	cp -av ${out_dir}/*.der ${uefi_certs}/

	echo "keys:"| tee --append ${log_file}
	find ${out_dir} -maxdepth 1 -type f -ls 2>&1 | tee --append ${log_file}

	echo "certs:"| tee --append ${log_file}
	find ${uefi_certs} -maxdepth 1 -type f -ls 2>&1 | tee --append ${log_file}
}

#===============================================================================
# program start
#===============================================================================
export PS4='\[\e[0;33m\]+ ${BASH_SOURCE##*/}:${LINENO}:(${FUNCNAME[0]:-"?"}):\[\e[0m\] '
set -e

script_name="${0##*/}"
trap "on_exit 'failed.'" EXIT

SCRIPTS_TOP=${SCRIPTS_TOP:-"$(cd "${BASH_SOURCE%/*}" && pwd)"}
source ${SCRIPTS_TOP}/lib/util.sh

process_opts "${@}"

out_dir=${out_dir:-"$(pwd)/user-keys"}
cert_subject=${cert_subject:-"/O=TDD Project/OU=TDD Project Secure Boot Keys"}

sbsign=${sbsign:-"sbsign"}
sbverify=${sbverify:-"sbverify"}
openssl=${openssl:-"openssl"}

if [[ ${usage} ]]; then
	usage
	trap - EXIT
	exit 0
fi

generate_user_keys "${out_dir}" "${cert_subject}"

trap "on_exit 'Success.'" EXIT
