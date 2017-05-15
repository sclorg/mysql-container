# Variables are documented in common/build.sh.
BASE_IMAGE_NAME = mysql
VERSIONS = 5.6 5.7
OPENSHIFT_NAMESPACES = 5.5

# HACK:  Ensure that 'git pull' for old clones doesn't cause confusion.
# New clones should use '--recursive'.
.PHONY: $(shell test -f common/common.mk || echo >&2 'Please do "git submodule update --init" first.')

include common/common.mk
