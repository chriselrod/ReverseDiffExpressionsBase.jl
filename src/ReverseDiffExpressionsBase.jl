module ReverseDiffExpressionsBase

# using StackPointers, SIMDPirates, VectorizationBase, LinearAlgebra
using LoopVectorization, OffsetArrays, VectorizationBase, ChainRules, StackPointers
using LoopVectorization: second, third, fourth, fifth, sixth, seventh, eighth, ninth

# import SIMDPirates: vadd, vsum, vifelse

# export uninitialized, isinitialized, tadd

# export Zero, One


# Base.Broadcast.materialize to be used for instantiating lazy objects.
# @inline grad
function constrain end
function constrain_pullback end
function constrain_reverse! end
function logpdf end
function ∂logpdf! end

@inline StackPointers.stack_pointer_call(::typeof(ChainRules.rrule), sp::StackPointer, f::F, args::Vararg{<:Any,N}) where {F, N} = (sp, rrule(f, args...))

include("derivativerules.jl")
# include("initialized_variable_tracker.jl")
include("identities.jl")
# include("uninitialized_references.jl")
include("target.jl")
# include("seed_increments.jl")
# include("fallback.jl")

adj(out, a) = Symbol("##∂", out, "/∂", a, "##")
adj(a) = adj(:target, a)

# RESERVED_INCREMENT_SEED_RESERVED! ∂getindex uninitialized
# @def_stackpointer_fallback alloc_adjoint
function __init__()
    # @add_stackpointer_method alloc_adjoint
end


end # module
