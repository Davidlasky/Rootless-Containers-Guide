# Rootless-Containers-Guide
This repo is about installation of commonly used rootless containers and their usage. 

( ゜- ゜)つロ Cheers~

## Why Docker Rootless? 
Since one of the biggest security issues with Docker is that, its daemon runs as a root user. The main concern when running any program as the root user lies in potential vulnerabilities. If a vulnerability is found in the software run by root, the attacker has instant access to the entire system. Thankfully Docker introduced Docker rootless mode. The Rootless mode allows users to run the Docker daemon and containers as a non-root user. This mitigates the potential vulnerabilities in the daemon and the container runtime. As long as the prerequisites are met, rootless mode does not require root privileges even during the installation of the Docker daemon. 

Here is the guide of docker and docker rootless mode [docker rootless guide](https://github.com/Davidlasky/Rootless-Containers-Guide/blob/main/Docker%20Rootless%20Guide.md)

## What about Podman?
Personally I'd recommend Podman over Docker and Docker Rootless. Podman follows the OCI standard and has been designed since its inception to be a close replacement to Docker. It runs rootlessly by design. though the only confusing piece of this is that a Podman container running as a non-root user will run within the user namespace. Also, one of the primary "selling" points of Podman is the fact that it runs "daemonless". To the average user this likely means very little, but from a security standpoint it means a LOT.  

However, updates of Podman is falling far behind on Ubuntu. Only Ubuntu 20.10 and above have it included in the apt packages, and it's version 3.4.4, while the latest is 4.5.X. Most companies still use Ubuntu 18.04 and 20.04 for production, and downloading Podman 3.4.2 from Kubic repo is NOT recommended for PRODUCTION use. 

Manual compilation of latest Podman is doable and fully functioning on Ubuntu 20.04, but HIGHLY NOT recommended! It took me three days to deal with weird compilation errors, installation of various dependencies,and package conflicts :(  

## Entrypoint
The entrypoint.sh file is made specifically for rootless containers such as podman and docker rootless mode, where the default user in the container is root with id 0. In production environment, we need to mount files and directories into the container, which by default are all owned by root:root(USER:GROUP). We need to change the USER to the real user name to have correct access to the moutned files and directories,  pretending we are the user, yet we are STILL ROOT.

It's worth noting that even though our user name is changed to the real user name on the host machine, from the container's perspective of view, we're still root with UID and GID 0. This id issue may cause some troubles. Watch out for apps and verifications that read user id UID. If such problem occurs, modify the entrypoint file as intended.

### Usage
Add '--entrypoint' option after docker run or podman run command, add '-v' option to mount directories into the container, add '-w' to specify workspace directory inside the container. e.g.
```
docker run --rm -it --entrypoint PATH-TO-THE-FILE -e USER -v /home/david/.ssh:/home/david/.ssh -v /home/david/test:/home/david/test -w /home/david/test myimage bash
```
