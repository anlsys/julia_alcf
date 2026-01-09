#!/usr/bin/env julia

"""
Comprehensive oneAPI-aware MPI test suite for Julia

This script tests various MPI operations with oneAPI arrays to verify
that oneAPI-aware MPI is working correctly.

Usage:
    mpirun -n 4 julia --project oneapi_mpi_test.jl
"""

using oneAPI
using MPI
using Printf
import KernelAbstractions as KA
using Adapt

KA.ndevices(::oneAPIBackend) = length(oneAPI.devices().handles)
KA.device!(id::Integer) = oneAPI.device!(id - 1)  # Convert to 0-based index

function check_oneapi_mpi_support()
    """Check if oneAPI-aware MPI is properly configured"""
    has_oneapi = MPI.has_oneapi()
    if !has_oneapi
        error("oneAPI-aware MPI is not available. Please check your MPI installation.")
    end
    return has_oneapi
end

function test_point_to_point_communication(comm, backend)
    """Test point-to-point communication with GPU arrays"""
    rank = MPI.Comm_rank(comm)
    size = MPI.Comm_size(comm)

    if size < 2
        @warn "Point-to-point test requires at least 2 processes"
        return true
    end

    n = 1000
    success = true

    if rank == 0
        # Send data from rank 0 to rank 1
        send_data = adapt(backend, collect(1.0f0:Float32(n)))
        println("Rank $rank: Sending $(length(send_data)) elements to rank 1")
        MPI.Send(send_data, comm; dest=1, tag=42)

    elseif rank == 1
        # Receive data at rank 1
        recv_data = adapt(backend, zeros(Float32, n))
        println("Rank $rank: Receiving data from rank 0")
        MPI.Recv!(recv_data, comm; source=0, tag=42)

        # Verify data
        expected = collect(1.0f0:Float32(n))
        received = Array(recv_data)

        if isapprox(received, expected)
            println("Rank $rank: ✓ Point-to-point communication test PASSED")
        else
            println("Rank $rank: ✗ Point-to-point communication test FAILED")
            success = false
        end
    end

    return success
end

function test_collective_operations(comm, backend)
    """Test collective operations with GPU arrays"""
    rank = MPI.Comm_rank(comm)
    size = MPI.Comm_size(comm)
    n = 100
    success = true

    # Test Allreduce
    gpu_data = adapt(backend, fill(Float32(rank + 1), n))
    original_value = rank + 1

    MPI.Allreduce!(gpu_data, +, comm)

    expected_sum = sum(1:size)
    actual_sum = Array(gpu_data)[1]

    if isapprox(actual_sum, expected_sum)
        println("Rank $rank: ✓ Allreduce test PASSED (sum: $actual_sum)")
    else
        println("Rank $rank: ✗ Allreduce test FAILED (expected: $expected_sum, got: $actual_sum)")
        success = false
    end

    # Test Broadcast
    if rank == 0
        bcast_data = adapt(backend, fill(Float32(π), n))
    else
        bcast_data = adapt(backend, zeros(Float32, n))
    end

    MPI.Bcast!(bcast_data, 0, comm)
    bcast_value = Array(bcast_data)[1]

    if isapprox(bcast_value, π, atol=1e-6)
        println("Rank $rank: ✓ Broadcast test PASSED")
    else
        println("Rank $rank: ✗ Broadcast test FAILED (expected: π, got: $bcast_value)")
        success = false
    end

    # Test Allgather
    local_data = adapt(backend, fill(Float32(rank), 10))
    gathered_data = adapt(backend, zeros(Float32, 10 * size))

    MPI.Allgather!(local_data, gathered_data, comm)

    gathered_host = Array(gathered_data)
    expected_pattern = repeat(collect(0:size-1), inner=10)

    if isapprox(gathered_host, expected_pattern)
        println("Rank $rank: ✓ Allgather test PASSED")
    else
        println("Rank $rank: ✗ Allgather test FAILED")
        success = false
    end

    return success
end

function test_large_data_transfer(comm, backend)
    """Test communication with larger arrays to stress-test the system"""
    rank = MPI.Comm_rank(comm)
    size = MPI.Comm_size(comm)

    if size < 2
        @warn "Large data transfer test requires at least 2 processes"
        return true
    end

    # Test with ~10MB of data
    n = 2^20  # ~4MB of Float32 data
    success = true

    if rank == 0
        large_data = adapt(backend, rand(Float32, n))
        checksum = sum(Array(large_data))

        println("Rank $rank: Sending large array ($(n) elements, ~$(@sprintf("%.1f", n*4/1024/1024)) MB)")

        # Send checksum first, then data
        MPI.Send([checksum], comm; dest=1, tag=100)
        MPI.Send(large_data, comm; dest=1, tag=101)

    elseif rank == 1
        # Receive checksum and data
        checksum_recv = zeros(Float32, 1)
        MPI.Recv!(checksum_recv, comm; source=0, tag=100)

        large_data_recv = adapt(backend, zeros(Float32, n))
        println("Rank $rank: Receiving large array...")
        MPI.Recv!(large_data_recv, comm; source=0, tag=101)

        # Verify checksum
        received_checksum = sum(Array(large_data_recv))
        expected_checksum = checksum_recv[1]

        if isapprox(received_checksum, expected_checksum, rtol=1e-6)
            println("Rank $rank: ✓ Large data transfer test PASSED")
        else
            println("Rank $rank: ✗ Large data transfer test FAILED")
            println("  Expected checksum: $expected_checksum")
            println("  Received checksum: $received_checksum")
            success = false
        end
    end

    return success
