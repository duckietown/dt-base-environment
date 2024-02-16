# parameters
ARG ARCH
ARG DISTRO
ARG BASE_REPOSITORY
ARG BASE_TAG
ARG LAUNCHER=default
# ---
ARG PROJECT_NAME
ARG PROJECT_MAINTAINER
ARG PROJECT_DESCRIPTION="Base image of any Duckietown software module. Based on ${BASE_REPOSITORY}:${BASE_TAG}."
ARG PROJECT_ICON="square"
ARG PROJECT_FORMAT_VERSION

# base image
FROM docker.io/${ARCH}/${BASE_REPOSITORY}:${BASE_TAG}

# recall all arguments
ARG ARCH
ARG BASE_REPOSITORY
ARG BASE_TAG
ARG DISTRO
ARG LAUNCHER
ARG PROJECT_NAME
ARG PROJECT_DESCRIPTION
ARG PROJECT_MAINTAINER
ARG PROJECT_ICON
ARG PROJECT_FORMAT_VERSION
# - buildkit
ARG TARGETPLATFORM
ARG TARGETOS
ARG TARGETARCH
ARG TARGETVARIANT

# setup environment
ENV INITSYSTEM="off" \
    TERM="xterm" \
    LANG="C.UTF-8" \
    LC_ALL="C.UTF-8" \
    READTHEDOCS="True" \
    PYTHONIOENCODING="UTF-8" \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED="1" \
    DEBIAN_FRONTEND="noninteractive" \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    DISABLE_CONTRACTS=1 \
    QEMU_EXECVE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_ROOT_USER_ACTION=ignore

# nvidia runtime configuration
ENV NVIDIA_VISIBLE_DEVICES="all" \
    NVIDIA_DRIVER_CAPABILITIES="all"

# OS info
ENV OS_FAMILY="${BASE_REPOSITORY}" \
    OS_DISTRO="${BASE_TAG}"

# code environment
ENV WORKSPACE_DIR="/code" \
    SOURCE_DIR="/code/src" \
    LAUNCHERS_DIR="/launch" \
    USER_WS_DIR="/user_ws" \
    MINIMUM_DTPROJECT_FORMAT_VERSION="4"

# start inside the course code directory
WORKDIR "${SOURCE_DIR}"

# copy QEMU
COPY ./assets/qemu/${TARGETPLATFORM}/ /usr/bin/

# copy binaries
COPY ./assets/bin/. /usr/local/bin/

# define and create repository paths
ARG PROJECT_PATH="${SOURCE_DIR}/${PROJECT_NAME}"
ARG PROJECT_LAUNCHERS_PATH="${LAUNCHERS_DIR}/${PROJECT_NAME}"
RUN mkdir -p "${PROJECT_PATH}/packages" "${PROJECT_LAUNCHERS_PATH}" "${USER_WS_DIR}"

# keep some arguments as environment variables
ENV DT_PROJECT_NAME="${PROJECT_NAME}" \
    DT_PROJECT_DESCRIPTION="${PROJECT_DESCRIPTION}" \
    DT_PROJECT_MAINTAINER="${PROJECT_MAINTAINER}" \
    DT_PROJECT_ICON="${PROJECT_ICON}" \
    DT_PROJECT_PATH="${PROJECT_PATH}" \
    DT_PROJECT_LAUNCHERS_PATH="${PROJECT_LAUNCHERS_PATH}" \
    DT_LAUNCHER="${LAUNCHER}"

# Install gnupg required for apt-key (not in base image since Focal)
RUN apt-get update \
  && apt-get install -y --no-install-recommends gnupg \
  && rm -rf /var/lib/apt/lists/*

# install dependencies (APT)
COPY ./dependencies-apt.txt "${PROJECT_PATH}/"
RUN dt-apt-install "${PROJECT_PATH}/dependencies-apt.txt"

# install dependencies (PIP3)
ARG PIP_INDEX_URL="https://pypi.org/simple"
ENV PIP_INDEX_URL=${PIP_INDEX_URL}

# upgrade PIP
RUN python3 -m pip install pip==23.2

# install dependencies (PIP3)
COPY ./dependencies-py3.* "${PROJECT_PATH}/"
RUN dt-pip3-install "${PROJECT_PATH}/dependencies-py3.*"

# check build arguments
RUN dt-args-check \
    "ARCH" "${ARCH}" \
    "DISTRO" "${DISTRO}" \
    "PROJECT_FORMAT_VERSION" "${PROJECT_FORMAT_VERSION}" \
    && dt-check-project-format "${PROJECT_FORMAT_VERSION}"

# copy the assets (needed by sibling images)
COPY ./assets "${PROJECT_PATH}/assets"

# copy the source code
COPY ./packages "${PROJECT_PATH}/packages"

# configure terminal size in docker: https://docs.python.org/3/library/shutil.html#shutil.get_terminal_size
ENV COLUMNS 160

# install launcher scripts
COPY ./launchers/default.sh "${PROJECT_LAUNCHERS_PATH}/"
RUN dt-install-launchers "${PROJECT_LAUNCHERS_PATH}"

# define default command
CMD ["bash", "-c", "dt-launcher-${DT_LAUNCHER}"]

# store module metadata
LABEL \
    # module info
    org.duckietown.label.project.name="${PROJECT_NAME}" \
    org.duckietown.label.project.description="${PROJECT_DESCRIPTION}" \
    org.duckietown.label.project.maintainer="${PROJECT_MAINTAINER}" \
    org.duckietown.label.project.icon="${PROJECT_ICON}" \
    org.duckietown.label.project.path="${PROJECT_PATH}" \
    org.duckietown.label.project.launchers.path="${PROJECT_LAUNCHERS_PATH}" \
    # format
    org.duckietown.label.format.version="${PROJECT_FORMAT_VERSION}" \
    # platform info
    org.duckietown.label.platform.os="${TARGETOS}" \
    org.duckietown.label.platform.architecture="${TARGETARCH}" \
    org.duckietown.label.platform.variant="${TARGETVARIANT}" \
    # code info
    org.duckietown.label.code.distro="${DISTRO}" \
    org.duckietown.label.code.launcher="${LAUNCHER}" \
    org.duckietown.label.code.python.registry="${PIP_INDEX_URL}" \
    # base info
    org.duckietown.label.base.organization="${ARCH}" \
    org.duckietown.label.base.repository="${BASE_REPOSITORY}" \
    org.duckietown.label.base.tag="${BASE_TAG}"

# install packages
RUN dt-git-install-package "ros2/launch" 3.1.0 && \
    dt-git-install-package "ros2/python_cmake_module" 0.11.0 && \
    dt-git-install-package "ament/ament_index" 1.7.0

# build packages
RUN cd ${WORKSPACE_DIR} && \
    colcon build --symlink-install
