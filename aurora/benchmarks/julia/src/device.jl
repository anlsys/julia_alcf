"""
Device distribution utilities for multi-GPU MPI benchmarks.
"""

import KernelAbstractions as KA

"""
    get_backend_for_rank(backend_type, comm) -> backend

Select a device based on MPI rank and return a backend for that device.
Devices are distributed round-robin across MPI ranks.

# Arguments
- `backend_type`: The backend type (e.g., `CUDABackend`, `oneAPIBackend`, `ROCBackend`)
- `comm`: MPI communicator

# Returns
- A backend instance configured for the appropriate device
"""
function get_backend_for_rank(backend_type, comm)
    rank = MPI.Comm_rank(comm)
    
    # Create a default backend instance to query device count
    backend = backend_type()
    ndev = KA.ndevices(backend)
    
    if ndev == 0
        error("No devices available for backend $backend_type")
    end
    
    # Round-robin device assignment (0-indexed for KA.device!)
    device_id = rank % ndev
    KA.device!(backend, device_id + 1)  # KA uses 1-indexed device IDs
    
    if rank == 0
        world_size = MPI.Comm_size(comm)
        println("Running with $ndev device(s), $world_size MPI rank(s)")
    end
    
    return backend
end
