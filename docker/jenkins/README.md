# The TDD project

A framework for test driven Linux software development.

## TDD Jenkins Service

### Host System Jenkins User

Although not required, to ease system setup and maintenece it is recommended to
add a host system Jenkins user with the same user and group names and id values
as those of the Jenkins user in the Jenkins container.  The
[useradd-jenkins.sh](scripts/useradd-jenkins.sh) script can be used to do this.

If a host system Jenkins user other than the default is used the `JENKINS_USER`
environment variable must be set when calling the
[build-jenkins.sh](docker/jenkins/build-jenkins.sh) or
[docker-build-all.sh](docker/docker-build-all.sh) scripts.


### Install Service

To build, install and start the TDD Jenkins service use the
[build-jenkins.sh](docker/jenkins/build-jenkins.sh) script:

```sh
docker/jenkins/build-jenkins.sh --purge --install --enable --start
```

Once the [build-jenkins.sh](docker/jenkins/build-jenkins.sh) script has
completed the status of the tdd-jenkins.service can be checked with commands
like these:

```sh
docker ps
sudo systemctl status tdd-jenkins.service
```

With the tdd-jenkins container running the Jenkins UI will be served via
http on port 8080.  The `JENKINS_URL` will be port 8080 of the installed
server:

    JENKINS_URL=http://${server_addr}:8080

To complete the installation, using a web browser navigate to the `${JENKINS_URL}`.
A series of 'Getting' Started dialogs will need to be completed.  The
`Unlock Jenkins` dialog should be displayed first.  On startup Jenkins will have
output the required `Administrator password` to the systemd journal.  Use
commands like these to retrieve it:

```sh
sudo journalctl -u tdd-jenkins.service --boot --pager-end

 docker[30930]: Please use the following password to proceed to installation:
 docker[30930]: 2491sfe2668404795fk8d4f40db6w24f
```

The `Customize Jenkins` dialog should be displayed next.  Choose
`Install suggested plugins`.

Once the 'Getting Started' dialogs are complete the
`Please create new jobs to get started` message is presented.  To create the
TDD jobs navigate to the `${JENKINS_URL}/script` page. Copy and paste
the contents of the
[jenkins/job-setup/job-setup.groovy](jenkins/job-setup/job-setup.groovy)
file into the 'Script Console' dialog box and press the 'RUN' button.

Once run, the 'Result' should be `Jenkins jobs were successfully created`.

The TDD jobs will be at `${JENKINS_URL}/blue/pipelines` or
`${JENKINS_URL}/job/tdd/`.


#### TFTP Server Setup

* Use [ssh-keygen](https://www.openssh.com/manual.html) to create a login key
pair for the tftp server.

* Create a tftp upload user account on the tftp server.

* Install the public key of the tftp server login key pair to the authorized_keys
file of the tftp upload user on the tftp server using
[ssh-copy-id](https://www.openssh.com/manual.html), etc.

* Install the private key of the tftp server login key pair to the Jenkins
Credentials Configuration
${JENKINS_URL}/credentials/store/system/domain/_/newCredentials. Choose
`SSH Username with private key`. Set the credential `ID` to
`tftp-server-login-key`.  This is the ID value is expected by the job files and
must be set correctly in the Jenkins Credentials Configuration.

For more info see 
[Adding new global credentials](https://jenkins.io/doc/book/using/using-credentials/#adding-new-global-credentials)
in the Jenkins Documentation.

##### Create TFTP server Environment Variables

* Navigate to ${JENKINS_URL}/configure.
* Under `Global properties` select `Environment variables`.
* Add variables named `TDD_RELAY_SERVER` and `TDD_TFTP_SERVER` with values
that corespond to the DNS names or IP addresses of the servers for your site.

### Check service status:

```sh
docker ps
sudo systemctl status tdd-jenkins.service
```

### Stop service:

```sh
sudo systemctl stop tdd-jenkins.service
```

### Run shell in Jenkins container:

```sh
docker exec -it tdd-jenkins.service bash
```

### Completely remove service from system:

```sh
sudo systemctl stop tdd-jenkins.service
sudo systemctl disable tdd-jenkins.service
sudo rm /etc/systemd/system/tdd-jenkins.service
docker rm -f tdd-jenkins.service
docker rmi -f tdd-jenkins:1 openjdk:8-jdk
docker volume rm -f jenkins_home

```
