#!/bin/bash

set -e
# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Prompt user for Julia depot path
read -p "Enter Julia depot path: " user_depot_path

# Set Julia depot path
export JULIA_DEPOT_PATH=$user_depot_path

echo "Using JULIA_DEPOT_PATH: $JULIA_DEPOT_PATH"

# Create Julia depot directory
mkdir -p $JULIA_DEPOT_PATH

# Download and extract Julia directly into $JULIA_DEPOT_PATH/julia
echo "Downloading and installing Julia to $JULIA_DEPOT_PATH/julia..."
curl -L https://julialang-s3.julialang.org/bin/linux/x64/1.12/julia-1.12.0-linux-x86_64.tar.gz | tar xz -C $JULIA_DEPOT_PATH
mv $JULIA_DEPOT_PATH/julia-1.12.0 $JULIA_DEPOT_PATH/julia
mkdir -p $JULIA_DEPOT_PATH/environments/v1.12
echo "Copying global LocalPreferences.toml to $JULIA_DEPOT_PATH/environments/v1.12/LocalPreferences.toml.."
cp $SCRIPT_DIR/environment/LocalPreferences.toml $JULIA_DEPOT_PATH/environments/v1.12/LocalPreferences.toml
echo "Copying modulefiles to $JULIA_DEPOT_PATH/modulefiles.."
cp -a $SCRIPT_DIR/modulefiles $JULIA_DEPOT_PATH/modulefiles

# Replace USER_DEPOT_PATH in the modulefile with the actual depot path
echo "Configuring modulefile with depot path..."
sed -i "s|USER_DEPOT_PATH|$JULIA_DEPOT_PATH|g" $JULIA_DEPOT_PATH/modulefiles/julia
echo "Configuring environment with depot path..."
sed -i "s|USER_DEPOT|$JULIA_DEPOT_PATH|g" $JULIA_DEPOT_PATH/environments/v1.12/LocalPreferences.toml

# Create symbolic links to system libraries in Julia's lib directory
echo "Creating symbolic links to system libraries..."
ln -sf /usr/lib64/libiga64.so.2 $JULIA_DEPOT_PATH/julia/lib/libiga64.so
ln -sf /usr/lib64/libigc.so.2 $JULIA_DEPOT_PATH/julia/lib/libigc.so
ln -sf /usr/lib64/libigdfcl.so.2 $JULIA_DEPOT_PATH/julia/lib/libigdfcl.so
ln -sf /usr/lib64/intel-opencl/libigdrcl.so $JULIA_DEPOT_PATH/julia/lib/libigdrcl.so
ln -sf /usr/lib64/libopencl-clang.so.15 $JULIA_DEPOT_PATH/julia/lib/libopencl-clang.so
ln -sf /usr/lib64/libopencl-clang.so.15 $JULIA_DEPOT_PATH/julia/lib/libopencl-clang.so.15

echo "Julia installation completed successfully."
echo "Load the Julia module with:"
echo "module use $JULIA_DEPOT_PATH/modulefiles && module load julia"

echo "Add the module to your .bashrc or .zshrc for automatic loading."