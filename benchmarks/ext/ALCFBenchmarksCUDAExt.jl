"""
CUDA extension for ALCFBenchmarks - provides CUDA-specific topology discovery.
"""
module ALCFBenchmarksCUDAExt

import ALCFBenchmarks
using ALCFBenchmarks: DeviceInfo, P2PInfo
using CUDA
using Printf
import KernelAbstractions as KA

"""
    discover_topology(backend::CUDABackend) -> (devices, p2p_matrix)

CUDA-specific topology discovery using CUDA.jl APIs.
"""
function ALCFBenchmarks.discover_topology(backend::CUDABackend)
    devices = collect(CUDA.devices())
    n = length(devices)

    # Gather device info
    device_infos = DeviceInfo[]
    for (idx, dev) in enumerate(devices)
        id = idx - 1  # 0-based
        name = CUDA.name(dev)
        uuid = string(CUDA.uuid(dev))

        # Get PCI address
        domain = CUDA.attribute(dev, CUDA.CU_DEVICE_ATTRIBUTE_PCI_DOMAIN_ID)
        bus = CUDA.attribute(dev, CUDA.CU_DEVICE_ATTRIBUTE_PCI_BUS_ID)
        device_id = CUDA.attribute(dev, CUDA.CU_DEVICE_ATTRIBUTE_PCI_DEVICE_ID)
        pci_bus = @sprintf("%04x:%02x:%02x.0", domain, bus, device_id)

        push!(device_infos, DeviceInfo(id, name, uuid, pci_bus, false, -1))
    end

    # Build P2P matrix
    p2p_matrix = Matrix{P2PInfo}(undef, n, n)
    for i in 1:n, j in 1:n
        if i == j
            p2p_matrix[i, j] = P2PInfo(i-1, j-1, true, 0, true, 0.0, 0.0)
        else
            accessible = CUDA.can_access_peer(devices[i], devices[j])
            perf_rank = CUDA.p2p_attribute(devices[i], devices[j],
                CUDA.CU_DEVICE_P2P_ATTRIBUTE_PERFORMANCE_RANK)
            atomic = CUDA.p2p_attribute(devices[i], devices[j],
                CUDA.CU_DEVICE_P2P_ATTRIBUTE_NATIVE_ATOMIC_SUPPORTED) == 1
            p2p_matrix[i, j] = P2PInfo(i-1, j-1, accessible, perf_rank, atomic, 0.0, 0.0)
        end
    end

    return device_infos, p2p_matrix
end

end # module
