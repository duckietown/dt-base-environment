COLCON_SETUP_FPATH=/opt/colcon/install/setup.bash

if [ -f "${COLCON_SETUP_FPATH}" ]; then
    source "${COLCON_SETUP_FPATH}"
else
    echo "WARNING: colcon setup file not found: ${COLCON_SETUP_FPATH}"
fi
