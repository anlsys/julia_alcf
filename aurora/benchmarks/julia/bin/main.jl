#!/usr/bin/env julia

# ALCF GPU Benchmarks - Entry Point
#
# Usage:
#   mpirun -n 12 julia --project bin/main.jl flops
#
# To use a different backend, change the `using` statement and backend_type below.
# Examples:
#   - oneAPI (Aurora): using oneAPI; backend_type = oneAPIBackend
#   - CUDA (NVIDIA):   using CUDA; backend_type = CUDABackend
#   - AMDGPU (AMD):    using AMDGPU; backend_type = ROCBackend

using ALCFBenchmarks

# Select your backend here (type, not instance)
using CUDA
backend_type = CUDABackend

# Alternative backends (uncomment as needed):
# using oneAPI; backend_type = oneAPIBackend
# using AMDGPU; backend_type = ROCBackend

ALCFBenchmarks.main(backend_type)
