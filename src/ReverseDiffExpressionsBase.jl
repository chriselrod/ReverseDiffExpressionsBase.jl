module ReverseDiffExpressionsBase

using StackPointers, SIMDPirates, VectorizationBase

import SIMDPirates: vadd, vsum, vifelse

export uninitialized, isinitialized, tadd

export Zero, One

"""
 Additive identity.
"""
struct Zero end
@inline Base.:+(::Zero, a) = a
@inline Base.:+(a, ::Zero) = a
@inline Base.:+(::Zero, ::Zero) = Zero()
@inline Base.:+(sptr::StackPointer, ::Zero, a) = (sptr, a)
@inline Base.:+(sptr::StackPointer, a, ::Zero) = (sptr, a)
@inline Base.:+(sptr::StackPointer, ::Zero, ::Zero) = (sptr, Zero())
@inline SIMDPirates.vadd(::Zero, a) = a
@inline SIMDPirates.vadd(a, ::Zero) = a
@inline SIMDPirates.vadd(::Zero, ::Zero) = Zero()
@inline SIMDPirates.vadd(sptr::StackPointer, ::Zero, a) = (sptr, a)
@inline SIMDPirates.vadd(sptr::StackPointer, a, ::Zero) = (sptr, a)
@inline SIMDPirates.vadd(sptr::StackPointer, ::Zero, ::Zero) = (sptr, Zero())

@inline Base.:*(::Zero, a) = Zero()
@inline Base.:*(a, ::Zero) = Zero()
@inline Base.:*(::Zero, ::Zero) = Zero()
@inline Base.:*(sptr::StackPointer, ::Zero, a) = (sptr, Zero())
@inline Base.:*(sptr::StackPointer, a, ::Zero) = (sptr, Zero())
@inline Base.:*(sptr::StackPointer, ::Zero, ::Zero) = (sptr, Zero())
@inline SIMDPirates.vmul(::Zero, a) = Zero()
@inline SIMDPirates.vmul(a, ::Zero) = Zero()
@inline SIMDPirates.vmul(::Zero, ::Zero) = Zero()
@inline SIMDPirates.vmul(sptr::StackPointer, ::Zero, a) = (sptr, Zero())
@inline SIMDPirates.vmul(sptr::StackPointer, a, ::Zero) = (sptr, Zero())
@inline SIMDPirates.vmul(sptr::StackPointer, ::Zero, ::Zero) = (sptr, Zero())


"""
Multiplicative identity.
"""
struct One end
@inline Base.:*(::One, a) = a
@inline Base.:*(a, ::One) = a
@inline Base.:*(::One, ::One) = One()
@inline Base.:*(sptr::StackPointer, ::One, a) = (sptr, a)
@inline Base.:*(sptr::StackPointer, a, ::One) = (sptr, a)
@inline Base.:*(sptr::StackPointer, ::One, ::One) = (sptr, One())
@inline SIMDPirates.vmul(::One, a) = a
@inline SIMDPirates.vmul(a, ::One) = a
@inline SIMDPirates.vmul(::One, ::One) = One()
@inline SIMDPirates.vmul(sptr::StackPointer, ::One, a) = (sptr, a)
@inline SIMDPirates.vmul(sptr::StackPointer, a, ::One) = (sptr, a)
@inline SIMDPirates.vmul(sptr::StackPointer, ::One, ::One) = (sptr, One())
@inline Base.inv(::One) = One()
@inline Base.FastMath.inv_fast(::One) = One()
@inline Base.:/(a, ::One) = a
@inline Base.FastMath.div_fast(a, ::One) = a

Base.size(::Zero) = Core.tuple()
Base.size(::One) = Core.tuple()

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
@inline initialized(x) = x
@inline initialized(x::UninitializedRef) = x.data
@inline initialized(x::UninitializedPtr) = Pointer(x.ptr)
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
