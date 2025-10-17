using CUDA, CUDA.CUSPARSE
using CUDSS
using LinearAlgebra
using SparseArrays
using Adapt
using BenchmarkTools
using Profile

device_count = CUDA.ndevices()
device_indices = collect(0:device_count-1)
T = Float64
n = 100

gpu(x) = adapt(CUDABackend(), x)
function create_matrix(T, n, density)
    A_cpu = sprand(T, n, n, density)
    A_cpu = A_cpu + A_cpu' + I
    A_gpu = CuSparseMatrixCSR(gpu(A_cpu.colptr), gpu(A_cpu.rowval), gpu(A_cpu.nzval), size(A_cpu))
    GB = nnz(A_cpu) * (sizeof(T) + sizeof(Int32)) / (1024^3)
    println("Creating matrix of size $(n)x$(n) with density $(density) and $(nnz(A_cpu)) non-zeros.")
    println("Approximate size of the matrix in GPU memory: $(round(GB, digits=2)) GB")
    return A_gpu
end

function create_solver(A::T, device_count, device_indices) where {T <: AbstractSparseMatrix}
    handle = CUDSS.cudssCreateMg(Cint(device_count), Cint.(device_indices))
    data = CudssData(handle)
    config = CudssConfig(Cint(device_count), Cint.(device_indices))
    matrix = CudssMatrix(A, "S", 'F')
    solver = CudssSolver(matrix, config, data)
    return solver
end

function analysis!(solver, x, b)
    cudss("analysis", solver, x, b)
    CUDA.synchronize()
end

function factorization!(solver, x, b)
    cudss("factorization", solver, x, b)
    CUDA.synchronize()
end

function solve!(solver, x, b)
    cudss("solve", solver, x, b)
    CUDA.synchronize()
end

@time A = create_matrix(T, n, 0.01)
@time solver = create_solver(A, device_count, device_indices)

@info "Starting analysis..."
b = gpu(rand(T, n))
x = similar(b)
@btime analysis!(solver, x, b)

@info "Starting factorization..."
@btime factorization!(solver, x, b)
@info "Starting solve..."
@btime solve!(solver, x, b)
r = b - A * x
println("Residual norm ||b - A*x||: $(norm(r))")
