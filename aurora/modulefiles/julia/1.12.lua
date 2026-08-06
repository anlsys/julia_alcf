--[[
Module julia
]]--

local system_path = "SYSTEM_DEPOT_PATH"
local version = "1.12"
help([[Julia programming language]])

whatis("Julia programming language version " .. version)


-- Set JULIA_DEPOT_PATH to default if not already set
local julia_depot = os.getenv("JULIA_DEPOT_PATH")
if not julia_depot then
    local home = os.getenv("HOME")
    julia_depot = pathJoin(home, ".julia")
    setenv("JULIA_DEPOT_PATH", julia_depot)
    LmodMessage("JULIA_DEPOT_PATH not set. Using default: " .. julia_depot .. "\n" ..
                "To use a different location, set JULIA_DEPOT_PATH before loading this module.")
end

local prefix = pathJoin(system_path, "julia_binaries")
local julia_dir = pathJoin(prefix, "julia-" .. version)

-- Check if Julia installation directory exists
if not isDir(julia_dir) then
    LmodError("Julia " .. version .. " has not been set up.\n" ..
              "Expected installation directory not found: " .. julia_dir .. "\n" ..
              "Please run the setup script to install Julia " .. version .. ".")
end

unload("xalt")
family("julia")
conflict("julia")
conflict("xalt")

prepend_path("PATH", pathJoin(julia_dir, "bin"))
prepend_path("MANPATH", pathJoin(julia_dir, "share/man"))
prepend_path("LIBRARY_PATH", pathJoin(julia_dir, "lib"))
prepend_path("LD_LIBRARY_PATH", pathJoin(julia_dir, "lib"))
local sys_prefs = pathJoin(system_path, "environments/v" .. version)
if not isDir(sys_prefs) then
    LmodError("Julia " .. version .. " has not been set up.\n" ..
              "Expected installation directory not found: " .. sys_prefs .. "\n" ..
              "Please run the setup script to install Julia " .. version .. ".")
end
setenv("JULIA_LOAD_PATH", "@:@v#.#:@stdlib:" .. sys_prefs)
local tmpdir = pathJoin(julia_depot, "tmp")
setenv("TMPDIR", tmpdir)
-- Check if directory exists; if not, create it
if (not isDir(tmpdir)) then
    execute{cmd="mkdir -p " .. tmpdir, modeA={"load"}}
end

setenv("HTTP_PROXY", "http://proxy.alcf.anl.gov:3128")
setenv("HTTPS_PROXY", "http://proxy.alcf.anl.gov:3128")
setenv("http_proxy", "http://proxy.alcf.anl.gov:3128")
setenv("https_proxy", "http://proxy.alcf.anl.gov:3128")
setenv("ftp_proxy", "http://proxy.alcf.anl.gov:3128")

if (mode() == "load") then
    LmodMessage("Julia module v" .. version .. " successfully loaded.")
    LmodMessage("Warning: Julia needs a large /tmp which is too small. It is set to " .. tmpdir)
    LmodMessage("oneAPI.jl LTS workarounds enabled (ONEAPI_LTS=1); requires oneAPI.jl v2.8 or newer.\n" ..
                "If you precompiled oneAPI before this was set, run Pkg.precompile() once.")
end

setenv("JULIA_MPI_HAS_ONEAPI", "1")
setenv("ZE_FLAT_DEVICE_HIERARCHY", "FLAT")
-- Aurora runs Intel's LTS Compute Runtime (NEO 25.18.33578 / IGC 2.11.29 / Level Zero
-- 1.24), not the rolling stack oneAPI.jl targets by default. Read at load time by
-- oneAPI.jl v2.8+, this compiles kernels with the Khronos SPIR-V translator and enables
-- the LTS driver workarounds: https://juliagpu.github.io/oneAPI.jl/dev/lts/
setenv("ONEAPI_LTS", "1")

-- Intel's compiled-kernel cache, re-enabled.  The site oneapi module sets
-- NEO_CACHE_PERSISTENT=0 unconditionally
-- (/opt/aurora/*/oneapi/modulefiles/oneapi/release/*), which is defensible for
-- AOT-compiled C++ but expensive for Julia: oneAPI.jl JIT-compiles every kernel
-- through IGC at run time, in a fresh process each job, so with the cache off
-- nothing is ever reused and each process pays full IGC compilation again.  In a
-- benchmark campaign that dominated per-instance startup.
--
-- The cache lives beside the depot rather than in /tmp so it survives across
-- jobs, which is the entire point -- a node-local cache is cold in every new
-- allocation.
--
-- `pushenv`, unconditionally, is what makes these revert cleanly.
--
-- Unconditional matters because guarding a set behind `if not os.getenv(...)`
-- breaks unload: Lmod re-evaluates this
-- file in unload mode, finds the variable already set (by this very module),
-- skips the setenv, and so never learns it should restore the previous value.
-- The symptom is that `module unload julia` -- and even `module purge` -- leaves
-- NEO_CACHE_PERSISTENT=1 and NEO_CACHE_DIR pointing into the Julia depot, so a
-- subsequent plain SYCL/C++ job silently inherits Julia's kernel cache.
-- `pushenv` rather than `setenv` matters because unloading a `setenv` UNSETS the
-- variable instead of restoring what was there before, and to NEO an unset
-- NEO_CACHE_PERSISTENT is not the same as 0.  `pushenv` saves the oneapi
-- module's 0 and puts it back, leaving the environment exactly as it was.
--
-- To use a different cache, or to turn persistence back off, set the variables
-- AFTER loading this module.
local neo_cache = pathJoin(julia_depot, "neo_cache")
pushenv("NEO_CACHE_DIR", neo_cache)
pushenv("NEO_CACHE_PERSISTENT", "1")
if (not isDir(neo_cache)) then
    execute{cmd="mkdir -p " .. neo_cache, modeA={"load"}}
end
