"""
FLOPS benchmark - measures peak floating-point performance using multiply-add operations.

Port of clpeak-style benchmark from C++/OpenMP to Julia/KernelAbstractions.
"""

@kernel function flops_kernel!(A, y0::T) where T
    i = @index(Global)
    x = A[i]
    y = y0
    # 128 iterations of MAD_16 = 128 * 16 * 2 = 4096 flops per work item
    for _ in 1:128
        # MAD_16: 16 multiply-add operations (32 flops)
        # Unrolled MAD_4 x 4
        for _ in 1:4
            x = y * x + y
            y = x * y + x
            x = y * x + y
            y = x * y + x
        end
    end
    A[i] = y
end

function bench_flops(::Type{T}, backend, comm) where T
    world_size = MPI.Comm_size(comm)
    world_rank = MPI.Comm_rank(comm)

    # Split global work items across ranks
    total_global_wi = 20_000_000
    local_wi = total_global_wi ÷ world_size

    x0 = T(1.1)
    y0 = -x0

    # Allocate and transfer to device (each rank only allocates its share)
    A_host = fill(x0, local_wi)
    A = adapt(backend, A_host)

    # Create kernel instance
    kernel! = flops_kernel!(backend)

    # Benchmark the kernel using BenchmarkTools
    # @belapsed returns minimum time, handles warmup automatically
    MPI.Barrier(comm)
    local_time = @belapsed begin
        $kernel!($A, $y0; ndrange=$local_wi)
        KernelAbstractions.synchronize($backend)
    end

    # Get max time across all ranks (wall-clock time for parallel execution)
    max_time = MPI.Reduce(local_time, MPI.MAX, 0, comm)

    # Copy back and verify result is finite
    A_result = Array(A)
    @assert isfinite(A_result[1]) "Result is not finite"

    # Calculate and report GFLOP/s
    work_per_wi = 128 * 16 * 2  # flops per work item
    if world_rank == 0
        gflops = (work_per_wi * local_wi * world_size * 1e-9) / max_time
        precision = T == Float32 ? "Single" : "Double"
        println("$precision Precision Peak Flops: $gflops GFlop/s")
    end
end

function run_flops(backend, comm)
    bench_flops(Float32, backend, comm)
    bench_flops(Float64, backend, comm)
end
