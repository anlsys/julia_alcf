"""
Intranode benchmark - measures GPU-to-GPU bandwidth within a node using peer access.

Port of SYCL intranode P2P benchmark from C++ to Julia using KernelAbstractions APIs.

Uses KA.ndevices(), KA.device!(), adapt(), and copyto!() for portable GPU P2P transfers.
"""

using Adapt: adapt

function run_intranode(backend, comm)
    world_rank = MPI.Comm_rank(comm)

    if world_rank != 0
        return
    end

    ndev = KA.ndevices(backend)
    if ndev < 2
        println("Need at least 2 GPUs for P2P test. Found: $ndev")
        return
    end

    println("Detected $ndev GPUs")

    N = 1 << 22  # 4M floats = 16MB
    REPEAT = 100

    # Allocate source buffer on device 0
    KA.device!(backend, 1)
    src_host = rand(Float32, N)
    src = adapt(backend, src_host)

    println(".......{WRITE} GPU 0 to GPU <*>.......")
    for peer_idx in 2:ndev
        # Allocate destination on peer device
        KA.device!(backend, peer_idx)
        dst = adapt(backend, zeros(Float32, N))

        # Warmup
        copyto!(dst, src)
        KA.synchronize(backend)

        # Timed copy loop
        start = time_ns()
        for _ in 1:REPEAT
            copyto!(dst, src)
        end
        KA.synchronize(backend)
        elapsed = (time_ns() - start) * 1e-9

        total_bytes = Float64(REPEAT) * N * sizeof(Float32)
        bw_gbps = total_bytes / elapsed / 1e9
        println("GPU 0 -> GPU $(peer_idx-1): Bandwidth = $(round(bw_gbps, digits=2)) GB/s")
    end

    println(".......{READ} GPU<*> to GPU 0.......")
    for peer_idx in 2:ndev
        # Allocate source on peer device
        KA.device!(backend, peer_idx)
        peer_src = adapt(backend, rand(Float32, N))

        # Destination on device 0
        KA.device!(backend, 1)
        dst = adapt(backend, zeros(Float32, N))

        # Warmup
        copyto!(dst, peer_src)
        KA.synchronize(backend)

        # Timed copy loop
        start = time_ns()
        for _ in 1:REPEAT
            copyto!(dst, peer_src)
        end
        KA.synchronize(backend)
        elapsed = (time_ns() - start) * 1e-9

        total_bytes = Float64(REPEAT) * N * sizeof(Float32)
        bw_gbps = total_bytes / elapsed / 1e9
        println("GPU $(peer_idx-1) -> GPU 0: Bandwidth = $(round(bw_gbps, digits=2)) GB/s")
    end
end
