"""
Triad benchmark - measures memory bandwidth using STREAM-like A[i] = 2.0 * B[i] + C[i].

Port of OpenMP triad benchmark from C++ to Julia/KernelAbstractions.
"""

@kernel function triad_kernel!(A, B, C, scalar::T) where T
    i = @index(Global)
    @inbounds A[i] = scalar * B[i] + C[i]
end

function bench_triad(::Type{T}, backend, comm; num_elements::Int=65_536_000, num_iterations::Int=100) where T
    world_size = MPI.Comm_size(comm)
    world_rank = MPI.Comm_rank(comm)

    scalar = T(2.0)

    # Initialize arrays on host with random data
    B_host = rand(T, num_elements)
    C_host = rand(T, num_elements)
    A_host = zeros(T, num_elements)

    # Transfer to device
    A = adapt(backend, A_host)
    B = adapt(backend, B_host)
    C = adapt(backend, C_host)

    # Create kernel instance
    kernel! = triad_kernel!(backend)

    # Manual iteration loop to capture minimum time (like C++)
    min_time = typemax(Float64)
    for _ in 1:num_iterations
        MPI.Barrier(comm)
        l_start = time_ns()
        kernel!(A, B, C, scalar; ndrange=num_elements)
        KernelAbstractions.synchronize(backend)
        l_end = time_ns()

        # Get global start/end times
        start_time = MPI.Reduce(l_start, MPI.MIN, 0, comm)
        end_time = MPI.Reduce(l_end, MPI.MAX, 0, comm)

        if world_rank == 0
            elapsed = (end_time - start_time) * 1e-9  # Convert ns to seconds
            min_time = min(min_time, elapsed)
        end
    end

    # Copy back and verify result
    A_result = Array(A)
    B_result = Array(B)
    C_result = Array(C)
    expected = scalar * B_result[1] + C_result[1]
    @assert isapprox(A_result[1], expected, rtol=0.01) "Result verification failed"

    # Calculate and report bandwidth
    if world_rank == 0
        # 3 memory operations per element: read B, read C, write A
        bytes_transferred = 3 * sizeof(T) * num_elements * world_size
        bandwidth = (bytes_transferred * 1e-9) / min_time
        precision = T == Float32 ? "Single" : "Double"
        println("$precision Precision Memory Bandwidth (triad): $bandwidth GB/s")
    end
end

function run_triad(backend, comm; num_elements::Int=65_536_000, num_iterations::Int=100)
    bench_triad(Float64, backend, comm; num_elements=num_elements, num_iterations=num_iterations)
    bench_triad(Float32, backend, comm; num_elements=num_elements, num_iterations=num_iterations)
end
