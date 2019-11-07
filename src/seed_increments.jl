

const Reference{T} = Union{Base.RefValue{T}, Pointer{T}}

@inline RESERVED_INCREMENT_SEED_RESERVED!(c::AbstractUninitializedReference, a::Reference) = (c[] =  a; nothing)
@inline function RESERVED_INCREMENT_SEED_RESERVED!(c::Reference, a::Reference)
    c[] = SIMDPirates.vadd(c[], a); nothing
end
@inline function RESERVED_INCREMENT_SEED_RESERVED!(c::AbstractUninitializedReference, a::Reference, b::Reference)
    c[] = SIMDPirates.vmul(a, b); nothing
end
@inline function RESERVED_INCREMENT_SEED_RESERVED!(c::Reference, a::Reference, b::Reference)
    c[] = SIMDPirates.vmuladd(a, b, c[]); nothing
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


