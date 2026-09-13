-- Keep `module load julia` on 1.12 even though 1.13 is installed. Lmod would
-- otherwise pick the numerically highest version. Promote 1.13 here once
-- oneAPI.jl and the oneAPI-aware MPI.jl branch are confirmed to work on it.
module_version("julia/1.12", "default")
