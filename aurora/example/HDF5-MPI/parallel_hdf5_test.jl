#!/usr/bin/env julia

"""
Parallel HDF5 test for Julia on Aurora

Verifies that HDF5.jl is configured against the system parallel HDF5 build (rather
than its own serial artifact) and that a collective write/read across MPI ranks
produces the expected data.

Usage:
    mpiexec -n 24 --ppn 12 julia --project parallel_hdf5_test.jl
"""

using MPI
using HDF5

MPI.Init()

const comm = MPI.COMM_WORLD
const rank = MPI.Comm_rank(comm)
const nranks = MPI.Comm_size(comm)

if rank == 0
    println("HDF5.jl version      : ", pkgversion(HDF5))
    println("HDF5 library version : ", HDF5.API.h5_get_libversion())
    println("HDF5.has_parallel()  : ", HDF5.has_parallel())
    println("libhdf5              : ", HDF5.API.libhdf5)
    println("MPI library          : ", strip(MPI.MPI_LIBRARY_VERSION_STRING))
    println("Ranks                : ", nranks)
    println()
end

if !HDF5.has_parallel()
    rank == 0 && println("FAIL: HDF5.jl has no parallel support -- it is using the serial artifact")
    MPI.Abort(comm, 1)
end

const N = 16                       # elements contributed by each rank
const path = joinpath(get(ENV, "PBS_O_WORKDIR", pwd()), "parallel_test.h5")

rank == 0 && isfile(path) && rm(path)
MPI.Barrier(comm)

# Collective write: every rank fills its own column of one shared dataset.
h5open(path, "w", comm, MPI.Info()) do file
    dset = create_dataset(file, "data", datatype(Float64), dataspace(N, nranks);
                          chunk=(N, 1), dxpl_mpio=:collective)
    dset[:, rank + 1] = fill(Float64(rank), N)
end

MPI.Barrier(comm)

# Collective read-back, verified independently on every rank.
ok = h5open(path, "r", comm, MPI.Info()) do file
    dset = open_dataset(file, "data"; dxpl_mpio=:collective)
    data = read(dset)
    expected = repeat(reshape(Float64.(0:nranks-1), 1, nranks), N, 1)
    data == expected
end

all_ok = MPI.Allreduce(ok, &, comm)

if rank == 0
    println("Wrote $(N * nranks) elements to $path ($(filesize(path)) bytes)")
    println(all_ok ? "PASS: collective write/read verified on all $nranks ranks" :
                     "FAIL: data mismatch after collective read")
end

MPI.Barrier(comm)
MPI.Finalize()
all_ok || exit(1)
