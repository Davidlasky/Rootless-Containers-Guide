# For Root:
## Environment: Ubuntu 18.04, 20.04, 22.04 LTS
## Install Docker: 
```bash
#Uninstall all conflicting packages
for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do sudo apt-get remove $pkg; done

#Update the apt package index and install packages to allow apt to use a repository over HTTPS, then add Docker’s official GPG key and set up the repository
sudo apt-get update
sudo apt-get install ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

#Begin to install
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
 ```

# For Users:
## Install Docker Rootless Mode:
```bash
export FORCE_ROOTLESS_INSTALL=1
curl -fsSL https://get.docker.com/rootless | sh

#Not recommended, won't be able to address problem 2 below without sudo access
(dockerd-rootless-setuptool.sh install --force)
```
### For Corp APT mirror maintainers who are having concerns about docker rootless mode package dependencies, pls refer to my repo [DinD](https://github.com/Davidlasky/docker-rootless-inside-docker) which tests the least amount of extra dependency packages needed to install and run docker rootless.

## Control docker.service:
```bash
systemctl --user (start|stop|restart|status) docker.service
```
For more info pls refer to the official doc: [Docker rootless](https://docs.docker.com/engine/security/rootless/)

# Troubleshooting for Docker rootless mode
## Problem 1 

Docker can't establish a connection under "rootless" context, but works fine under default(root) context.
(Optional for admin, seems like a security improvement to me indeed)
```bash
docker: Error response from daemon: Get "https://registry-1.docker.io/v2/": proxyconnect tcp: dial tcp 127.0.0.1:3128: connect: connection refused. 
```
### Environment: proxy is cntlm on localhost (so, proxy_ip is localhost, and proxy_port is 3128), docker context is set to rootless.
```bash
##Manually setup docker proxy for rootless, and then modify the daemon file
mkdir ~/.config/systemd/user/docker.service.d
cd ~/.config/systemd/user/docker.service.d
vim http-proxy.conf

##i for INPUT, use 10.0.2.2 for slirp4netns(default) , 192.168.65.2 for VPNKit
[Service]
Environment="http_proxy=http://10.0.2.2:3128"
Environment="https_proxy=http://10.0.2.2:3128"

##write and exit 
:wq

##then modify daemon file
cd
vim ~/bin/dockerd-rootless.sh

##delete the flag in line 106(DELETE it, don't COMMENT it out)
--disable-host-loopback

##write and exit
:wq

##reload the daemon and then restart docker rootless
systemctl --user daemon-reload
systemctl --user restart docker

##check docker's status
systemctl --user status docker
```

## Problem 2

Using wrong context while trying to run docker
```bash
docker: permission denied while trying to connect to the Docker daemon socket at unix:///var/run/docker.sock: Post "http://%2Fvar%2Frun%2Fdocker.sock/v1.24/containers/create": dial unix /var/run/docker.sock: connect: permission denied.
See 'docker run --help'.
```
### Solution: 
For admins: change file permission of "/var/run/docker.sock" with the last line in the installation guide above
```bash
## list all docker contexts
docker context ls

##To reset DOCKER ENDPOINT to default
unset DOCKER_HOST

##To use default DOCKER ENDPOINT(unix:///var/run/docker.sock)
docker context use default
```

For users: change docker context to rootless, where DOCKER ENDPOINT should look like unix://run/user/$UID/docker.sock
```bash
## list all docker contexts
docker context ls

##To reset DOCKER ENDPOINT to default
unset DOCKER_HOST

## If the user don't have rootful docker permission, change the docker context to rootless
docker context use rootless
```

## Problem 3
Docker build may include codes that download files from public Internet, with connections on privileged ports like 80 and 443.

### Solution: 
To expose privileged ports (< 1024), set CAP_NET_BIND_SERVICE on rootlesskit binary and restart the daemon.
```bash
sudo setcap cap_net_bind_service=ep $(which rootlesskit) 
systemctl --user restart docker
```
# Remarks:
1. The socket path is set to $XDG_RUNTIME_DIR/docker.sock by default. $XDG_RUNTIME_DIR is typically set to /run/user/$UID. 

2. If DOCKER_HOST is set, it will overwrite default context! 

3. The data dir is set to ~/.local/share/docker by default. The data dir should not be on NFS. 

4. The daemon config dir is set to ~/.config/docker by default. This directory is different from ~/.docker that is used by the client. 
