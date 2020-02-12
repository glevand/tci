# The TDD project

A framework for test driven Linux software development.

## TDD tftpd Service

### Install Service

To build, install and start the TDD tftpd service use the
[build-tftpd.sh](docker/tftpd/build-tftpd.sh) script:

```sh
sudo mkdir -p /var/tftproot
docker/tftpd/build-tftpd.sh --purge --install --enable --start
```

Once the [build-tftpd.sh](docker/tftpd/build-tftpd.sh) script has
completed the status of the tdd-tftpd.service can be checked with commands
like these:

```sh
docker ps
sudo systemctl status tdd-tftpd.service
```

Files are served from the `/var/tftproot/` directory.

### Check service status:

```sh
docker ps
sudo systemctl status tdd-tftpd.service
```

### Stop service:

```sh
sudo systemctl stop tdd-tftpd.service
```

### Run shell in tftpd container:

```sh
docker exec -it tdd-tftpd.service bash
```

### Completely remove service from system:

```sh
sudo systemctl stop tdd-tftpd.service
sudo systemctl disable tdd-tftpd.service
sudo rm /etc/systemd/system/tdd-tftpd.service
docker rm -f tdd-tftpd.service
docker rmi -f tdd-tftpd:1 alpine:latest
sudo rm -rf /var/tftproot
```

