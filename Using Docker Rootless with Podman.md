# This wiki is a special use case for using docker rootless with non-root user.
## Installation of Docker and Docker Rootless: [Guide](https://github.com/Davidlasky/Rootless-Containers-Guide/blob/main/Docker%20Rootless%20Guide.md)

## Why and how Docker Rootless + Podman?

### Why should we use them both instead of either one?

It is true that simply using Podman alone is feasible. However, updates of Podman is falling far behind on Ubuntu. Only Ubuntu 20.10 and above have it included in the apt packages, and it's version 3.4.4, while the latest is 4.5.X. Most projects are still using Ubuntu 18.04 and 20.04 for production, and downloading Podman 3.4.2 from Kubic repo is NOT recommended for production use. 

Docker rootless, on the other hand, is actively maintained and the latest version can run on any machines, which includes security patches, bug fixes, and latest features. For rootless containers such as podman and docker rootless,the default user in the container is root with id 0. In production environment, we need to mount files and directories into the container, which by default are all owned by root:root(UID:GID). We need to change the USER and GROUP to the real user name(basically change UID/GID from 0 to real user's IDs) to in special use cases. But docker rootless can't change file ownership of mounted files and directories since it does not have root permission, so this is where Podman unshare chown kicks in.

### How Podman unshare chown work?

Podman unshare launches a process (by default, $SHELL) in a new user namespace. The user namespace is configured so that the invoking user’s UID and primary GID appear to be UID 0 and GID 0, respectively. Any ranges which match that user and group in /etc/subuid and /etc/subgid are also mapped in as themselves with the help of the newuidmap and newgidmap helpers.

Suppose my UID is 23333. Let's see how the rootless containers would “see” the filesystem using podman unshare:
```bash
jnd1sgh@SGH-C-001EV:~/test$ podman unshare ls -la .
total 20
drwxrwxr-x  5 root root    4096 Aug  7 11:20 .
drwx------ 23 root nogroup 4096 Aug  3 14:12 ..
drwxrwxr-x 15 root root    4096 Jul 20 15:51 test0
drwxr-xr-x  2 root root    4096 Jul 31 10:14 test1
drwxr-xr-x  2 root root    4096 Aug  3 14:08 test2
```
When my container starts, it will want to write to that directory. And since the user in the container is user 23333 and not root, it will fail.
To change the UID/GID of the volume directory in the rootless Podman user namespace, run podman unshare chown:

```bash
podman unshare chown -R 23333:23333 .
# Users may replace "." with absolute path to the directory.
```
To change the ownership back after compilations, run 
```bash
podman unshare chown -R 0:0 .
```

### How to apply it into production?
All the files and directories that will be mounted into the container is passed as DOCKER_ARGS when running build_all_plusqnx_docker.sh, and we have to change their ownership before running build_all_plusqnx.sh. To be more specific, we can write a for loop to iterate through DOCKER_ARGS, strip strings that contains ":" and only keep the first part so that we don't have to chown the same file or dirs twice.

An example snippet is shown below. 
```bash
#save directories and files to be changed into an array, and change them back after the docker run
to_change=()

for i in "${!DOCKER_ARGS[@]}"; do
    if [[ ${DOCKER_ARGS[i]} == "-v" ]]; then
      string=${DOCKER_ARGS[i+1]}
      array=(${string//:/ })
      to_change+=(${array[0]})
    fi
done

for i in "${!to_change[@]}"; do
  podman unshare chown -R $(id -u):$(id -g) ${to_change[i]}
done

#make sure we don't change ownership of repair.sh
podman unshare chown root:root repair.sh

#for podman, add -v /tmp:/tmp to the docker args if podman can't create temporary files
#"${BUILT_IN_QUALITY_DIR}"/docker/run_docker.sh -v /tmp:/tmp "${DOCKER_ARGS[@]}"  "${IMAGE}" ${CMD} ${CMD_ARGS[*]}

#for docker, just use the original one. Podman should also work in most cases.
"${BUILT_IN_QUALITY_DIR}"/docker/run_docker.sh "${DOCKER_ARGS[@]}"  "${IMAGE}" ${CMD} ${CMD_ARGS[*]}

#change back the ownership of the files and directories
for i in "${!to_change[@]}"; do
  podman unshare chown -R root:root ${to_change[i]}
done
```
The repair.sh is a backup restoration script in case errors occurred during compilation, and the last part which changes back the ownership of the files and directories won't be run. It's simplified from the code snippet above. 

```bash
#!/usr/bin/env bash
set -eux
 
SCRIPT_DIR=""
# Fill in accordingly
 
if [ -f ${HOME}/.gitconfig_gerrit_urls_fe ]; then #if the file exists
  #unshare chown again in case the user forgot to run repair.sh first
  podman unshare chown -R root:root ${HOME}/.gitconfig_gerrit_urls_fe
fi
 
source "${SCRIPT_DIR}"/docker_args.sh
 
# Mount ${HOME}/.artifactory for developers scenario
if [ -f ${HOME}/.artifactory ]; then
  DOCKER_ARGS+=(
    -v ${HOME}/.artifactory:${HOME}/.artifactory
  )
fi
 
to_change=()
 
for i in "${!DOCKER_ARGS[@]}"; do
    if [[ ${DOCKER_ARGS[i]} == "-v" ]]; then
      string=${DOCKER_ARGS[i+1]}
      array=(${string//:/ })
      to_change+=(${array[0]})
    fi
done
 
for i in "${!to_change[@]}"; do
  podman unshare chown -R root:root ${to_change[i]}
done
```

## Entrypoint for non-root user 
