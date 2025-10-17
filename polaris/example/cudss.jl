using CUDA, CUDA.CUSPARSE
using CUDSS
using LinearAlgebra
using SparseArrays

T = Float64
n = 100
A_cpu = sprand(T, n, n, 0.01)
A_cpu = A_cpu + A_cpu' + I
b_cpu = rand(T, n)

A_gpu = CuSparseMatrixCSR(A_cpu)
b_gpu = CuVector(b_cpu)
x_gpu = similar(b_gpu)

solver = CudssSolver(A_gpu, "S", 'F')

# Use the hybrid mode (host and device memory)

cudss("analysis", solver, x_gpu, b_gpu)

# Minimal amount of device memory required in the hybrid memory mode.
# nbytes_gpu = cudss_get(solver, "hybrid_device_memory_min")

# Device memory limit for the hybrid memory mode.
# Only use it if you don't want to rely on the internal default heuristic.
# cudss_set(solver, "hybrid_device_memory_limit", nbytes_gpu)

cudss("factorization", solver, x_gpu, b_gpu)
cudss("solve", solver, x_gpu, b_gpu)

r_gpu = b_gpu - CuSparseMatrixCSR(A_cpu) * x_gpu
norm(r_gpu)