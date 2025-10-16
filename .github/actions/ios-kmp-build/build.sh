#!/bin/bash
set -e

if [ "$INPUT_KMP_SWIFT_PACKAGE_INTEGRATION" == "true" ]; then
    cd "$INPUT_KMP_SWIFT_PACKAGE_PATH"
    export KMP_BUILD_FLAVOR="$INPUT_KMP_SWIFT_PACKAGE_FLAVOR"
    export KMP_FRAMEWORK_BUILD_TYPE="release"
    make build
fi