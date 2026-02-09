"""
GEMM benchmark - measures matrix multiplication performance.

Port of oneMKL GEMM benchmark from C++/SYCL to Julia using LinearAlgebra.mul!
which dispatches to cuBLAS, oneMKL, rocBLAS, etc. based on array type.
"""

using LinearAlgebra

function bench_gemm(::Type{T}, backend, comm; size::Int=8192) where T
    world_size = MPI.Comm_size(comm)
    world_rank = MPI.Comm_rank(comm)

    # Initialize random matrices on host
    # Scale values to avoid overflow, especially for lower precision types
    max_val = min(sqrt(typemax(T) / size), T(100))
    A_host = rand(T, size, size) .* max_val
    B_host = rand(T, size, size) .* max_val
    C_host = zeros(T, size, size)

    # Transfer to device
    A = adapt(backend, A_host)
    B = adapt(backend, B_host)
    C = adapt(backend, C_host)
    
    # Benchmark GEMM using LinearAlgebra.mul!
    # This dispatches to the appropriate BLAS library (cuBLAS, oneMKL, rocBLAS)
    MPI.Barrier(comm)
    local_time = @belapsed begin
        mul!($C, $A, $B)
        KernelAbstractions.synchronize($backend)
    end

    # Get max time across all ranks
    max_time = MPI.Reduce(local_time, MPI.MAX, 0, comm)

    # GEMM FLOPS: 2 * N^3 (N multiplications + N additions per element, N^2 elements)
    if world_rank == 0
        flops_per_gemm = 2.0 * size^3
        gflops = (flops_per_gemm * world_size * 1e-9) / max_time

        precision_name = if T == Float64
            "DGEMM"
        elseif T == Float32
            "SGEMM"
        elseif T == Float16
            "HGEMM"
        else
            "$(T)GEMM"
        end

        println("$precision_name: $gflops GFlop/s (time: $(max_time*1000) ms)")
        add_result!(precision_name, gflops, "GFlop/s")
    end
end

function run_gemm(backend, comm; size::Int=8192)
    bench_gemm(Float64, backend, comm; size=size)
    bench_gemm(Float32, backend, comm; size=size)
    bench_gemm(Float16, backend, comm; size=size)
end
