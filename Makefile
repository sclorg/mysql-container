# Variables are documented in hack/build.sh.
BASE_IMAGE_NAME = mysql
VERSIONS = 5.5 5.6 5.7
OPENSHIFT_NAMESPACES = 5.5

# Include common Makefile code.
include hack/common.mk
