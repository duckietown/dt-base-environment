#!/bin/bash

# constants
CONFIG_DIR=/data/config
ROBOT_TYPE_FILE=${CONFIG_DIR}/robot_type
ROBOT_CONFIGURATION_FILE=${CONFIG_DIR}/robot_configuration

# if anything weird happens from now on, STOP
set -e

# get container ID
DT_MODULE_INSTANCE=$(basename "$(cat /proc/1/cpuset)")
export DT_MODULE_INSTANCE


debug(){
  if [ "${DEBUG}" = "1" ]; then
    echo "$1";
  fi
}


configure_vehicle(){
  # check the mandatory arguments
  VEHICLE_NAME_IS_SET=1
  if [ ${#VEHICLE_NAME} -le 0 ]; then
    VEHICLE_NAME_IS_SET=0
    VEHICLE_NAME=$(hostname)
    echo "The environment variable VEHICLE_NAME is not set. Using '${VEHICLE_NAME}'."
  fi
  export VEHICLE_NAME="${VEHICLE_NAME}"

  # check optional arguments
  VEHICLE_IP_IS_SET=0
  if [ ${#VEHICLE_IP} -ne 0 ]; then
    VEHICLE_IP_IS_SET=1
    echo "The environment variable VEHICLE_IP is set to '${VEHICLE_IP}'. Adding to /etc/hosts."
    {
      echo "${VEHICLE_IP} ${VEHICLE_NAME} ${VEHICLE_NAME}.local" | dd of=/etc/hosts &>/dev/null
    } || {
      echo "WARNING: Failed writing to /etc/hosts. Will continue anyway."
    }
  fi

  # configure hosts
  if [ "${VEHICLE_NAME_IS_SET}" -eq "0" ]; then
    # vehicle name not set (assume vehicle is localhost)
    {
      echo "127.0.0.1 ${VEHICLE_NAME} ${VEHICLE_NAME}.local" | dd of=/etc/hosts &>/dev/null
    } || {
      echo "WARNING: Failed writing to /etc/hosts. Will continue anyway."
    }
  fi

  # robot_type
  if [ -f "${ROBOT_TYPE_FILE}" ]; then
      ROBOT_TYPE=$(cat ${ROBOT_TYPE_FILE})
      export ROBOT_TYPE
  else
      echo "WARNING: robot_type file does not exist. Using 'duckiebot' as default type."
      export ROBOT_TYPE="duckiebot"
  fi

  # robot_configuration
  if [ -f "${ROBOT_CONFIGURATION_FILE}" ]; then
      ROBOT_CONFIGURATION=$(cat ${ROBOT_CONFIGURATION_FILE})
      export ROBOT_CONFIGURATION
  else
      echo "WARNING: robot_configuration file does not exist."
      export ROBOT_CONFIGURATION="__NOTSET__"
  fi
}


configure_python(){
  # make the code discoverable by python
  for d in $(find ${SOURCE_DIR} -mindepth 1 -maxdepth 1 -type d); do
    if [ "${DEBUG}" = "1" ]; then echo " > Adding ${d} to PYTHONPATH"; fi
    export PYTHONPATH="${d}:${PYTHONPATH}"
  done
}


configure_ROS(){
  # check if ROS_MASTER_URI is set
  ROS_MASTER_URI_IS_SET=0
  if [ -n "${ROS_MASTER_URI}" ]; then
    ROS_MASTER_URI_IS_SET=1
  fi

  # constants
  ROS_SETUP=(
    "/opt/ros/${ROS_DISTRO}/setup.bash"
    "${SOURCE_DIR}/catkin_ws/devel/setup.bash"
    "${SOURCE_DIR}/setup.sh"
  )

  # setup ros environment
  for ROS_SETUP_FILE in "${ROS_SETUP[@]}"; do
    if [ -f "${ROS_SETUP_FILE}" ]; then
      source "${ROS_SETUP_FILE}";
    fi
  done

  # configure ROS IP
  CONTAINER_IP=$(hostname -I 2>/dev/null | cut -d " " -f 1)
  export ROS_IP=${CONTAINER_IP}

  # configure ROS MASTER URI
  if [ "${ROS_MASTER_URI_IS_SET}" -eq "0" ]; then
    export ROS_MASTER_URI="http://${VEHICLE_NAME}.local:11311/"
  fi
}


# configure
debug "=> Setting up vehicle configuration..."
configure_vehicle
debug "<= Done!\n"

debug "=> Setting up PYTHONPATH..."
configure_python
debug "<= Done!\n"

debug "=> Configuring ROS environment..."
configure_ROS
debug "<= Done!\n"


# if anything weird happens from now on, CONTINUE
set +e


# reuse LAUNCHER as CMD if the var is set and the first argument is `--`
if [ ${#LAUNCHER} -gt 0 ] && [ "$1" == "--" ]; then
  shift
  exec bash -c "dt-launcher-$LAUNCHER $*"
else
  exec "$@"
fi
