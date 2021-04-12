# Copyright 2018 Carbon Black Inc.  All rights reserved.
TOP_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/.."

source ${BUILD_UTIL_DIR}/sh-utils/conan-utils.sh

# Expand env variables
function do_validate_env_step
{
    echo "Beginning do_validate_env_step..."
    BUILD_DIR=$(echo ${BUILD_DIR} | envsubst)
    BUILD_DIR=${BUILD_DIR//${DUB_SLSH}/${SLSH}}
    export ORIGINAL_SOURCE=${TOP_DIR}/src

    export PROJECT_VERSION=$(echo ${PROJECT_VERSION} | envsubst)
    export JOBS=$(echo "-j${JOBS}" | envsubst)

    export PLATFORM_BUILD=${BUILD_DIR}/${SERVICE}

    if [ "$BUILD_VERBOSE" == "yes" ]; then
        export VERBOSE_OPT=VERBOSE=1
    fi

    if [[ $BUILD_TYPE == "debug" ]]; then
        CMAKE_BUILD_TYPE=Debug
    elif [[ $BUILD_TYPE == "release" ]]; then
        CMAKE_BUILD_TYPE=RelWithDebInfo
    else
        echo >&2 "$0: INVALID BUILD TYPE $1"
        exit 1
    fi
    export CMAKE_BUILD_TYPE

    export COVERITY_BUILD_DIR=$(echo ${COVERITY_BUILD_DIR} | envsubst)

    export CONAN_PROFILE=$(echo ${CONAN_PROFILE} | envsubst)

    export SOURCE_VERSION=$(echo ${SOURCE_VERSION} | envsubst)

    export PACKAGE_VERSION=$PROJECT_VERSION
    export PACKAGE_MAJOR_VERSION=$(echo ${PROJECT_VERSION} | cut -d "." -f 1 )
    export PACKAGE_MINOR_VERSION=$(echo ${PROJECT_VERSION} | cut -d "." -f 2 )
    export PACKAGE_POINT_VERSION=$(echo ${PROJECT_VERSION} | cut -d "." -f 3 )
    export PACKAGE_DIR=$(echo ${PACKAGE_DIR} | envsubst)
    export PACKAGE_NAME=$(echo ${PACKAGE_NAME} | envsubst)
    export PACKAGE_CHANNEL=$(echo ${PACKAGE_CHANNEL} | envsubst)
    export PACKAGE_PATH=$(echo ${PACKAGE_PATH} | envsubst)

    echo "Finished do_validate_env_step."
}

function do_prepare_step
{
    echo "Beginning do_prepare_step..."
    rm -rf ${BUILD_DIR}/*

    echo "KERNEL_EVENT_COLLECTOR_MODULE_VERSION: ${PACKAGE_NAME}" > ${BUILD_DIR}/manifest

    pushd ${TOP_DIR} &>/dev/null

    # Add git metadata to the build
    GIT_BRANCH="${GIT_BRANCH:-$(git rev-parse --abbrev-ref HEAD)}"
    GIT_COMMIT="${GIT_COMMIT:-$(git rev-parse HEAD)}"

    echo "  Building from $GIT_BRANCH @ $GIT_COMMIT"
    echo "$GIT_BRANCH" > ${BUILD_DIR}/branch.git.txt
    echo "$GIT_COMMIT" > ${BUILD_DIR}/revision.git.txt

    popd &>/dev/null
    echo "Finished do_prepare_step."
}

source ${BUILD_UTIL_DIR}/sh-utils/build-tdd.sh

function build_kernel
{
    pushd ${PLATFORM_BUILD} &>/dev/null
    if [ ${FAST_BUILD} -ne 1 ]; then
        cmake -DCMAKE_TOOLCHAIN_FILE=${CONAN_CMAKE_TOOLCHAIN_FILE} \
              -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE} \
              -S ${ORIGINAL_SOURCE} \
              -B ${PLATFORM_BUILD}
    fi


    cmake --build ${PLATFORM_BUILD} -- --no-print-directory ${VERBOSE_OPT}
    RET=$?
    if [[ $RET = 0 && "${SKIP_PACKAGING}" != "True" ]]; then
        if [ "$QUIET_PACKAGING" == "yes" ]; then
            QMSG="(quiet)"
            exec 3>/dev/null
        else
            exec 3>&1
        fi
        # Export the package into the local cache
        echo "# Packaging... $QMSG"
        flock ${BUILD_DIR} conan export-pkg -f \
              --build-folder ${PLATFORM_BUILD} \
              --source-folder ${ORIGINAL_SOURCE} \
              ${PLATFORM_BUILD} \
              ${PACKAGE_CHANNEL} >&3
    fi
    popd &>/dev/null
}

function tdd_build_kernel
{
    sync_source_files
    build_kernel
}

function sync_source_files
{
    sync_directory ${PLATFORM_BUILD} ${ORIGINAL_SOURCE}

    # Replace the version string
    find ${PLATFORM_BUILD} -type f -iname conanfile.py -print0 | while IFS= read -r -d $'\0' file; do
        apply_file_replacements $file
    done
}

function do_build_step
{
    echo "Doing build step for kernel module..."

    sync_source_files

    echo "# Building in ${BUILD_DIR}..."

    if [ "$PACKAGE_OPTIONS" != "None" ]; then
        O=$PACKAGE_OPTIONS
    fi
    PACKAGE_OPTIONS=""
    for i in $(echo $O | sed "s/,/ /g"); do
        PACKAGE_OPTIONS="$PACKAGE_OPTIONS -o $i"
    done
    export PACKAGE_OPTIONS=$(echo ${PACKAGE_OPTIONS} | envsubst)

    local CONAN_UPDATE="--update"
    if [ "${PREFER_LOCAL_CACHE}" = "yes" ]; then
        CONAN_UPDATE=""
    fi

    if [ $FAST_BUILD -ne 1 ]; then
        echo "--- Installing Packages"
        flock ${BUILD_DIR} conan install \
            --profile ${CONAN_PROFILE} \
            ${CONAN_UPDATE} \
            ${PACKAGE_OPTIONS} \
            --install-folder ${PLATFORM_BUILD} \
            ${PLATFORM_BUILD}
    fi

    # Build the package
    if [ "${TDD_MODE}" = "yes" ]; then\
        (watch_for_changes ${ORIGINAL_SOURCE} - tdd_build_kernel   - ${BUILD_DIR} -) &
        wait
    else
        build_kernel
    fi

    echo "Done doing build step for kernel module."
}

function do_package_step
{
    echo "Doing package step for kernel module..."

    echo "Done doing package step for kernel module."
}

function do_package_fail_step
{
    echo "Doing package fail step for kernel module..."

    echo "Done doing package fail step for kernel module."
}
