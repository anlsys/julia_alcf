#!/bin/bash

set -e
# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Define all Julia versions to install
declare -A JULIA_VERSIONS
JULIA_VERSIONS["1.10"]="1.10.10"
JULIA_VERSIONS["1.11"]="1.11.7"
JULIA_VERSIONS["1.12"]="1.12.2"

# Prompt user for Julia depot path only if not already set
export JULIA_DEPOT_PATH=/soft/applications/julia

echo "Using JULIA_DEPOT_PATH: $JULIA_DEPOT_PATH"

# Create Julia depot directory
rm -rf $JULIA_DEPOT_PATH/*
mkdir -p $JULIA_DEPOT_PATH
mkdir -p $JULIA_DEPOT_PATH/julia_binaries

# Install all Julia versions
for JULIA_MINOR in "${!JULIA_VERSIONS[@]}"; do
    JULIA_VERSION="${JULIA_VERSIONS[$JULIA_MINOR]}"

    echo ""
    echo "========================================="
    echo "Installing Julia $JULIA_VERSION..."
    echo "========================================="

    # Download and extract Julia
    echo "Downloading Julia $JULIA_VERSION..."
    curl -L https://julialang-s3.julialang.org/bin/linux/x64/$JULIA_MINOR/julia-$JULIA_VERSION-linux-x86_64.tar.gz | tar xz -C $JULIA_DEPOT_PATH

    # Remove existing julia-$JULIA_MINOR directory if it exists
    if [ -d "$JULIA_DEPOT_PATH/julia-$JULIA_MINOR" ]; then
        echo "Removing existing julia-$JULIA_MINOR directory..."
        rm -rf "$JULIA_DEPOT_PATH/julia-$JULIA_MINOR"
    fi

    mv $JULIA_DEPOT_PATH/julia-$JULIA_VERSION $JULIA_DEPOT_PATH/julia_binaries/julia-$JULIA_MINOR

    # Set up environment directory
    mkdir -p $JULIA_DEPOT_PATH/environments/v$JULIA_MINOR
    echo "Copying global LocalPreferences.toml to $JULIA_DEPOT_PATH/environments/v$JULIA_MINOR/LocalPreferences.toml..."
    cp $SCRIPT_DIR/environment/LocalPreferences.toml $JULIA_DEPOT_PATH/environments/v$JULIA_MINOR/LocalPreferences.toml
    echo "Copying global Project.toml to $JULIA_DEPOT_PATH/environments/v$JULIA_MINOR/Project.toml..."
    cp $SCRIPT_DIR/environment/Project.toml $JULIA_DEPOT_PATH/environments/v$JULIA_MINOR/Project.toml

    # Configure environment with depot path
    echo "Configuring environment with depot path..."
    sed -i "s|USER_DEPOT|$JULIA_DEPOT_PATH|g" $JULIA_DEPOT_PATH/environments/v$JULIA_MINOR/LocalPreferences.toml

    echo "Julia $JULIA_VERSION installed successfully."
done

# Copy modulefiles once for all versions
echo ""
echo "Copying modulefiles to $JULIA_DEPOT_PATH/modulefiles..."
mkdir -p $JULIA_DEPOT_PATH/modulefiles
cp -a $SCRIPT_DIR/modulefiles/. $JULIA_DEPOT_PATH/modulefiles/

# Configure all modulefiles with the depot path
echo "Configuring modulefiles with depot path..."
for JULIA_MINOR in "${!JULIA_VERSIONS[@]}"; do
    sed -i "s|SYSTEM_DEPOT_PATH|$JULIA_DEPOT_PATH|g" $JULIA_DEPOT_PATH/modulefiles/julia/$JULIA_MINOR.lua
done

echo ""
echo "========================================="
echo "Julia installation completed successfully."
echo "========================================="
echo "Installed versions:"
for JULIA_MINOR in "${!JULIA_VERSIONS[@]}"; do
    echo "  - Julia ${JULIA_VERSIONS[$JULIA_MINOR]} (module: julia/$JULIA_MINOR)"
done
echo "Julia installation completed successfully."
echo "Load the Julia module with:"
echo "module use $JULIA_DEPOT_PATH/modulefiles && module load julia"

echo "Add the module to your .bashrc or .zshrc for automatic loading."
