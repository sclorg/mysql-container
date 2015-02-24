#!/bin/bash -e
# $1 - Specifies distribution - RHEL7/CentOS7
# $2 - Specifies MySQL version - 5.5

# Array of all versions of MySQL
declare -a VERSIONS=(5.5)

OS=$1
VERSION=$2

function docker_build {
  TAG=$1
  DOCKERFILE=$2

  if [ -n "$DOCKERFILE" -a "$DOCKERFILE" != "Dockerfile" ]; then
    # Swap Dockerfiles and setup a trap restoring them
    mv Dockerfile Dockerfile.centos7
    mv "${DOCKERFILE}" Dockerfile
    trap "mv Dockerfile ${DOCKERFILE} && mv Dockerfile.centos7 Dockerfile" ERR RETURN
  fi

  docker build -t ${TAG} . && trap - ERR
}

if [ -z ${VERSION} ]; then
  # Build all versions
  dirs=${VERSIONS}
else
  # Build only specified version on MySQL
  dirs=${VERSION}
fi

for dir in ${dirs}; do
  IMAGE_NAME=openshift/mysql-${dir//./}-${OS}
  echo ">>>> Building ${IMAGE_NAME}"

  pushd ${dir} > /dev/null

  if [ "$OS" == "rhel7" ]; then
    docker_build ${IMAGE_NAME} Dockerfile.rhel7
  else
    docker_build ${IMAGE_NAME}
  fi

  popd > /dev/null
done
