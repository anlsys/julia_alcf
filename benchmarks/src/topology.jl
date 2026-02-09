"""
Topology benchmark - discovers GPU topology and P2P connectivity.

Provides a portable abstraction over backend-specific topology APIs:
- CUDA: Uses CUDA.can_access_peer() and CUDA.p2p_attribute()
- oneAPI: Uses Level Zero experimental fabric vertex/edge APIs

Backend-specific implementations are provided via package extensions:
- ALCFBenchmarksCUDAExt for CUDA backends
- ALCFBenchmarksoneAPIExt for oneAPI backends
"""

using Printf
import KernelAbstractions as KA

#==============================================================================#
# Generic interface
#==============================================================================#

"""
    DeviceInfo

Information about a single GPU device.
"""
struct DeviceInfo
    id::Int              # Device index (0-based)
    name::String         # Device name
    uuid::String         # Device UUID
    pci_bus::String      # PCI bus address (domain:bus:device.function)
    is_subdevice::Bool   # Whether this is a sub-device/tile
    parent_id::Int       # Parent device ID (-1 if not a sub-device)
end

"""
    P2PInfo

Peer-to-peer connectivity information between two devices.
"""
struct P2PInfo
    src::Int             # Source device index
    dst::Int             # Destination device index
    accessible::Bool     # Whether P2P access is supported
    performance_rank::Int # Relative performance (higher = better, e.g., NVLink > PCIe)
    atomic_supported::Bool # Whether native atomics are supported
    bandwidth::Float64   # Bandwidth in GB/s (0 if unknown)
    latency::Float64     # Latency in ns (0 if unknown)
end

"""
    discover_topology(backend) -> (devices::Vector{DeviceInfo}, p2p::Matrix{P2PInfo})

Discover GPU topology for the given backend. Returns device information and
a P2P connectivity matrix.

This function is extended by package extensions for specific backends.
"""
function discover_topology(backend)
    error("Topology discovery not implemented for backend: $(typeof(backend)). " *
          "Make sure the appropriate GPU package (CUDA.jl or oneAPI.jl) is loaded.")
end

"""
    print_topology(devices, p2p_matrix)

Pretty-print topology information.
"""
function print_topology(devices::Vector{DeviceInfo}, p2p::Matrix{P2PInfo})
    println("=" ^ 70)
    println("GPU Topology Discovery")
    println("=" ^ 70)

    # Print device info
    println("\nDevices:")
    println("-" ^ 70)
    for dev in devices
        subdev_str = dev.is_subdevice ? " (tile of device $(dev.parent_id))" : ""
        println("  [$(dev.id)] $(dev.name)$subdev_str")
        println("       UUID: $(dev.uuid)")
        println("       PCI:  $(dev.pci_bus)")
    end

    # Print P2P connectivity matrix
    n = length(devices)
    if n > 1
        println("\nP2P Connectivity Matrix (access supported):")
        println("-" ^ 70)

        # Header
        print("      ")
        for j in 1:n
            print("  [$(j-1)] ")
        end
        println()

        # Matrix
        for i in 1:n
            print("  [$(i-1)] ")
            for j in 1:n
                if i == j
                    print("   -  ")
                else
                    sym = p2p[i, j].accessible ? "  Y  " : "  .  "
                    print("$sym ")
                end
            end
            println()
        end

        # Print performance ranks if available
        has_perf = any(p2p[i, j].performance_rank > 0 for i in 1:n, j in 1:n if i != j)
        if has_perf
            println("\nP2P Performance Ranks (higher = faster link):")
            println("-" ^ 70)
            print("      ")
            for j in 1:n
                print("  [$(j-1)] ")
            end
            println()
            for i in 1:n
                print("  [$(i-1)] ")
                for j in 1:n
                    if i == j
                        print("   -  ")
                    else
                        rank = p2p[i, j].performance_rank
                        print(lpad(rank, 4), "  ")
                    end
                end
                println()
            end
        end

        # Print bandwidth if available
        has_bw = any(p2p[i, j].bandwidth > 0 for i in 1:n, j in 1:n if i != j)
        if has_bw
            println("\nP2P Bandwidth (GB/s):")
            println("-" ^ 70)
            print("      ")
            for j in 1:n
                print("   [$(j-1)]  ")
            end
            println()
            for i in 1:n
                print("  [$(i-1)] ")
                for j in 1:n
                    if i == j
                        print("    -   ")
                    else
                        bw = p2p[i, j].bandwidth
                        if bw > 0
                            print(lpad(round(bw, digits=1), 6), "  ")
                        else
                            print("    .   ")
                        end
                    end
                end
                println()
            end
        end
    end

    println("\n" * "=" ^ 70)
end

#==============================================================================#
# Entry point
#==============================================================================#

function run_topology(backend, comm)
    world_rank = MPI.Comm_rank(comm)

    if world_rank == 0
        backend_name = string(typeof(backend))

        try
            devices, p2p = discover_topology(backend)
            print_topology(devices, p2p)
        catch e
            println("Topology discovery failed for $backend_name")
            println("Error: $e")
            println("")
            println("For detailed fabric topology on Intel GPUs, use the C++ binary:")
            println("  cd aurora/benchmarks/cpp")
            println("  make topology")
            println("  ./topology")
        end
    end
end