end

function test_multiple_gpu_communication(comm, backend)
    """Test communication when multiple GPUs are available"""
    rank = MPI.Comm_rank(comm)
    size = MPI.Comm_size(comm)

    n_devices = KA.ndevices(backend)
    if n_devices < 2
        println("Rank $rank: Only $n_devices GPU(s) available, skipping multi-GPU test")
        return true
    end

    # Use different GPU for each rank
    device_id = rank % n_devices + 1
    KA.device!(backend, device_id)

    println("Rank $rank: Using GPU device $device_id (of $n_devices available)")

    # Simple allreduce test with device affinity
    test_data = fill(Float32(device_id), 100)
    MPI.Allreduce!(test_data, +, comm)

    # Expected sum depends on how ranks map to devices
    device_sum = 0
    for r in 0:(size-1)
        device_sum += (r % n_devices) + 1
    end

    actual_sum = Array(test_data)[1]

    if isapprox(actual_sum, device_sum)
        println("Rank $rank: ✓ Multi-GPU communication test PASSED")
        return true
    else
        println("Rank $rank: ✗ Multi-GPU communication test FAILED")
        println("  Expected: $device_sum, Got: $actual_sum")
        return false
    end
end

function run_performance_benchmark(comm, backend)
    """Run a simple performance benchmark for oneAPI-aware MPI"""
    rank = MPI.Comm_rank(comm)
    size = MPI.Comm_size(comm)

    if size < 2
        return
    end

    # Test different message sizes
    sizes = [1024, 4096, 16384, 65536, 262144, 1048576]  # 4KB to 4MB

    if rank == 0
        println("\nPerformance Benchmark Results:")
        println("Message Size (KB) | Bandwidth (MB/s)")
        println("------------------|------------------")
    end

    for msg_size in sizes
        data = adapt(backend, ones(Float32, msg_size))

        MPI.Barrier(comm)  # Synchronize before timing

        if rank == 0
            start_time = time()
            for _ in 1:10  # Average over 10 iterations
                MPI.Send(data, comm; dest=1, tag=0)
                recv_data = adapt(backend, zeros(Float32, msg_size))
                MPI.Recv!(recv_data, comm; source=1, tag=1)
            end
            end_time = time()

            total_time = (end_time - start_time) / 10  # Average time
            bytes_transferred = msg_size * 4 * 2  # Float32 * roundtrip
            bandwidth_mbps = (bytes_transferred / total_time) / (1024 * 1024)

            @printf("%13.1f | %14.2f\n", msg_size * 4 / 1024, bandwidth_mbps)

        elseif rank == 1
            for _ in 1:10
                recv_data = adapt(backend, zeros(Float32, msg_size))
                MPI.Recv!(recv_data, comm; source=0, tag=0)
                MPI.Send(recv_data, comm; dest=0, tag=1)
            end
        end
    end
end

function main()
    """Main test function"""
    MPI.Init()

    comm = MPI.COMM_WORLD
    rank = MPI.Comm_rank(comm)
    size = MPI.Comm_size(comm)

    if rank == 0
        println("="^60)
        println("oneAPI-aware MPI Test Suite")
        println("="^60)
        println("Number of processes: $size")
        println("Number of oneAPI devices: $(KA.ndevices(oneAPIBackend()))")
        println()
    end

    try
        # Check oneAPI-aware MPI support
        backend = check_oneapi_mpi_support() ? oneAPIBackend() : error("oneAPI-aware MPI not supported")

        # Initialize oneAPI context
        device_id = rank % KA.ndevices(backend) + 1
        KA.device!(backend, device_id)

        if rank == 0
            println("✓ oneAPI-aware MPI support confirmed")
            println()
        end

        # Run tests
        all_tests_passed = true

        # Test 1: Point-to-point communication
        if rank == 0
            println("Running point-to-point communication test...")
        end
        MPI.Barrier(comm)
        success = test_point_to_point_communication(comm, backend)
        all_tests_passed &= success

        # Test 2: Collective operations
        MPI.Barrier(comm)
        if rank == 0
            println("\nRunning collective operations test...")
        end
        success = test_collective_operations(comm, backend)
        all_tests_passed &= success

        # Test 3: Large data transfer
        MPI.Barrier(comm)
        if rank == 0
            println("\nRunning large data transfer test...")
        end
        success = test_large_data_transfer(comm, backend)
        all_tests_passed &= success

        # Test 4: Multi-GPU communication
        MPI.Barrier(comm)
        if rank == 0
            println("\nRunning multi-GPU communication test...")
        end
        success = test_multiple_gpu_communication(comm, backend)
        all_tests_passed &= success

        # Performance benchmark
        MPI.Barrier(comm)
        if rank == 0 && size >= 2
            println("\nRunning performance benchmark...")
        end
        run_performance_benchmark(comm, backend)

        # Final results
        MPI.Barrier(comm)
        if rank == 0
            println("\n" * "="^60)
            if all_tests_passed
                println("🎉 All oneAPI-aware MPI tests PASSED!")
            else
                println("❌ Some tests FAILED. Check output above.")
            end
            println("="^60)
        end

    catch e
        println("Rank $rank: Error during testing: $e")
        rethrow(e)
    finally
        # MPI.Finalize()
    end
end

# Run the main function
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
