module ALCFBenchmarks

using KernelAbstractions
using MPI
using Adapt
using ArgParse
using BenchmarkTools
using GPUArraysCore

import KernelAbstractions as KA

include("device.jl")
include("report.jl")  # Must be before benchmarks so add_result! is available
include("cli.jl")
include("flops.jl")
include("gemm.jl")
include("triad.jl")
include("peer2peer.jl")
include("pci.jl")
include("intranode.jl")
include("topology.jl")

export main, run_flops, run_gemm, get_backend_for_rank
export run_triad, run_peer2peer, run_pci, run_intranode, run_topology
export run_all, generate_markdown, ReportData, BenchmarkResult, get_backend_versioninfo
export DeviceInfo, P2PInfo, discover_topology

end
