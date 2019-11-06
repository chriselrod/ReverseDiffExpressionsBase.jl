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
@inline uninitialized(x::Pointer) = UninitializedPtr(pointer(x))
@inline initialized(x) = x
@inline initialized(x::UninitializedRef) = x.data
@inline initialized(x::UninitializedPtr) = Pointer(x.ptr)
isinitialized(::Any) = true
isinitialized(::Type{<:UninitializedRef}) = false
isinitialized(::Type{<:UninitializedPtr}) = false
@inline zero_initialize!(A::AbstractArray{T}) where {T} = fill!(A, zero(T))
@inline zero_initialize!(x::Base.RefValue{T}) where {T} = x[] = zero(T)
@inline zero_initialize!(x::Pointer{T}) where {T} = x[] = zero(T)

