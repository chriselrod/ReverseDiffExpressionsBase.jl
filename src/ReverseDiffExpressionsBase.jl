module ReverseDiffExpressionsBase

using StackPointers, SIMDPirates, VectorizationBase

import SIMDPirates: vadd, vsum, vifelse

export uninitialized, isinitialized, tadd

export Zero, One


# Base.Broadcast.materialize to be used for instantiating lazy objects.
# @inline grad

include("identities.jl")
include("uninitialized_references.jl")
include("target.jl")
include("seed_increments.jl")

adj(out, a) = Symbol("##∂", out, "/∂", a, "##")
adj(a) = adj(:target, a)

@def_stackpointer_fallback RESERVED_INCREMENT_SEED_RESERVED! ∂getindex alloc_adjoint uninitialized
function __init__()
    @add_stackpointer_method RESERVED_INCREMENT_SEED_RESERVED! ∂getindex alloc_adjoint uninitialized
end


end # module
