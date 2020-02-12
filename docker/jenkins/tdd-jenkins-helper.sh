#!/bin/bash

set -ex

script_name="${0##*/}"

if [ ! -f /.dockerenv ]; then
	echo "${script_name}: ERROR: Startup helper for tdd-jenkins container." >&2
	exit 1
fi

stamp='/.jenkins-configured'

if [[ ! -f ${stamp} ]]; then
	sudo touch ${stamp}

	# The jenkins user must be a member of the host-docker group to
	# access the docker daemon via /var/run/docker.sock.
	host_gid=$(stat --format=%g /var/run/docker.sock)

	for g in $(id --groups ${JENKINS_USER}); do
		if [[ "${g}" == "${host_gid}" ]]; then
			found=1
			break;
		fi
	done

	if [[ ! ${found} ]]; then
		sudo groupadd --gid ${host_gid} host-docker
		sudo usermod -a -G host-docker ${JENKINS_USER}

		# Continue with the updated jenkins permissions.
		sudo chmod u+s /usr/sbin/gosu
		exec /usr/sbin/gosu ${JENKINS_USER} ${0}
	fi
fi

sudo chmod u-s /usr/sbin/gosu
exec /usr/local/bin/jenkins.sh
