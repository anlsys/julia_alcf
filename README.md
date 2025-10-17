# Julia Environment Setup for Polaris and Aurora at ALCF

This repository contains scripts and module files to set up a Julia programming environment on the Polaris and Aurora supercomputers at the Argonne Leadership Computing Facility (ALCF). The setup includes configuration for Julia's depot path, module files for easy loading of the Julia environment, and necessary dependencies.

## Quick Start

1. Clone this repository to your local machine or directly on the ALCF system.
```
git clone https://github.com/anlsys/julia_alcf.git
```
2. Navigate to the appropriate directory for your system (e.g., `aurora/`).
```cd julia_alcf/aurora
```
3. Run the setup script to configure your environment.
```bash
source setup.sh
```
You will be prompted for your [Julia depot path](https://docs.julialang.org/en/v1/manual/environment-variables/#JULIA_DEPOT_PATH). This is where Julia stores all installed packages, precompiled files, and environments. The script will download the Julia executable, set up the depot path, and copy necessary configuration files.

**Important:** Ensure that the depot path you provide is a fast system storage space for Julia packages and environments (e.g., `/lus/flare/projects/Julia/mschanen/julia_depot`).

4. Load the Julia module to use Julia in your sessions.
```bash
module use $JULIA_DEPOT_PATH/modulefiles
module load julia
```