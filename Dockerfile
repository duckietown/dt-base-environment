# parameters
ARG ARCH=arm32v7
ARG ROS_DISTRO=kinetic
ARG OS_FAMILY=ubuntu
ARG OS_DISTRO=xenial
ARG DISTRO=daffy
ARG LAUNCHER=default
# ---
ARG REPO_NAME="dt-base-environment"
ARG MAINTAINER="Andrea F. Daniele (afdaniele@ttic.edu)"
ARG DESCRIPTION="Base image of any Duckietown software module. Based on ${OS_FAMILY}:${OS_DISTRO}."
ARG ICON="square"

# base image
FROM ${ARCH}/${OS_FAMILY}:${OS_DISTRO}

# recall all arguments
ARG ARCH
ARG OS_FAMILY
ARG OS_DISTRO
ARG ROS_DISTRO
ARG DISTRO
ARG LAUNCHER
ARG REPO_NAME
ARG DESCRIPTION
ARG MAINTAINER
ARG ICON

# setup environment
ENV INITSYSTEM off
ENV QEMU_EXECVE 1
ENV TERM xterm
ENV LANG C.UTF-8
ENV LC_ALL C.UTF-8
ENV READTHEDOCS True
ENV PYTHONIOENCODING UTF-8
ENV DISABLE_CONTRACTS 1
ENV DEBIAN_FRONTEND noninteractive

# keep some arguments as environment variables
ENV OS_FAMILY "${OS_FAMILY}"
ENV OS_DISTRO "${OS_DISTRO}"
ENV ROS_DISTRO "${ROS_DISTRO}"
ENV DT_MODULE_TYPE "${REPO_NAME}"
ENV DT_MODULE_DESCRIPTION "${DESCRIPTION}"
ENV DT_MODULE_ICON "${ICON}"
ENV DT_MAINTAINER "${MAINTAINER}"
ENV DT_LAUNCHER "${LAUNCHER}"

# duckietown-specific settings
ENV DUCKIEFLEET_ROOT "/data/config"

# code environment
ENV SOURCE_DIR /code
ENV LAUNCH_DIR /launch
WORKDIR "${SOURCE_DIR}"

# copy QEMU
COPY ./assets/qemu/${ARCH}/ /usr/bin/

# copy binaries
COPY ./assets/bin/. /usr/local/bin/

# define and create repository paths
ARG REPO_PATH="${SOURCE_DIR}/${REPO_NAME}"
ARG LAUNCH_PATH="${LAUNCH_DIR}/${REPO_NAME}"
RUN mkdir -p "${REPO_PATH}"
RUN mkdir -p "${LAUNCH_PATH}"
ENV DT_REPO_PATH "${REPO_PATH}"
ENV DT_LAUNCH_PATH "${LAUNCH_PATH}"

# setup ROS sources
RUN apt-key adv \
    --keyserver hkp://keyserver.ubuntu.com:80 \
    --recv-keys C1CF6E31E6BADE8868B172B4F42ED6FBAB17C654
RUN echo "deb http://packages.ros.org/ros/ubuntu ${OS_DISTRO} main" >> /etc/apt/sources.list

# add python3.7 sources to APT
#TODO: this can go once we move to Focal
RUN echo "deb http://ppa.launchpad.net/deadsnakes/ppa/ubuntu ${OS_DISTRO} main" >> /etc/apt/sources.list
RUN echo "deb-src http://ppa.launchpad.net/deadsnakes/ppa/ubuntu ${OS_DISTRO} main" >> /etc/apt/sources.list
RUN gpg --keyserver keyserver.ubuntu.com --recv 6A755776 \
 && gpg --export --armor 6A755776 | apt-key add -

# install dependencies (APT)
COPY ./dependencies-apt.txt "${REPO_PATH}/"
RUN dt-apt-install "${REPO_PATH}/dependencies-apt.txt"

# upgrade PIP
RUN pip install -U pip

# install dependencies (PIP)
COPY ./dependencies-py.txt "${REPO_PATH}/"
RUN pip install -r "${REPO_PATH}/dependencies-py.txt"

# update alternatives for python, python3
#TODO: this can go once we move to Focal
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.7 1

# install pip3
#TODO: this can go once we move to Focal
RUN cd /tmp \
  && wget --no-check-certificate http://bootstrap.pypa.io/get-pip.py \
  && python3 ./get-pip.py \
  && rm ./get-pip.py
# remove the newly installed binary pip shadowing the Python2 pip
RUN rm /usr/local/bin/pip

# install dependencies (PIP3)
COPY ./dependencies-py3.txt "${REPO_PATH}/"
RUN pip3 install -r "${REPO_PATH}/dependencies-py3.txt"

# install RPi libs
ADD assets/vc.tgz /opt/
COPY assets/00-vmcs.conf /etc/ld.so.conf.d
RUN ldconfig
ENV PATH=/opt/vc/bin:${PATH}

# copy the source code
COPY ./packages/. "${REPO_PATH}/"

# define healthcheck
RUN echo ND > /health
RUN chmod 777 /health
HEALTHCHECK \
    --interval=5s \
    CMD cat /health && grep -q ^healthy$ /health

# configure catkin to work nicely with docker
RUN sed \
  -i \
  's/__default_terminal_width = 80/__default_terminal_width = 160/' \
  /usr/lib/python2.7/dist-packages/catkin_tools/common.py

# install launcher scripts
COPY ./launchers/default.sh "${LAUNCH_PATH}/"
RUN dt-install-launchers "${LAUNCH_PATH}"

# define default command
CMD ["bash", "-c", "dt-launcher-${DT_LAUNCHER}"]

# store module metadata
LABEL org.duckietown.label.module.type="${REPO_NAME}" \
    org.duckietown.label.module.description="${DESCRIPTION}" \
    org.duckietown.label.module.icon="${ICON}" \
    org.duckietown.label.architecture="${ARCH}" \
    org.duckietown.label.code.location="${REPO_PATH}" \
    org.duckietown.label.code.version.distro="${DISTRO}" \
    org.duckietown.label.base.image="${OS_FAMILY}" \
    org.duckietown.label.base.tag="${OS_DISTRO}" \
    org.duckietown.label.maintainer="${MAINTAINER}"
