# Podman Guide
## For Admin:
### Podman Installation
#### Environment: Ubuntu 18.04 or 20.04 LTS
```bash
source /etc/os-release
echo "deb https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_${VERSION_ID}/ /" | sudo tee /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list
curl -L https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_${VERSION_ID}/Release.key | sudo apt-key add -
sudo apt-get update
sudo apt-get -y upgrade
sudo apt-get -y install podman
podman -v
```

#### Environment: OSD 7
```bash
source /etc/os-release
echo "deb https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/unstable/xUbuntu_${VERSION_ID}/ /" | sudo tee /etc/apt/sources.list.d/devel:kubic:libcontainers:unstable.list
curl -L https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/unstable/xUbuntu_${VERSION_ID}/Release.key | sudo apt-key add -
sudo apt-get update
sudo apt-get -y upgrade
sudo apt-get -y install podman
podman -v
```

### Setup correct user namespace subuid and subgid mapping
```bash
sudo usermod --add-subuids $(($(id -u) + 1))-$((2*$(id -u) + 1)) "$(id -un)"
sudo usermod --add-subgids $(($(id -g) + 1))-$((2*$(id -g) + 1)) "$(id -un)"

# make sure we don't have missconfigured system
sudo chown $(id -u):$(id -g) /run/user/$(id -u)/containers

#apply the change
podman system migrate

# check UID/GID mapping inside containers
podman unshare cat /proc/self/uid_map
podman unshare cat /proc/self/gid_map
```

### Edit storage.conf to bypass "chown:permission denied" errors
```bash
vim /etc/containers/storage.conf

#uncomment line 70 and change false to true
ignore_chown_errors = "true"

#write and quit
:wq

#apply the change
podman system migrate
```
