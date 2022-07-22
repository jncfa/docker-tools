#!/usr/bin/bash

# Grab arguments passed to the script
POSITIONAL_ARGS=()
DOCKER_ARGS=() # additional args we can pass to Docker
while [[ $# -gt 0 ]]; do
  case $1 in
    -t|--tag)
      CONTAINER_TAG="$2"
      shift # past argument
      shift # past value
      ;;
    -n|--name)
      CONTAINER_NAME="$2"
      shift # past argument
      shift # past value
      ;;
    -d|--detach)
      [[ ! " ${DOCKER_ARGS[*]} " =~ " -d " ]] && DOCKER_ARGS+=("-d")
      shift # past argument
      ;;
    --rm)
      [[ ! " ${DOCKER_ARGS[*]} " =~ " --rm " ]] && DOCKER_ARGS+=("--rm") 
      shift # past argument
      ;;
    -it)
      [[ ! " ${DOCKER_ARGS[*]} " =~ " -it " ]] && DOCKER_ARGS+=("-it") 
      shift # past argument
      ;;
    -*|--*)
      echo "Unknown option $1"
      exit 1
      ;;
    *)
      POSITIONAL_ARGS+=("$1") # save positional arg
      shift # past argument
      ;;
  esac
done
set -- "${POSITIONAL_ARGS[@]}" # restore positional parameters

# Grab arguments passed to the script
if [[ $# -eq 0 ]]; then
    if [[ ! -v CONTAINER_TAG ]]; then
      echo "Please enter a Docker image name to create the new container."
      exit 1
    else
      # create random name if none chosen
      if [[ ! -v CONTAINER_NAME ]]; then
        echo "creating random name 1"
        CONTAINER_NAME="${USER}-container-${RANDOM}"
      fi  
    fi 
elif [[ $# -eq 1 ]]; then
    if [[ ! -v CONTAINER_TAG ]]; then
      echo "updating tag 1"
      CONTAINER_TAG=$1

    # create random name if none chosen
    if [[ ! -v CONTAINER_NAME ]]; then
      echo "creating random name 1"
      CONTAINER_NAME="${USER}-container-${RANDOM}"
    fi  

    else
      echo "updating name 1"
      CONTAINER_NAME=$1
    fi   
elif [[ $# -eq 2 ]]; then
  if [[ -v CONTAINER_TAG ]] || [[ -v CONTAINER_NAME ]];
    echo "Too many arguments passed, exiting..."
    exit 1
  then
    CONTAINER_TAG=$1
    CONTAINER_NAME=$2
  fi
else
    echo "Too many arguments passed, exiting... (${@:3})"
    exit 1
fi
# get md5 sum of tag + name to ensure we can use multiple containers
CONTAINER_MD5HASH=`echo "${CONTAINER_TAG}${CONTAINER_NAME}" | md5sum | awk '{print $1}'`

# Create a directory for the socket and Xauthority
BASE_FOLDER=${HOME}/.docker-redirect
CONTAINER_FOLDER="${BASE_FOLDER}/${CONTAINER_MD5HASH}"

#[ -d ${CONTAINER_FOLDER} ] && rm -r ${CONTAINER_FOLDER}
mkdir -p ${CONTAINER_FOLDER}

# Prepare target env
CONTAINER_HOSTNAME=${HOSTNAME} # use the same hostname to avoid issues with X11 forwading (kind of a hack)

# setup X11 forwarding 
if [[ -v DISPLAY ]]; then
  # Get the DISPLAY slot currently being used
  DISPLAY_NUMBER=$(echo $DISPLAY | cut -d. -f1 | cut -d: -f2)
  # Extract current authentication cookie
  AUTH_COOKIE=$(xauth list | grep "^$(hostname)/unix:${DISPLAY_NUMBER} " | awk '{print $3}')

  # Create the new X Authority file
  X11_DOCKER_DIR="${CONTAINER_FOLDER}/x11"
  mkdir -p ${X11_DOCKER_DIR}
  touch ${X11_DOCKER_DIR}/.Xauthority
  xauth -f ${X11_DOCKER_DIR}/.Xauthority add ${CONTAINER_HOSTNAME}/unix:0 MIT-MAGIC-COOKIE-1 ${AUTH_COOKIE}
  chmod a+rw ${X11_DOCKER_DIR}/.Xauthority
  if [ -e "${X11_DOCKER_DIR}/socket/X0" ]; then  # kill old socat & replace with new one
      pkill -F "${X11_DOCKER_DIR}/.x11_socat_pid" socat
      rm "${X11_DOCKER_DIR}/.x11_socat_pid" # it should be created in the end anyway, but this helps in case there is an error during docker run
  fi
  # Proxy with the :0 DISPLAY and save PID in folder
  mkdir -p ${X11_DOCKER_DIR}/socket
  socat UNIX-LISTEN:${X11_DOCKER_DIR}/socket/X0,fork,mode=666 TCP4:localhost:60${DISPLAY_NUMBER} &
  echo $! > "${X11_DOCKER_DIR}/.x11_socat_pid"

  echo "Forwarded X11 sucessfully!"
else
  echo "Skipping X11 forwarding.."
fi

SSH_DOCKER_DIR="${CONTAINER_FOLDER}/ssh"
mkdir -p ${SSH_DOCKER_DIR}
# Dupe SSH Agent
SSH_AUTH_SOCK_DOCKER="${SSH_DOCKER_DIR}/.ssh_auth_sock"
if [ -e "${SSH_AUTH_SOCK_DOCKER}_pid" ]; then  # kill old socat & replace with new one
    pkill -F "${SSH_AUTH_SOCK_DOCKER}_pid" socat
    rm ${SSH_AUTH_SOCK_DOCKER}_pid
fi

socat UNIX-LISTEN:${SSH_AUTH_SOCK_DOCKER},fork,mode=666 UNIX-CLIENT:${SSH_AUTH_SOCK} &
echo $! > ${SSH_AUTH_SOCK_DOCKER}_pid
echo "Forwarded SSH Agent sucessfully!"

# Launch the container if it's not running already
if [ "$(docker ps -a | grep ${CONTAINER_NAME})" ]; then
  if [ "$(docker ps | grep ${CONTAINER_NAME})" ]; then
    echo "Container already running"
  else
    echo "Container already created but not running, starting container now..."
    docker start ${CONTAINER_NAME} >> /dev/null
  fi

#--gpus all --ipc=host --ulimit memlock=-1 --ulimit stack=67108864
else
  docker run \
  --runtime=nvidia \
  --name ${CONTAINER_NAME} \
  -v ${SSH_DOCKER_DIR}:/ssh \
  -v ${X11_DOCKER_DIR}/socket:/tmp/.X11-unix \
  -v ${X11_DOCKER_DIR}:/tmp/.X11-tmp-dir \
  -v ${HOME}/docker_workspace:/docker_workspace \
  -e DISPLAY=:0 \
  -e LIBGL_ALWAYS_INDIRECT=1 \
  -e SSH_AUTH_SOCK=/ssh/.ssh_auth_sock \
  -e XAUTHORITY=/tmp/.X11-tmp-dir/.Xauthority \
  --hostname ${CONTAINER_HOSTNAME} \
  ${DOCKER_ARGS[@]} ${CONTAINER_TAG} 
fi
