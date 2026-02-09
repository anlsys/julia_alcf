"""
PCI benchmark - measures PCIe bandwidth between host and device.

Port of SYCL PCI benchmark from C++ to Julia/KernelAbstractions.
Note: Uses copyto! which may not achieve peak bandwidth without pinned memory.
"""

function datatransfer_pci(backend, comm, transfers, num_iterations::Int=10)
    world_rank = MPI.Comm_rank(comm)

    min_time = typemax(UInt64)

    for _ in 1:num_iterations
        MPI.Barrier(comm)
        l_start = time_ns()

        # Execute all transfers
        for (dest, src) in transfers
            copyto!(dest, src)
        end
        KernelAbstractions.synchronize(backend)

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

function bench_pci(backend, comm; num_elements::Int=(1 << 28), num_iterations::Int=10)
    world_size = MPI.Comm_size(comm)
    world_rank = MPI.Comm_rank(comm)

    N_bytes = num_elements * sizeof(Int32)

    # Allocate host arrays
    a_cpu = rand(Int32, num_elements)
    b_cpu = rand(Int32, num_elements)

    # Allocate device arrays
    a_gpu = adapt(backend, rand(Int32, num_elements))
    b_gpu = adapt(backend, rand(Int32, num_elements))

    # Host-to-Device bandwidth
    H2D_time = datatransfer_pci(backend, comm, [(a_gpu, a_cpu)], num_iterations)
    if world_rank == 0
        H2D_bw = (N_bytes * world_size) / H2D_time  # GB/s (time in ns)
        println("PCIe Unidirectional Bandwidth (H2D): $H2D_bw GB/s")
        add_result!("PCIe H2D Bandwidth", H2D_bw, "GB/s")
    end

    # Device-to-Host bandwidth
    D2H_time = datatransfer_pci(backend, comm, [(a_cpu, a_gpu)], num_iterations)
    if world_rank == 0
        D2H_bw = (N_bytes * world_size) / D2H_time  # GB/s
        println("PCIe Unidirectional Bandwidth (D2H): $D2H_bw GB/s")
        add_result!("PCIe D2H Bandwidth", D2H_bw, "GB/s")
    end

    # Bidirectional bandwidth (H2D and D2H simultaneously)
    bidir_time = datatransfer_pci(backend, comm, [(a_gpu, a_cpu), (b_cpu, b_gpu)], num_iterations)
    if world_rank == 0
        bidir_bw = (2 * N_bytes * world_size) / bidir_time  # GB/s
        println("PCIe Bidirectional Bandwidth: $bidir_bw GB/s")
        add_result!("PCIe Bidirectional Bandwidth", bidir_bw, "GB/s")
    end
end

function run_pci(backend, comm; num_elements::Int=(1 << 28), num_iterations::Int=10)
    bench_pci(backend, comm; num_elements=num_elements, num_iterations=num_iterations)
end
