module ReverseDiffExpressionsBase

using StackPointers, SIMDPirates, VectorizationBase

import SIMDPirates: vadd, vsum, vifelse

export uninitialized, isinitialized, tadd

export Zero, One


# Base.Broadcast.materialize to be used for instantiating lazy objects.
# @inline grad

include("initialized_variable_tracker.jl")
include("identities.jl")
include("uninitialized_references.jl")
include("target.jl")
include("seed_increments.jl")

adj(out, a) = Symbol("##∂", out, "/∂", a, "##")
adj(a) = adj(:target, a)


# RESERVED_INCREMENT_SEED_RESERVED! ∂getindex uninitialized
@def_stackpointer_fallback alloc_adjoint
function __init__()
    @add_stackpointer_method alloc_adjoint
end


end # module
