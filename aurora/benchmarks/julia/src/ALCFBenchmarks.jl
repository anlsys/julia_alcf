module ALCFBenchmarks

using KernelAbstractions
using MPI
using Adapt
using ArgParse
using BenchmarkTools

include("device.jl")
include("cli.jl")
include("flops.jl")

export main, run_flops, get_backend_for_rank

end
