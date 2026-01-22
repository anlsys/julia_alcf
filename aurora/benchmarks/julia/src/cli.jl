function parse_commandline()
    s = ArgParseSettings(description="ALCF GPU Benchmarks")
    @add_arg_table! s begin
        "benchmark"
            help = "benchmark to run: flops, gemm"
            required = true
        "--size", "-s"
            help = "matrix size for gemm benchmark (default: 8192)"
            arg_type = Int
            default = 8192
    end
    return parse_args(s)
end

function main(backend_type)
    MPI.Init()
    comm = MPI.COMM_WORLD
    
    # Get backend with device assigned based on MPI rank
    backend = get_backend_for_rank(backend_type, comm)
    
    args = parse_commandline()
    benchmark = args["benchmark"]

    if benchmark == "flops"
        run_flops(backend, comm)
    elseif benchmark == "gemm"
        run_gemm(backend, comm; size=args["size"])
    else
        error("Unknown benchmark: $benchmark. Available: flops, gemm")
    end
    
    MPI.Finalize()
end
