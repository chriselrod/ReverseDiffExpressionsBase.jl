



@inline RESERVED_INCREMENT_SEED_RESERVED!(c::AbstractUninitializedReference, a) = (c[] =  a; nothing)
@inline function RESERVED_INCREMENT_SEED_RESERVED!(c, a)
    c[] = SIMDPirates.vadd(c[], a); nothing
end
@inline function RESERVED_INCREMENT_SEED_RESERVED!(c::AbstractUninitializedReference, a, b)
    c[] = SIMDPirates.vmul(a, b); nothing
end
@inline function RESERVED_INCREMENT_SEED_RESERVED!(c, a, b)
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


