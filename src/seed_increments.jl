

# These functions are all registered as supporting StackPointers,
# as we will only use them alongside StackPointers, we only need
# to write versions taking them as the first argument.
#
# Additionally, RESERVED_INCREMENT_SEED_RESERVED and
# RESERVED_DECREMENT_SEED_RESERVED (is this used?)
# are allowed to mutate the last (the incremented) argument.
# 

@inline RESERVED_INCREMENT_SEED_RESERVED(sp::StackPointer, a) = (sp,a)
@inline RESERVED_DECREMENT_SEED_RESERVED(sp::StackPointer, a) = (sp,-a)
@inline function RESERVED_INCREMENT_SEED_RESERVED(sp::StackPointer, a, b, c)
    sp, SIMDPirates.vmuladd(a, b, c)
end
@inline function RESERVED_DECREMENT_SEED_RESERVED(sp::StackPointer, a, b, c)
    sp, SIMDPirates.fnmadd(a, b, c)
end
@inline function RESERVED_INCREMENT_SEED_RESERVED(sp::StackPointer, a, b)
    +(sp, a, b)
end
@inline function RESERVED_DECREMENT_SEED_RESERVED(sp::StackPointer, a, b)
    -(sp, b, a)
end

@inline RESERVED_MULTIPLY_SEED_RESERVED(sp::StackPointer, a) = sp, a
@inline function RESERVED_NMULTIPLY_SEED_RESERVED(sp::StackPointer, a)
    sp, -a
end

@inline function RESERVED_MULTIPLY_SEED_RESERVED(sp::StackPointer, a, b)
    *(sp, a, b)
end
@inline function RESERVED_NMULTIPLY_SEED_RESERVED(sp::StackPointer, a, b)
    *(sp, -a, b)
end

@inline function RESERVED_INCREMENT_SEED_RESERVED(sp::StackPointer, ::One, b, c)
    RESERVED_INCREMENT_SEED_RESERVED(sp, b, c)
end
@inline function RESERVED_DECREMENT_SEED_RESERVED(sp::StackPointer, ::One, b, c)
    RESERVED_DECREMENT_SEED_RESERVED(sp, b, c)
end

@inline RESERVED_MULTIPLY_SEED_RESERVED(sp::StackPointer, ::One, b) = (sp, b)
@inline RESERVED_NMULTIPLY_SEED_RESERVED(sp::StackPointer, ::One, b) = (sp, -b)

@inline function RESERVED_INCREMENT_SEED_RESERVED(sp::StackPointer, a, ::One, c)
    RESERVED_INCREMENT_SEED_RESERVED(sp, a, c)
end
@inline function RESERVED_DECREMENT_SEED_RESERVED(sp::StackPointer, a, ::One, c)
    RESERVED_DECREMENT_SEED_RESERVED(sp, a, c)
end

@inline RESERVED_INCREMENT_SEED_RESERVED(sp::StackPointer, ::One, b) = (sp, b)

@inline RESERVED_MULTIPLY_SEED_RESERVED(sp::StackPointer, ::One) = (sp, One())
@inline RESERVED_MULTIPLY_SEED_RESERVED(sp::StackPointer, a, ::One) = (sp,a)
@inline RESERVED_NMULTIPLY_SEED_RESERVED(sp::StackPointer, a, ::One) = (sp,-a)
@inline RESERVED_MULTIPLY_SEED_RESERVED(sp::StackPointer, ::One, ::One) = (sp, One())


