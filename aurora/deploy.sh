#!/bin/bash

set -e
# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Define all Julia versions to install
declare -A JULIA_VERSIONS
JULIA_VERSIONS["1.10"]="1.10.11"
JULIA_VERSIONS["1.11"]="1.11.9"
JULIA_VERSIONS["1.12"]="1.12.6"
JULIA_VERSIONS["1.13"]="1.13.0"

# Prompt user for Julia depot path only if not already set
export JULIA_DEPOT_PATH=/soft/libraries/julia

echo "Using JULIA_DEPOT_PATH: $JULIA_DEPOT_PATH"

# Track whichever mpich module is loaded at deploy time instead of hard-coding a release
# path that goes stale when Aurora rolls to a new /opt/aurora tree. MPI_ROOT is set by the
# mpich modulefile; check it before anything is removed below.
if [ ! -f "$MPI_ROOT/lib/libmpi.so" ]; then
    echo "ERROR: \$MPI_ROOT does not point at an mpich install ('$MPI_ROOT')." >&2
    echo "       Load the mpich module before running this script." >&2
    exit 1
fi
echo "Using MPI: $MPI_ROOT"

# Same story for HDF5: point HDF5.jl at the system parallel build rather than its own
# artifact, which is serial. HDF5_ROOT is set by the hdf5 modulefile, and because those
# modulefiles live under the mpich hierarchy, `module load hdf5` resolves to the build
# matching the mpich checked above. Verify it is actually a parallel build before using it.
if [ ! -f "$HDF5_ROOT/lib/libhdf5.so" ] || [ ! -f "$HDF5_ROOT/lib/libhdf5_hl.so" ]; then
    echo "ERROR: \$HDF5_ROOT does not point at an HDF5 install ('$HDF5_ROOT')." >&2
    echo "       Run 'module load hdf5' before running this script." >&2
    exit 1
fi
if ! strings "$HDF5_ROOT/lib/libhdf5.so" | grep -q "Parallel HDF5: ON"; then
    echo "ERROR: '$HDF5_ROOT' is a serial HDF5 build." >&2
    echo "       Load the hdf5 module from the mpich hierarchy (not hdf5/*-serial)." >&2
    exit 1
fi
echo "Using HDF5: $HDF5_ROOT"

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
    sed -i "s|USER_DEPOT|$JULIA_DEPOT_PATH/julia_binaries/julia-$JULIA_MINOR|g" $JULIA_DEPOT_PATH/environments/v$JULIA_MINOR/LocalPreferences.toml
    sed -i "s|MPI_LIBMPI|$MPI_ROOT/lib/libmpi|g" $JULIA_DEPOT_PATH/environments/v$JULIA_MINOR/LocalPreferences.toml
    sed -i "s|HDF5_LIBDIR|$HDF5_ROOT/lib|g" $JULIA_DEPOT_PATH/environments/v$JULIA_MINOR/LocalPreferences.toml

    # Create symbolic links to system libraries in Julia's lib directory
    echo "Creating symbolic links to system libraries..."
    ln -sf /usr/lib64/libiga64.so.2 $JULIA_DEPOT_PATH/julia_binaries/julia-$JULIA_MINOR/lib/libiga64.so
    ln -sf /usr/lib64/libigc.so.2 $JULIA_DEPOT_PATH/julia_binaries/julia-$JULIA_MINOR/lib/libigc.so
    ln -sf /usr/lib64/libigdfcl.so.2 $JULIA_DEPOT_PATH/julia_binaries/julia-$JULIA_MINOR/lib/libigdfcl.so
    ln -sf /usr/lib64/intel-opencl/libigdrcl.so $JULIA_DEPOT_PATH/julia_binaries/julia-$JULIA_MINOR/lib/libigdrcl.so
    ln -sf /usr/lib64/libopencl-clang.so.15 $JULIA_DEPOT_PATH/julia_binaries/julia-$JULIA_MINOR/lib/libopencl-clang.so
    ln -sf /usr/lib64/libopencl-clang.so.15 $JULIA_DEPOT_PATH/julia_binaries/julia-$JULIA_MINOR/lib/libopencl-clang.so.15

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
