#!/bin/bash -e
# $1 - Specifies distribution - RHEL7/CentOS7
# $2 - Specifies MySQL version - 5.5

# Array of all versions of MySQL
declare -a VERSIONS=(5.5)

OS=$1
VERSION=$2


function build_rhel {
  mv Dockerfile Dockerfile.centos7
  mv Dockerfile.rhel7 Dockerfile
  trap "mv Dockerfile Dockerfile.rhel7 && mv Dockerfile.centos7 Dockerfile" RETURN
  docker build -t ${IMAGE_NAME} .
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
    build_rhel
  else
    docker build -t ${IMAGE_NAME} .
  fi

  popd > /dev/null
done
