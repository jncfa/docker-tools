#!/usr/bin/bash
# Grab arguments passed to the script
CONTAINER_NAME="x11-test" # name of the container to execute

# Prepare target env
CONTAINER_DISPLAY="0" #$((`ls display/socket/ | wc -l`+1))
CONTAINER_HOSTNAME=${HOSTNAME}

# Create a directory for the socket and Xauthority
BASE_FOLDER=${HOME}/.ssh

# Launch the container w
docker run \
  -it --rm \
  --name 'jose-container' \
  -e DISPLAY=:${CONTAINER_DISPLAY} \
  -e SSH_AUTH_SOCK=/ssh-agent \
  -v $HOME/.ssh/.ssh_auth_sock:/ssh-agent \
  -v /home/jose/trustid_image_processing:/trustid \
  --hostname ${CONTAINER_HOSTNAME} \
  --net=host \
  --gpus all --ipc=host --ulimit memlock=-1 --ulimit stack=67108864 \
  jupyter/scipy-notebook 
#nvcr.io/nvidia/pytorch:21.07-py3

# Kill socket redirection
echo "Finished"
