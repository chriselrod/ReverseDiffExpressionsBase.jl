module ReverseDiffExpressionsBase

using StackPointers, SIMDPirates, VectorizationBase

import SIMDPirates: vadd, vsum, vifelse

export uninitialized, isinitialized

# export Zero, One

# """
# Additive identity.
# """
# struct Zero end
# @inline Base.:+(a::Zero, b) = b
# @inline Base.:+(a, b::Zero) = a
# @inline Base.:+(a::Zero, b::Zero) = Zero()
# @inline Base.:+(sptr::StackPointer, a::Zero, b) = (sptr, b)
# @inline Base.:+(sptr::StackPointer, a, b::Zero) = (sptr, a)
# @inline Base.:+(sptr::StackPointer, a::Zero, b::Zero) = (sptr, Zero())
# """
# Multiplicative identity.
# """
# struct One end
# @inline Base.:*(a::One, b) = b
# @inline Base.:*(a, b::One) = a
# @inline Base.:*(a::One, b::One) = One()
# @inline Base.:*(sptr::StackPointer, a::One, b) = (sptr, b)
# @inline Base.:*(sptr::StackPointer, a, b::One) = (sptr, a)
# @inline Base.:*(sptr::StackPointer, a::One, b::One) = (sptr, One())

# Base.size(::Zero) = Core.tuple()
# Base.size(::One) = Core.tuple()

abstract type AbstractUninitializedReference{T} end
"""
This is a struct wrapping a RefValue rather than a mutable struct
because the ReverseDiff API wants the initialized parameters to be
Refs of some kind; it is simpler to wrap the first access in an
Uninitialized struct than a mutable struct.
"""
struct UninitializedRef{T} <: AbstractUninitializedReference{T}
    data::Base.RefValue{T}
end
@inline Base.getindex(uninit::UninitializedRef) = uninit.data[]
@inline Base.setindex!(uninit::UninitializedRef{T}, v::T) where {T} = uninit.data[] = v
struct UninitializedPtr{T} <: AbstractUninitializedReference{T}
    ptr::Ptr{T}
end
@inline Base.getindex(uninit::UninitializedPtr) = VectorizationBase.load(uninit.ptr)
@inline Base.setindex!(uninit::UninitializedPtr{T}, v::T) where {T} = VectorizationBase.store!(uninit.ptr, v)

function ∂getindex end
function ∂mul end
@inline alloc_adjoint(x::T) where {T<:Real} = Ref{T}()
@inline uninitialized(::Nothing) = nothing
@inline uninitialized(x::Base.RefValue) = Uninitialized(x)
@inline uninitialized(x::VectorizationBase.Pointer) = UninitializedPtr(pointer(x))
isinitialized(::Any) = true
isinitialized(::Type{<:UninitializedRef}) = false
isinitialized(::Type{<:UninitializedPtr}) = false

# Base.Broadcast.materialize to be used for instantiating lazy objects.
# @inline grad


include("target.jl")
include("seed_increments.jl")

adj(out, a) = Symbol("##∂", out, "/∂", a, "##")
adj(a) = adj(:target, a)

@def_stackpointer_fallback RESERVED_INCREMENT_SEED_RESERVED! ∂getindex alloc_adjoint uninitialized
function __init__()
    @add_stackpointer_method RESERVED_INCREMENT_SEED_RESERVED! ∂getindex alloc_adjoint uninitialized
end


end # module
