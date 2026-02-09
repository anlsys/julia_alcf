function parse_commandline()
    s = ArgParseSettings(description="ALCF GPU Benchmarks")
    @add_arg_table! s begin
        "benchmark"
            help = "benchmark to run: flops, gemm, triad, peer2peer, pci, intranode, topology, all"
            required = true
        "--size", "-s"
            help = "matrix size for gemm benchmark (default: 8192)"
            arg_type = Int
            default = 8192
        "--elements", "-n"
            help = "number of elements for triad/pci benchmarks"
            arg_type = Int
            default = 65_536_000
        "--iterations", "-i"
            help = "number of iterations for triad benchmark"
            arg_type = Int
            default = 100
        "--mode", "-m"
            help = "mode for peer2peer: Tile2Tile, Node2Node"
            arg_type = String
            default = "Tile2Tile"
        "--output", "-o"
            help = "output file for markdown report (e.g., aurora.md)"
            arg_type = String
            default = ""
        "--system", "-S"
            help = "system name for report title (defaults to hostname)"
            arg_type = String
            default = ""
        "--skip-peer2peer"
            help = "skip MPI peer2peer benchmark (use if GPU-aware MPI causes crashes)"
            action = :store_true
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
    elseif benchmark == "triad"
        run_triad(backend, comm; num_elements=args["elements"], num_iterations=args["iterations"])
    elseif benchmark == "peer2peer"
        run_peer2peer(backend, comm; mode=args["mode"])
    elseif benchmark == "pci"
        run_pci(backend, comm; num_elements=args["elements"])
    elseif benchmark == "intranode"
        run_intranode(backend, comm)
    elseif benchmark == "topology"
        run_topology(backend, comm)
    elseif benchmark == "all"
        run_all(backend, comm;
                output=args["output"],
                system_name=args["system"],
                gemm_size=args["size"],
                skip_peer2peer=args["skip-peer2peer"])
    else
        error("Unknown benchmark: $benchmark. Available: flops, gemm, triad, peer2peer, pci, intranode, topology, all")
    end

    MPI.Finalize()
end
