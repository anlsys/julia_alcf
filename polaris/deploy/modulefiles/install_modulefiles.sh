#!/bin/bash

set -e
# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Define all Julia versions to install (keep in sync with ../deploy.sh)
declare -A JULIA_VERSIONS
JULIA_VERSIONS["1.10"]="1.10.11"
JULIA_VERSIONS["1.11"]="1.11.9"
JULIA_VERSIONS["1.12"]="1.12.6"
JULIA_VERSIONS["1.13"]="1.13.0"

if [ -z "$JULIA_DEPOT_PATH" ]; then
    echo "JULIA_DEPOT_PATH is not set. Please set it before running this script."
    exit 1
fi

# Copy modulefiles once for all versions. `dir/.` copies dotfiles such as
# .modulerc.lua too, which `dir/*` would skip.
echo ""
echo "Copying modulefiles to $JULIA_DEPOT_PATH/modulefiles..."
mkdir -p $JULIA_DEPOT_PATH/modulefiles/julia
cp -a $SCRIPT_DIR/julia/. $JULIA_DEPOT_PATH/modulefiles/julia/

# Configure all modulefiles with the depot path
echo "Configuring modulefiles with depot path..."
for JULIA_MINOR in "${!JULIA_VERSIONS[@]}"; do
    sed -i "s|SYSTEM_DEPOT_PATH|$JULIA_DEPOT_PATH|g" $JULIA_DEPOT_PATH/modulefiles/julia/$JULIA_MINOR.lua
done
