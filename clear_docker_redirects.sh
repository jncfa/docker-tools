# kill lingering socat connections and clear redirect folder
echo "Clearning any lingering Docker socat redirections..."
for CONTAINER_FOLDER in ${HOME}/.docker-redirect/* ; do
    if [ -d "${CONTAINER_FOLDER}" ]; then
        # Kill X11 Redirect
        if [ -e "${CONTAINER_FOLDER}/socket/X0" ]; then  # kill socat
            pkill -F "${CONTAINER_FOLDER}/.x11_socat_pid" socat
            rm "${CONTAINER_FOLDER}/.x11_socat_pid" 
        fi
        # Kill SSH Agent
        SSH_AUTH_SOCK_DOCKER="${CONTAINER_FOLDER}/ssh/.ssh_auth_sock"

        if [ -e "${SSH_AUTH_SOCK_DOCKER}_pid" ]; then  # kill socat
            pkill -F "${SSH_AUTH_SOCK_DOCKER}_pid" socat
            rm ${SSH_AUTH_SOCK_DOCKER}_pid
        fi
        # Do not delete folder, this will cause issues with Docker bind mounts
        #rm -r ${CONTAINER_FOLDER} 
    fi
done
echo "Done"
