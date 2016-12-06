#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset

IN=origin
for version in v5.5 v5.6; do
  cp -r $IN $version
  find $version -type f -exec sed -i -f "${version}.sed" \{\} \;
done
