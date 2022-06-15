# Prepare target env
CONTAINER_DISPLAY="0" #$((`ls display/socket/ | wc -l`+1))
CONTAINER_HOSTNAME=$(hostname)
CONTAINER_NAME="x11-test" # name of the container to execute

# Create a directory for the socket and Xauthority
BASE_FOLDER="$(mktemp -d -t docker-redirect.XXXXXX)"
mkdir $BASE_FOLDER/socket
touch $BASE_FOLDER/Xauthority

# Get the DISPLAY slot
DISPLAY_NUMBER=$(echo $DISPLAY | cut -d. -f1 | cut -d: -f2)

# Extract current authentication cookie
AUTH_COOKIE=$(xauth list | grep "^$(hostname):${DISPLAY_NUMBER} " | awk '{print $3}')

# Create the new X Authority file
xauth -f $BASE_FOLDER/Xauthority add ${CONTAINER_HOSTNAME}/unix:${CONTAINER_DISPLAY} MIT-MAGIC-COOKIE-1 ${AUTH_COOKIE}

# Proxy with the :0 DISPLAY and grab PID
socat UNIX-LISTEN:$BASE_FOLDER/socket/X${CONTAINER_DISPLAY},fork TCP4:localhost:60${DISPLAY_NUMBER} &
SOCAT_PID=$! 

# Launch the container
docker run -it --rm \
  -e DISPLAY=:${CONTAINER_DISPLAY} \
  -e XAUTHORITY=/tmp/.Xauthority \
  -v ${BASE_FOLDER}/socket:/tmp/.X11-unix \
  -v ${BASE_FOLDER}/Xauthority:/tmp/.Xauthority \
  --hostname ${CONTAINER_HOSTNAME} \
  ${CONTAINER_NAME}

# Kill socket redirection
kill $SOCAT_PID
echo "Finished"