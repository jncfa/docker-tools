#!/usr/bin/bash
set -e
export SSH_AUTH_SOCK_SL=${HOME}/.ssh/.ssh_auth_sock
socat -L ${SSH_AUTH_SOCK_SL}_lf UNIX-LISTEN:${SSH_AUTH_SOCK_SL},fork UNIX-CLIENT:${SSH_AUTH_SOCK} &