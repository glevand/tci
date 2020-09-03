# Image for compiling linux kernel, creating test rootfs, running QEMU.

ARG DOCKER_FROM

FROM ${DOCKER_FROM}

ENV LANG C.UTF-8
ENV LC_ALL C.UTF-8

ENV TDD_BUILDER 1
ENV TDD_DEBIAN_BUILDER 1

RUN echo 'deb-src http://deb.debian.org/debian buster main' >> /etc/apt/sources.list \
	&& apt-get update \
	&& apt-get -y upgrade \
	&& DEBIAN_FRONTEND=noninteractive apt-get -y install \
		apt-utils \
		bash \
		bash-completion \
		binfmt-support \
		bison \
		ccache \
		curl \
		debootstrap \
		dnsutils \
		docker.io \
		dosfstools \
		flex \
		gcc-x86-64-linux-gnu \
		git \
		grub-common \
		inotify-tools \
		ipmitool \
		isc-dhcp-server \
		libdnet-dev \
		libncurses5-dev \
		libpcap-dev \
		libssl-dev \
		netcat-openbsd \
		net-tools \
		ovmf \
		procps \
		qemu-system-x86-64 \
		qemu-user-static \
		qemu-utils \
		rpm2cpio \
		rsync \
		sbsigntool \
		sudo \
		tcpdump \
		tftp-hpa \
		vim \
		wget \
		zypper \
	&& apt-get -y build-dep linux \
	&& DEBIAN_FRONTEND=noninteractive apt-get -y install \
		g++-aarch64-linux-gnu \
		gcc-aarch64-linux-gnu \
		qemu-efi-aarch64 \
		qemu-system-arm \
	&& if [ "$(uname -m)" != "aarch64" ]; then \
		DEBIAN_FRONTEND=noninteractive apt-get -y install \
		gcc-powerpc-linux-gnu \
		qemu-system-ppc \
		openbios-ppc; fi \
	&& DEBIAN_FRONTEND=noninteractive apt-get -y autoremove \
	&& rm -rf /var/lib/apt/lists/* \
	&& mv /usr/sbin/tcpdump /usr/bin/tcpdump

CMD /bin/bash
