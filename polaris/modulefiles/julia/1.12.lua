--[[
Module julia
]]--

help([[Julia programming language]])

whatis("Julia programming language version 1.12")

local version = "1.12"
local prefix = "USER_DEPOT_PATH"
local julia_dir = pathJoin(prefix, "julia-" .. version)

-- Check if Julia installation directory exists
if not isDir(julia_dir) then
    LmodError("Julia " .. version .. " has not been set up.\n" ..
              "Expected installation directory not found: " .. julia_dir .. "\n" ..
              "Please run the setup script to install Julia " .. version .. ".")
end

purge()
family("julia")
conflict("julia")
load("PrgEnv-nvidia/8.6.0")
load("cray-hdf5-parallel/1.14.3.5")
load("cuda/12.6")
unload("xalt")

prepend_path("PATH", pathJoin(julia_dir, "bin"))
prepend_path("MANPATH", pathJoin(julia_dir, "share/man"))
prepend_path("LIBRARY_PATH", pathJoin(julia_dir, "lib"))
prepend_path("LD_LIBRARY_PATH", pathJoin(julia_dir, "lib"))
setenv("JULIA_DEPOT_PATH", "USER_DEPOT_PATH")
setenv("TERM", "xterm-256color")
setenv("LANG", "en_US.UTF-8")

setenv("HTTP_PROXY", "http://proxy.alcf.anl.gov:3128")
setenv("HTTPS_PROXY", "http://proxy.alcf.anl.gov:3128")
setenv("http_proxy", "http://proxy.alcf.anl.gov:3128")
setenv("https_proxy", "http://proxy.alcf.anl.gov:3128")
setenv("ftp_proxy", "http://proxy.alcf.anl.gov:3128")

-- prepend-path LD_LIBRARY_PATH /opt/nvidia/hpc_sdk/Linux_x86_64/24.11/cuda/12.6/extras/CUPTI/lib64

setenv("JULIA_CUDA_MEMORY_POOL", "none")
setenv("MPICH_GPU_SUPPORT_ENABLED", "1")

if os.getenv("CRAY_MPICH_DIR") then
    setenv("JULIA_MPI_PATH", "/opt/cray/pe/mpich/8.1.32/ofi/nvidia/23.3")
end

setenv("JULIA_MPI_HAS_CUDA", "1")
