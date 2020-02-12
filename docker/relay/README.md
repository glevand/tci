# The TDD project

A framework for test driven Linux software development.

## TDD tdd-relay Service

### Install Service

To build, install and start the tdd-relay service use the
[build-relay.sh](docker/relay/build-relay.sh) script:

```sh
docker/relay/build-relay.sh --purge --install --enable --start
```

Once the [build-relay.sh](docker/relay/build-relay.sh) script has
completed the tdd-relay service can be managed with commands
like these:

### Check service status:

```sh
docker ps
sudo systemctl status tdd-relay.service
```

### Stop service:

```sh
sudo systemctl stop tdd-relay.service
```

### Run shell in tdd-relay container:

```sh
docker exec -it tdd-relay.service bash
```

### Rebuild tdd-relay container:

```sh
sudo systemctl stop tdd-relay
docker/relay/build-relay.sh -p
sudo systemctl start tdd-relay
```

### Completely remove service from system:

```sh
sudo systemctl stop tdd-relay.service
sudo systemctl disable tdd-relay.service
sudo rm /etc/systemd/system/tdd-relay.service
docker rm -f tdd-relay.service
docker rmi -f tdd-relay:1 alpine:latest
```
