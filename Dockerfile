# parameters
ARG ROS_DISTRO=noetic
ARG OS_FAMILY=ubuntu
ARG OS_DISTRO=focal
ARG DISTRO=daffy
ARG LAUNCHER=default
# ---
ARG REPO_NAME="dt-base-environment"
ARG MAINTAINER="Andrea F. Daniele (afdaniele@ttic.edu)"
ARG DESCRIPTION="Base image of any Duckietown software module. Based on ${OS_FAMILY}:${OS_DISTRO}."
ARG ICON="square"

# base image
FROM ${OS_FAMILY}:${OS_DISTRO}

# recall all arguments
ARG OS_FAMILY
ARG OS_DISTRO
ARG ROS_DISTRO
ARG DISTRO
ARG LAUNCHER
ARG REPO_NAME
ARG DESCRIPTION
ARG MAINTAINER
ARG ICON
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
    PYTHONUNBUFFERED="1" \
    DEBIAN_FRONTEND="noninteractive" \
    DISABLE_CONTRACTS=1 \
    QEMU_EXECVE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_ROOT_USER_ACTION=ignore
# nvidia runtime configuration
ENV NVIDIA_VISIBLE_DEVICES="all" \
    NVIDIA_DRIVER_CAPABILITIES="all"

# keep some arguments as environment variables
ENV OS_FAMILY="${OS_FAMILY}" \
    OS_DISTRO="${OS_DISTRO}" \
    ROS_DISTRO="${ROS_DISTRO}" \
    DT_MODULE_TYPE="${REPO_NAME}" \
    DT_MODULE_DESCRIPTION="${DESCRIPTION}" \
    DT_MODULE_ICON="${ICON}" \
    DT_MAINTAINER="${MAINTAINER}" \
    DT_LAUNCHER="${LAUNCHER}"

# duckietown-specific settings
ENV DUCKIEFLEET_ROOT "/data/config"

# code environment
ENV SOURCE_DIR="/code" \
    LAUNCH_DIR="/launch"
ENV USER_WS_DIR "${SOURCE_DIR}/user_ws"
WORKDIR "${SOURCE_DIR}"

# copy QEMU
COPY ./assets/qemu/${TARGETPLATFORM}/ /usr/bin/

# copy binaries
COPY ./assets/bin/. /usr/local/bin/

# define and create repository paths
ARG REPO_PATH="${SOURCE_DIR}/${REPO_NAME}"
ARG LAUNCH_PATH="${LAUNCH_DIR}/${REPO_NAME}"
RUN mkdir -p "${REPO_PATH}" "${LAUNCH_PATH}" "${USER_WS_DIR}"
ENV DT_REPO_PATH="${REPO_PATH}" \
    DT_LAUNCH_PATH="${LAUNCH_PATH}"

# Install gnupg required for apt-key (not in base image since Focal)
RUN apt-get update \
  && apt-get install -y --no-install-recommends gnupg \
  && rm -rf /var/lib/apt/lists/*

# setup ROS sources
RUN apt-key adv \
    --keyserver hkp://keyserver.ubuntu.com:80 \
    --recv-keys F42ED6FBAB17C654 \
    && echo "deb http://packages.ros.org/ros/ubuntu ${OS_DISTRO} main" >> /etc/apt/sources.list.d/ros.list

# install dependencies (APT)
COPY ./dependencies-apt.txt "${REPO_PATH}/"
RUN dt-apt-install "${REPO_PATH}/dependencies-apt.txt"

# To fix CMake issue, we need to rebuild for arm
SHELL ["/bin/bash", "-c"]
ARG NCPUS=2
RUN if [ "$TARGETPLATFORM" == "linux/arm/v7" ]; \
    then \
      export CFLAGS="-D_FILE_OFFSET_BITS=64" && \
      export CXXFLAGS="-D_FILE_OFFSET_BITS=64" && \
      mkdir cmake && \
      git clone https://gitlab.kitware.com/cmake/cmake.git cmake && \
      cd cmake && \
      ./bootstrap && \
      make -j${NCPUS} && \
      make install && \
      cd ../ && \
      rm -rf cmake; \
    fi

# install dependencies (python3 -m pip)
ARG PIP_INDEX_URL="https://pypi.org/simple"
ENV PIP_INDEX_URL=${PIP_INDEX_URL}
RUN echo PIP_INDEX_URL=${PIP_INDEX_URL}

# upgrade PIP
RUN python3 -m pip install pip==22.2 && \
    ln -s $(which python3.8) /usr/bin/pip3.8

# install dependencies (PIP3)
COPY ./dependencies-py3.* "${REPO_PATH}/"
RUN dt-pip3-install "${REPO_PATH}/dependencies-py3.*"

# install RPi libs
COPY assets/vc.tgz /opt/
ENV PATH=/opt/vc/bin:${PATH}

# copy the source code
COPY ./packages/. "${REPO_PATH}/"

# define healthcheck
RUN echo ND > /health && \
    chmod 777 /health
HEALTHCHECK \
    --interval=5s \
    CMD cat /health && grep -q ^healthy$ /health

# configure catkin to work nicely with docker: https://docs.python.org/3/library/shutil.html#shutil.get_terminal_size
ENV COLUMNS 160

# install launcher scripts
COPY ./launchers/default.sh "${LAUNCH_PATH}/"
RUN dt-install-launchers "${LAUNCH_PATH}"

# define default command
CMD ["bash", "-c", "dt-launcher-${DT_LAUNCHER}"]

# store module metadata
LABEL org.duckietown.label.module.type="${REPO_NAME}" \
    org.duckietown.label.module.description="${DESCRIPTION}" \
    org.duckietown.label.module.icon="${ICON}" \
    org.duckietown.label.platform.os="${TARGETOS}" \
    org.duckietown.label.platform.architecture="${TARGETARCH}" \
    org.duckietown.label.platform.variant="${TARGETVARIANT}" \
    org.duckietown.label.code.location="${REPO_PATH}" \
    org.duckietown.label.code.version.distro="${DISTRO}" \
    org.duckietown.label.base.image="${OS_FAMILY}" \
    org.duckietown.label.base.tag="${OS_DISTRO}" \
    org.duckietown.label.maintainer="${MAINTAINER}"
