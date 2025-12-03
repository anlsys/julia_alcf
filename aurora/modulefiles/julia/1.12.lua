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
end
