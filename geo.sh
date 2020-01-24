#!/bin/bash

ROOT_DIR=${PWD}
SERVICES_DIR=${ROOT_DIR}'/services'
UTILS_DIR=${ROOT_DIR}'/utils'
DOS2UNIX="${UTILS_DIR}/dos2unix.exe"
BASE_DIR=${SERVICES_DIR}'/base'
SUBSCRIPTION_MANAGER_DIR=${SERVICES_DIR}"/subscription_manager"
SUBSCRIPTION_MANAGER_DIR_SRC=${SUBSCRIPTION_MANAGER_DIR}"/src"
GEOFENCING_SERVICE_DIR=${SERVICES_DIR}"/geofencing_service"
GEOFENCING_SERVICE_DIR_SRC=${GEOFENCING_SERVICE_DIR}"/src"
GEOFENCING_VIEWER_DIR=${SERVICES_DIR}"/geofencing_viewer"
GEOFENCING_VIEWER_DIR_SRC=${GEOFENCING_VIEWER_DIR}"/src"
GEOFENCING_USER_CONFIG_DIR=${SERVICES_DIR}"/swim_user_config"

is_windows() {
  UNAME=$(uname)

  [[ "${UNAME}" != "Linux" ]] && [[ "${UNAME}" != "Darwin" ]]
}

user_config() {

  echo "GEOFENCING user configuration..."
  echo -e "=========================="

  ENV_FILE="${ROOT_DIR}/swim.env"

  touch "${ENV_FILE}"

  python "${GEOFENCING_USER_CONFIG_DIR}/main.py" "${GEOFENCING_USER_CONFIG_DIR}/config.json" "${ENV_FILE}"

  if is_windows
  then
    "${DOS2UNIX}" -q "${ENV_FILE}"
  fi

  while read LINE; do export "$LINE"; done < "${ENV_FILE}"

  rm "${ENV_FILE}"
}

prepare_repos() {
  echo "Preparing Git repositories..."
  echo -e "============================\n"

  echo -n "Preparing subscription-manager..."
  if [[ -d ${SUBSCRIPTION_MANAGER_DIR_SRC} ]]
  then
    cd "${SUBSCRIPTION_MANAGER_DIR_SRC}" || exit
    git pull -q --rebase origin master
  else
    git clone -q https://github.com/eurocontrol-swim/subscription-manager.git "${SUBSCRIPTION_MANAGER_DIR_SRC}"
  fi
  echo "OK"

  echo -n "Preparing geofencing-service..."
  if [[ -d ${GEOFENCING_SERVICE_DIR_SRC} ]]
  then
    cd "${GEOFENCING_SERVICE_DIR_SRC}" || exit
    git pull -q --rebase origin master
  else
    git clone -q https://github.com/eurocontrol-swim/geofencing-service.git "${GEOFENCING_SERVICE_DIR_SRC}"
  fi
  echo "OK"

  echo -n "Preparing geofencing-viewer..."
  if [[ -d ${GEOFENCING_VIEWER_DIR_SRC} ]]
  then
    cd "${GEOFENCING_VIEWER_DIR_SRC}" || exit
    git pull -q --rebase origin master
  else
    git clone -q https://github.com/eurocontrol-swim/geofencing-viewer.git "${GEOFENCING_VIEWER_DIR_SRC}"
  fi
  echo "OK"

  echo -e "\n"
}

data_provision() {
  echo "Data provisioning to Subscription Manager..."
  echo -e "============================================\n"
  docker-compose run subscription-manager-provision
  echo ""
}

start_services() {
  echo "Starting up GEOFENCING..."
  echo -e "===================\n"
  docker-compose up -d web-server subscription-manager geofencing-service geofencing-viewer
  echo ""
}

stop_services_with_clean() {
  echo "Stopping GEOFENCING..."
  echo -e "================\n"
  docker-compose down
  echo ""
}

stop_services() {
  echo "Stopping GEOFENCING..."
  echo -e "================\n"
  docker-compose stop
  echo ""
}

build() {
  echo "Building images..."
  echo -e "==================\n"
  # build the base image upon which the swim services will depend on
  cd "${BASE_DIR}" || exit 1

  docker build -t swim-base -f Dockerfile .

  docker build -t swim-base.conda -f Dockerfile.conda .

  docker-compose build

  cd "${ROOT_DIR}" || exit 1
  echo ""

  echo "Removing obsolete docker images..."
  echo -e "==================================\n"
  docker images | grep none | awk '{print $3}' | xargs -r docker rmi
}

status() {
  docker ps
}

usage() {
  echo -e "Usage: swim.sh [COMMAND] [OPTIONS]\n"
  echo "Commands:"
  echo "    user_config     Prompts for username/password of all the swim related users"
  echo "    build           Clones/updates the necessary git repositories and builds the involved docker images"
  echo "    provision       Provisions the Subscription Manager with initial data (users)"
  echo "    start           Starts up all the GEOFENCING services"
  echo "    stop            Stops all the services"
  echo "    stop --clean    Stops all the services and cleans up the containers"
  echo "    status          Displays the status of the running containers"
  echo ""
}

if [[ $# -lt 1 || $# -gt 2  ]]
then
  usage
  exit 0
fi

ACTION=${1}

case ${ACTION} in
  build)
    # update the repos if they exits othewise clone them
    prepare_repos
    # build the images
    build
    ;;
  start)
    start_services
    ;;
  stop)
    if [[ -n ${2} ]]
    then
      EXTRA=${2}

      case ${EXTRA} in
          --clean)
            stop_services_with_clean
            ;;
          *)
            echo -e "Invalid argument\n"
            usage
            exit 1
            ;;
        esac
        exit 0
    fi
    stop_services
    ;;
  provision)
    data_provision
    ;;
  status)
    status
    ;;
  user_config)
    user_config
    ;;
  help)
    usage
    ;;
  *)
    echo -e "Invalid action\n"
    usage
    exit 1
    ;;
esac
