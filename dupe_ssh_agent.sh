#!/usr/bin/bash
export SSH_AUTH_SOCK_DOCKER=${HOME}/.ssh/.ssh_auth_sock

if [ -e "${SSH_AUTH_SOCK_DOCKER}" ]; then  # kill old socat & replace with new one
    pkill -F "${SSH_AUTH_SOCK_DOCKER}_pid" socat
fi

socat UNIX-LISTEN:${SSH_AUTH_SOCK_DOCKER},fork UNIX-CLIENT:${SSH_AUTH_SOCK} &
echo $! > ${SSH_AUTH_SOCK_DOCKER}_pid