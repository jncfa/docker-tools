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
if [[ $# -eq 0 ]]
then
  echo "Please enter a Docker image name to create the new container."
  exit 1
elif [[ $# -eq 1 ]]
then
    if [[ ! -v CONTAINER_TAG ]]; then
      CONTAINER_TAG=$1
    else
      CONTAINER_NAME=$1
    fi 

    # create random name if none chosen
    if [[ ! -v CONTAINER_NAME ]]; then
      CONTAINER_NAME="${USER}-container-${RANDOM}"
    fi    
elif [[ $# -eq 2 ]]
then
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

[ -d ${CONTAINER_FOLDER} ] && rm -d ${CONTAINER_FOLDER}
mkdir -p ${CONTAINER_FOLDER}

# Prepare target env
CONTAINER_HOSTNAME=${HOSTNAME} # use the same hostname to avoid issues with X11 forwading (kind of a hack)

if [[ -v DISPLAY ]]; then
  # Get the DISPLAY slot currently being used
  DISPLAY_NUMBER=$(echo $DISPLAY | cut -d. -f1 | cut -d: -f2)

  # Extract current authentication cookie
  AUTH_COOKIE=$(xauth list | grep "^$(hostname):${DISPLAY_NUMBER} " | awk '{print $3}')

  # Create the new X Authority file
  touch ${CONTAINER_FOLDER}/.Xauthority
  xauth -f ${CONTAINER_FOLDER}/.Xauthority add ${CONTAINER_HOSTNAME}/unix:0 MIT-MAGIC-COOKIE-1 ${AUTH_COOKIE}

  if [ -e "${CONTAINER_FOLDER}/socket/X0" ]; then  # kill old socat & replace with new one
      pkill -F "${CONTAINER_FOLDER}/.x11_socat_pid" socat
      rm "${CONTAINER_FOLDER}/.x11_socat_pid" # it should be created in the end anyway, but this helps in case there is an error during docker run
  fi
  # Proxy with the :0 DISPLAY and save PID in folder
  mkdir -p ${CONTAINER_FOLDER}/socket
  socat UNIX-LISTEN:${CONTAINER_FOLDER}/socket/X0,fork TCP4:localhost:60${DISPLAY_NUMBER} &
  echo $! > "${CONTAINER_FOLDER}/.x11_socat_pid"
else
  echo "Skipping X11 forwarding.."
fi

# Launch the container if it's not running already
if [ "$(docker ps -a | grep ${CONTAINER_NAME})" ]; then
  echo "Container already running..."
else
  #For docker compose access the variables you need to export them
  # export...  
  docker compose up
fi
