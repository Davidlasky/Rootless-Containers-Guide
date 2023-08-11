#!/bin/bash -u

# taken from:
# https://github.com/BrainTwister/docker-devel-env/blob/aefb1681ea1825ff77bae6fd7c3f38034419e50d/ubuntu/entrypoint.sh

if [[ ${VERBOSE:-} == true ]]; then
    set -x
fi

if [[ "${USER_ID:-}" != "0" ]]; then
  # Add local user
  USER_ID=${USER_ID:-9001}
  GROUP_ID=${GROUP_ID:-${USER_ID}}
  USER_NAME=${USER_NAME:-user}
  GROUP_NAME="${GROUP_NAME:-${USER_NAME}}"

  groupadd -g "$GROUP_ID" "$GROUP_NAME"
  # option --no-log-init is very important, otherwise you end up with "no space left on device, see
  # docker build hangs/crashes when useradd with large UID
  # see https://github.com/moby/moby/issues/5419
  useradd --no-log-init -s /bin/bash -g "$GROUP_ID" -u "$USER_ID" -o -c "container user" -m "$USER_NAME"
  # copy bash skeleton files like .bashrc, but don't overwrite
  cp -an /etc/skel/. /home/"$USER_NAME"/
  # do not change ownership of files as we may change mounted host files
  chown "$USER_NAME":"$GROUP_NAME" /home/"$USER_NAME"

  export HOME=/home/"$USER_NAME"
  export USER="$USER_NAME"

  cd "$HOME" >/dev/null || exit
  # Execute entrypoint modules as user
  if [[ -d "/entrypoint.d" && "${ENTRYPOINTS_DISABLED:-}" != true ]]; then
    for f in /entrypoint.d/*.sh; do
      chroot --userspec="$USER_NAME" --skip-chdir / bash -c "source \"$f\"" || exit
    done
  fi
  cd - >/dev/null || exit

  # Execute cmd as user
  chroot --userspec="$USER_NAME" --skip-chdir / "$@"
else
  # Execute cmd as root
  "$@"
fi
