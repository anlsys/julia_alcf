"""
Peer2Peer benchmark - measures MPI point-to-point bandwidth between GPU buffers.

Port of SYCL/MPI peer2peer benchmark from C++ to Julia/KernelAbstractions.
"""

function datatransfer_p2p(comm, sends, recvs, num_iterations::Int=10)
    world_rank = MPI.Comm_rank(comm)

    min_time = typemax(UInt64)

    for _ in 1:num_iterations
        MPI.Barrier(comm)
        l_start = time_ns()

        requests = MPI.Request[]

        # Issue all sends
        for (dest, buf) in sends
            req = MPI.Isend(buf, comm; dest=dest, tag=0)
            push!(requests, req)
        end

        # Issue all receives
        for (src, buf) in recvs
            req = MPI.Irecv!(buf, comm; source=src, tag=0)
            push!(requests, req)
        end

        MPI.Waitall(requests)
        l_end = time_ns()

        # Get global timing
        start_time = MPI.Reduce(l_start, MPI.MIN, 0, comm)
        end_time = MPI.Reduce(l_end, MPI.MAX, 0, comm)

        if world_rank == 0
            elapsed = end_time - start_time
            min_time = min(min_time, elapsed)
        end
    end

    return min_time
end

function bench_peer2peer(backend, comm; mode::String="Tile2Tile", num_iterations::Int=10)
    world_size = MPI.Comm_size(comm)
    world_rank = MPI.Comm_rank(comm)
    num_pairs = world_size ÷ 2

    if world_size < 2
        if world_rank == 0
            println("Peer2Peer benchmark requires at least 2 MPI ranks")
        end
        return
    end

    # 128 MB Float32 buffer (2^25 elements)
    N = 1 << 25
    N_bytes = N * sizeof(Float32)

    # Allocate GPU buffer and fill with random data
    a_host = rand(Float32, N)
    a_gpu = adapt(backend, a_host)

    # Setup send/recv pairs: even ranks send to odd ranks
    sends = Tuple{Int,typeof(a_gpu)}[]
    recvs = Tuple{Int,typeof(a_gpu)}[]

    if world_rank % 2 == 0
        push!(sends, (world_rank + 1, a_gpu))
    else
        push!(recvs, (world_rank - 1, a_gpu))
    end

    # Unidirectional bandwidth test
    uni_time = datatransfer_p2p(comm, sends, recvs, num_iterations)
    if world_rank == 0
        uni_bw = (N_bytes * num_pairs) / uni_time  # GB/s (time in ns, bytes/ns = GB/s)
        println("$mode Unidirectional Bandwidth: $uni_bw GB/s")
        add_result!("MPI P2P $mode Unidirectional", uni_bw, "GB/s")
    end

    # Add bidirectional transfers
    if world_rank % 2 == 0
        push!(recvs, (world_rank + 1, a_gpu))
    else
        push!(sends, (world_rank - 1, a_gpu))
    end

    # Bidirectional bandwidth test
    bi_time = datatransfer_p2p(comm, sends, recvs, num_iterations)
    if world_rank == 0
        bi_bw = (2 * N_bytes * num_pairs) / bi_time  # GB/s
        println("$mode Bidirectional Bandwidth: $bi_bw GB/s")
        add_result!("MPI P2P $mode Bidirectional", bi_bw, "GB/s")
    end
end

function run_peer2peer(backend, comm; mode::String="Tile2Tile")
    bench_peer2peer(backend, comm; mode=mode)
end
