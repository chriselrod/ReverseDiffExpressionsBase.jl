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


