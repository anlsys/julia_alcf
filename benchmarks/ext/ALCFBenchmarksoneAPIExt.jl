"""
oneAPI extension for ALCFBenchmarks - provides oneAPI-specific topology discovery.
"""
module ALCFBenchmarksoneAPIExt

import ALCFBenchmarks
using ALCFBenchmarks: DeviceInfo, P2PInfo
using oneAPI
using Printf
import KernelAbstractions as KA

"""
    discover_topology(backend::oneAPIBackend) -> (devices, p2p_matrix)

oneAPI-specific topology discovery using Level Zero APIs.
"""
function ALCFBenchmarks.discover_topology(backend::oneAPIBackend)
    oneL0 = oneAPI.oneL0

    # Get all devices
    all_devices = oneAPI.devices()
    n = length(all_devices)

    # Gather device info
    device_infos = DeviceInfo[]
    for (idx, dev) in enumerate(all_devices)
        id = idx - 1
        props = oneL0.properties(dev)
        name = unsafe_string(pointer([props.name...]))

        # UUID as hex string
        uuid_bytes = props.uuid.id
        uuid = join([@sprintf("%02x", b) for b in uuid_bytes], "")

        # Check if sub-device
        is_subdevice = !isnothing(props.subdeviceId)
        parent_id = is_subdevice ? props.subdeviceId : -1

        # PCI address (if available in device properties)
        pci_bus = "N/A"  # oneAPI doesn't expose PCI directly in device props

        push!(device_infos, DeviceInfo(id, name, uuid, pci_bus, is_subdevice, parent_id))
    end

    # Try to get fabric topology using experimental APIs
    p2p_matrix = Matrix{P2PInfo}(undef, n, n)

    # Initialize with default values
    for i in 1:n, j in 1:n
        p2p_matrix[i, j] = P2PInfo(i-1, j-1, i == j, 0, false, 0.0, 0.0)
    end

    # Try fabric vertex/edge APIs for detailed topology
    try
        drv = first(oneL0.drivers())

        # Get fabric vertices
        count_ref = Ref{UInt32}(0)
        oneL0.zeFabricVertexGetExp(drv, count_ref, C_NULL)

        if count_ref[] > 0
            vertices = Vector{oneL0.ze_fabric_vertex_handle_t}(undef, count_ref[])
            oneL0.zeFabricVertexGetExp(drv, count_ref, vertices)

            # Map vertices to device indices
            vertex_to_dev = Dict{oneL0.ze_fabric_vertex_handle_t, Int}()
            for (vidx, vertex) in enumerate(vertices)
                # Get device from vertex
                dev_ref = Ref{oneL0.ze_device_handle_t}()
                try
                    oneL0.zeFabricVertexGetDeviceExp(vertex, dev_ref)
                    # Find matching device index
                    for (didx, dev) in enumerate(all_devices)
                        if dev.handle == dev_ref[]
                            vertex_to_dev[vertex] = didx
                            break
                        end
                    end
                catch
                    continue
                end
            end

            # Get edges between vertices
            for (i, v1) in enumerate(vertices), (j, v2) in enumerate(vertices)
                if i >= j
                    continue
                end

                edge_count_ref = Ref{UInt32}(0)
                oneL0.zeFabricEdgeGetExp(v1, v2, edge_count_ref, C_NULL)

                if edge_count_ref[] > 0
                    edges = Vector{oneL0.ze_fabric_edge_handle_t}(undef, edge_count_ref[])
                    oneL0.zeFabricEdgeGetExp(v1, v2, edge_count_ref, edges)

                    for edge in edges
                        props_ref = Ref(oneL0.ze_fabric_edge_exp_properties_t())
                        oneL0.zeFabricEdgeGetPropertiesExp(edge, props_ref)
                        props = props_ref[]

                        # Get device indices
                        di = get(vertex_to_dev, v1, 0)
                        dj = get(vertex_to_dev, v2, 0)

                        if di > 0 && dj > 0
                            bw = Float64(props.bandwidth)
                            lat = Float64(props.latency)

                            p2p_matrix[di, dj] = P2PInfo(di-1, dj-1, true, 0, false, bw, lat)
                            p2p_matrix[dj, di] = P2PInfo(dj-1, di-1, true, 0, false, bw, lat)
                        end
                    end
                end
            end
        end
    catch e
        # Fabric APIs may not be available - fall back to basic device enumeration
        @debug "Fabric topology discovery failed: $e"
    end

    return device_infos, p2p_matrix
end

end # module
