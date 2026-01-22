function parse_commandline()
    s = ArgParseSettings(description="ALCF GPU Benchmarks")
    @add_arg_table! s begin
        "benchmark"
            help = "benchmark to run: flops"
            required = true
    end
    return parse_args(s)
end

function main(backend_type)
    MPI.Init()
    comm = MPI.COMM_WORLD
    
    # Get backend with device assigned based on MPI rank
    backend = get_backend_for_rank(backend_type, comm)
    
    args = parse_commandline()
    if args["benchmark"] == "flops"
        run_flops(backend, comm)
    else
        error("Unknown benchmark: $(args["benchmark"])")
    end
    
    MPI.Finalize()
end
