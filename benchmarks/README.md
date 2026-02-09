# ALCFBenchmarks.jl

GPU benchmarks for ALCF supercomputers using Julia and KernelAbstractions.jl for portable GPU programming.

## Overview

ALCFBenchmarks.jl provides a suite of GPU benchmarks that work across multiple GPU backends (CUDA, oneAPI, AMDGPU) using the KernelAbstractions.jl abstraction layer. The benchmarks are designed to measure key performance metrics on HPC systems.

These benchmarks are Julia ports of the C++ micro-benchmarks from the [ALCF Aurora Node Performance Documentation](https://docs.alcf.anl.gov/aurora/node-performance-overview/node-performance-overview/#micro-benchmarks).

## Available Benchmarks

| Benchmark | Description | Metrics |
|-----------|-------------|---------|
| `flops` | Peak floating-point performance using multiply-add operations | GFlop/s |
| `gemm` | Matrix multiplication via BLAS (cuBLAS, oneMKL, rocBLAS) | GFlop/s |
| `triad` | STREAM-like memory bandwidth: `A[i] = 2*B[i] + C[i]` | GB/s |
| `peer2peer` | MPI point-to-point bandwidth between GPU buffers | GB/s |
| `pci` | PCIe host-to-device and device-to-host bandwidth | GB/s |
| `intranode` | GPU-to-GPU P2P bandwidth (stub - requires backend-specific APIs) | - |
| `topology` | GPU topology and P2P connectivity discovery | Device info, P2P matrix |

## Installation

```bash
cd aurora/benchmarks/julia
julia --project -e 'using Pkg; Pkg.instantiate()'
```

For CUDA systems, add CUDA.jl:
```bash
julia --project -e 'using Pkg; Pkg.add("CUDA")'
```

For Intel GPUs (Aurora), add oneAPI.jl:
```bash
julia --project -e 'using Pkg; Pkg.add("oneAPI")'
```

## Usage

### Basic Usage

```bash
# Run with MPI (recommended for multi-GPU)
mpirun -n 12 julia --project bin/main.jl <benchmark> [options]

# Single rank
julia --project bin/main.jl <benchmark> [options]
```

### Examples

```bash
# Peak FLOPS (single and double precision)
mpirun -n 12 julia --project bin/main.jl flops

# GEMM with custom matrix size
mpirun -n 12 julia --project bin/main.jl gemm --size 16384

# Memory bandwidth (triad)
mpirun -n 12 julia --project bin/main.jl triad

# Triad with custom parameters
mpirun -n 12 julia --project bin/main.jl triad --elements 100000000 --iterations 50

# MPI peer-to-peer bandwidth
mpirun -n 12 julia --project bin/main.jl peer2peer --mode Tile2Tile

# PCIe bandwidth
mpirun -n 12 julia --project bin/main.jl pci

# GPU topology discovery
julia --project bin/main.jl topology
```

### CLI Options

| Option | Short | Description | Default |
|--------|-------|-------------|---------|
| `--size` | `-s` | Matrix size for GEMM benchmark | 8192 |
| `--elements` | `-n` | Number of elements for triad/pci | 65,536,000 |
| `--iterations` | `-i` | Number of iterations for triad | 100 |
| `--mode` | `-m` | Mode for peer2peer: `Tile2Tile` or `Node2Node` | Tile2Tile |

## Backend Configuration

Edit `bin/main.jl` to select your GPU backend:

```julia
# CUDA (NVIDIA GPUs)
using CUDA
backend_type = CUDABackend

# oneAPI (Intel GPUs)
using oneAPI
backend_type = oneAPIBackend

# AMDGPU (AMD GPUs)
using AMDGPU
backend_type = ROCBackend
```

## Benchmark Details

### flops
Measures peak floating-point throughput using a multiply-add kernel with 4096 FLOPs per work item. Tests both single (Float32) and double (Float64) precision.

### gemm
Matrix multiplication benchmark using `LinearAlgebra.mul!` which dispatches to the appropriate BLAS library (cuBLAS, oneMKL, rocBLAS). Tests Float64, Float32, and Float16 precision.

### triad
STREAM-like benchmark measuring memory bandwidth with the operation `A[i] = scalar * B[i] + C[i]`. Reports aggregate bandwidth across all MPI ranks.

### peer2peer
MPI point-to-point bandwidth test using GPU buffers with `MPI.Isend`/`MPI.Irecv!`. Pairs even/odd ranks for unidirectional and bidirectional bandwidth measurements. Requires GPU-aware MPI.

### pci
PCIe bandwidth benchmark measuring:
- Host-to-Device (H2D) transfer rate
- Device-to-Host (D2H) transfer rate
- Bidirectional (simultaneous H2D + D2H) transfer rate

### intranode (stub)
GPU-to-GPU peer access bandwidth. Not implemented in Julia because KernelAbstractions does not provide peer access APIs (`can_access_peer`, `enable_peer_access`). Use the C++ binary `mpi_sycl_intranode_bw` instead.

### topology
GPU topology discovery with P2P connectivity information. Provides a portable abstraction over backend-specific APIs:
- **CUDA**: Uses `CUDA.can_access_peer()` and `CUDA.p2p_attribute()` for P2P connectivity, device UUIDs, and PCI addresses
- **oneAPI**: Uses Level Zero experimental fabric vertex/edge APIs (`zeFabricVertexGetExp`, `zeFabricEdgeGetExp`) for device and connectivity discovery

Outputs:
- Device list with names, UUIDs, and PCI addresses
- P2P connectivity matrix showing which GPU pairs can communicate directly
- Performance ranks (if available) indicating link quality (e.g., NVLink vs PCIe)
- Bandwidth/latency information (oneAPI only, via fabric edge properties)

## Architecture

```
aurora/benchmarks/julia/
├── bin/
│   └── main.jl          # Entry point - backend selection
├── src/
│   ├── ALCFBenchmarks.jl # Main module
│   ├── cli.jl           # Command-line interface
│   ├── device.jl        # MPI rank to GPU mapping
│   ├── flops.jl         # Peak FLOPS benchmark
│   ├── gemm.jl          # Matrix multiplication benchmark
│   ├── triad.jl         # Memory bandwidth benchmark
│   ├── peer2peer.jl     # MPI P2P bandwidth benchmark
│   ├── pci.jl           # PCIe bandwidth benchmark
│   ├── intranode.jl     # GPU P2P benchmark (stub)
│   └── topology.jl      # GPU topology discovery
├── Project.toml
└── README.md
```

## Requirements

- Julia 1.10+
- MPI implementation (MPICH, OpenMPI)
- GPU backend package (CUDA.jl, oneAPI.jl, or AMDGPU.jl)
- For peer2peer: GPU-aware MPI

## Notes

- Device assignment is round-robin based on MPI rank
- Timing uses `MPI.Reduce` to get global min start / max end times
- Results are reported only on rank 0
- The `peer2peer` benchmark requires GPU-aware MPI; crashes may indicate MPI configuration issues rather than code bugs
