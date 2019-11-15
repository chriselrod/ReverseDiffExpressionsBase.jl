

const InitializedReference{T} = Union{Base.RefValue{T}, Pointer{T}}

@inline deref(x::Number) = x
@inline deref(x::InitializedReference) = x[]
@inline RESERVED_INCREMENT_SEED_RESERVED!(c::AbstractUninitializedReference, a) = (c[] =  deref(a); nothing)
@inline function RESERVED_INCREMENT_SEED_RESERVED!(c::InitializedReference, a)
    c[] = SIMDPirates.vadd(c[], deref(a)); nothing
end
@inline function RESERVED_INCREMENT_SEED_RESERVED!(c::AbstractUninitializedReference, a, b)
    c[] = SIMDPirates.vmul(deref(a), deref(b)); nothing
end
@inline function RESERVED_INCREMENT_SEED_RESERVED!(c::InitializedReference, a, b)
    c[] = SIMDPirates.vmuladd(deref(a), deref(b), c[]); nothing
end
# @inline RESERVED_DECREMENT_SEED_RESERVED!(c::Uninitialized, a) = (c[] = -a; nothing)
# @inline function RESERVED_DECREMENT_SEED_RESERVED!(c, a)
    # c[] = SIMDPirates.vsub(c[], a); nothing
# end
# @inline function RESERVED_DECREMENT_SEED_RESERVED!(c::Uninitialized, a, b)
    # c[] = - SIMDPirates.vmul(a, b); nothing
# end
# @inline function RESERVED_DECREMENT_SEED_RESERVED!(c, a, b)
    # c[] = SIMDPirates.fnmadd(a, b, c[]); nothing
# end
@inline function RESERVED_INCREMENT_SEED_RESERVED!(
    c::AbstractUninitializedReference, A::AbstractArray
)
    c[] = sum(A)
end
@inline function RESERVED_INCREMENT_SEED_RESERVED!(
    c::InitializedReference, A::AbstractArray
)
    c[] = Base.FastMath.add_fast(c[], sum(A))
end
@inline function RESERVED_INCREMENT_SEED_RESERVED!(
    c::AbstractUninitializedReference, A::AbstractArray, B::AbstractArray
)
    c[] = dot(A, B)
end
@inline function RESERVED_INCREMENT_SEED_RESERVED!(
    c::InitializedReference, A::AbstractArray, B::AbstractArray
)
    c[] = Base.FastMath.add_fast(c[], dot(A, B))
end
@inline function RESERVED_INCREMENT_SEED_RESERVED!(
    c::AbstractUninitializedReference, A, B::AbstractArray
)
    c[] = Base.FastMath.mul_fast(deref(A), sum(B))
end
@inline function RESERVED_INCREMENT_SEED_RESERVED!(
    c::InitializedReference, A, B::AbstractArray
)
    c[] = Base.FastMath.add_fast(c[], Base.FastMath.mul_fast(deref(A), sum(B)))
end
@inline function RESERVED_INCREMENT_SEED_RESERVED!(
    c::AbstractUninitializedReference, A::AbstractArray, B
)
    c[] = Base.FastMath.mul_fast(deref(B), sum(A))
end
@inline function RESERVED_INCREMENT_SEED_RESERVED!(
    c::InitializedReference, A::AbstractArray, B
)
    c[] = Base.FastMath.add_fast(c[], Base.FastMath.mul_fast(deref(B), sum(A)))
end



