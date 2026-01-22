module ALCFBenchmarks

using KernelAbstractions
using MPI
using Adapt
using ArgParse
using BenchmarkTools
using GPUArraysCore

include("device.jl")
include("cli.jl")
include("flops.jl")
include("gemm.jl")

export main, run_flops, run_gemm, get_backend_for_rank

end
