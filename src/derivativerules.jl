
using LoopVectorization: Instruction

"""
Contains a sequence of instructions and dependencies for each instruction.
Dependencies are vectors of integers, indicating all the arguments for the instruction.
Arguments ≥ 1 are intermediaries.
Argument 0 is the gradient with respect to the output
Arguments -N,...,-1 are the inputs
Arguments -2N,...,-N-1 are the gradients with respect to inputs, for use with updating operations (zero-initialized is common case)


Sections are:
1: End first pass block
2: End shared second pass block
2+1,...,2+n,...,2+N: End block for argument n

Returns:
1: return value of function
1+1,...,1+n,...,1+N: return value for gradient with respect to argument n

A few examples:

    exp(x)
instructions = [   :exp,     :fmadd    ]
dependencies = [ [ -1 ], [ 1,0,-2 ] ]
sections = [ 1:1, 2:1, 2:2 ]
returns  = [ 1, 2 ]

Means that we use the following instruction sequence for calculating the value and derivative of `y = exp(x)`:
# definitions
%-1 = x
%0 = ∂y
# first pass
%1 = exp(%-1)
# shared
# calc ∂x
%2 = %1 * %0

then `y = %1` and `∂x = %2`.

    atan(x, y)
instructions = [   atan,  abs2, abs2,   +,     /,     -,    *,      *   ]
dependencies = [ [-2,-1], [-2], [-1], [1,2], [0,4], [-2], [7,5], [-1,5] ]
sections = [ 1:1, 2:5, 6:7, 8:8 ]
returns = [ 1, 7, 8 ]


This corresponds to the following instruction sequence for `z = atan(x,y)`:
# definitions
%-2 = x
%-1 = y
%0 = ∂z
# first pass
%1 = atan(%-2, %-1)
# shared
%2 = abs2(%-2)
%3 = abs2(%-1)
%4 = %2 + %3
%5 = %0 / %4
# calc ∂x
%6 = - %-2
%7 = %6 * %5
# calc ∂y
%8 = %-1 * %5

With
z = %1
∂x = %7
∂y = %8

    sincos(x)
instructions = [ sincos, first,  last,    -,     *,     *,    tuple   ]
dependencies = [  [-1],  [ 1 ], [ 1 ], [ 2 ], [3,0], [4,0], [3, 4] ]
sections = [ 1:1, 2:1, 2:7 ]
returns = [ 1, 7 ]

For `y = sincos(x)`
# definitions
%-1 = x
%0 = ∂y
# first pass
%1 = sincos(x)
# shared
# calc ∂x
%2 = first(%1)
%3 = last(%1)
%4 = -%2
%5 = %3 * %0
%6 = %4 * %0
%7 = tuple( %5, %6 )


"""
struct DiffRule
    instructions::Vector{Instruction}
    dependencies::Vector{Vector{Int}}
    sections::Vector{UnitRange{Int}}
    returns::Vector{Int}
    num_parents::Int
end

LoopVectorization.instruction(dr::DiffRule, i::Int) = dr.instructions[i]
dependencies(dr::DiffRule, i::Int) = dr.dependencies[i]

struct InstructionArgs
    instr::Instruction
    num_args::Int
end
# function InstructionArgs(instr::Instruction, args)
    # uargs = zero(UInt)
    # for b ∈ args
        # uargs <<= 1
        # uargs |= b
    # end
    # InstructionArgs(instr, uargs, length(args))
# end
# InstructionArgs(instr::Symbol, num_args) = InstructionArgs(Instruction(instr), args)
num_parents(dr::DiffRule) = dr.num_parents
section_two_returns(dr::DiffRule) = length(dr.sections) == length(dr.returns)
function Base.hash(ia::InstructionArgs, h::UInt)
    hash(ia.instr, hash(ia.num_args, h))
end
function Base.:(==)(ia1::InstructionArgs, ia2::InstructionArgs)
    instr1 = ia1.instr; instr2 = ia2.instr
    # Rough order of likelihood they differ
    instr1.instr === instr2.instr && ia1.num_args == ia2.num_args && instr1.mod === instr2.mod
end

const DERIVATIVERULES = Dict{InstructionArgs,DiffRule}()
# Sometimes we may want to drop additions and set equal to a value rather than update.
# """
# Drop last argument to the function
# """
# const NOADDITION = Dict{Instruction,Instruction}(
#     Instruction(:+) => Instruction(:identity),
#     Instruction(:vadd) => Instruction(:identity),
#     Instruction(:vnsub) => Instruction(:vsub),
#     Instruction(:muladd) => Instruction(:*),
#     Instruction(:vmuladd) => Instruction(:vmul),
#     Instruction(:vfma) => Instruction(:vmul),
#     Instruction(:vfmadd) => Instruction(:vmul),
#     Instruction(:vfmadd_fast) => Instruction(:vmul),
#     Instruction(:vfnmadd) => Instruction(:vnmul),
#     Instruction(:vfnmadd_fast) => Instruction(:vnmul),
#     Instruction(:vmullog2add) => Instruction(:vmullog2),
#     Instruction(:vmullog10add) => Instruction(:vmullog10),
#     Instruction(:vdivlog2add) => Instruction(:vdivlog2),
#     Instruction(:vdivlog10add) => Instruction(:vdivlog10)
# )
# To support mutating and non-mutating APIs.
# Generated code should be SAC-style
const MAKEUPDATING = Dict{Instruction,Instruction}(
    Instruction(:identity) => Instruction(:vadd!),
    Instruction(:vsub) => Instruction(:vsub!),
    Instruction(:*) => Instruction(:vfmadd!),
    Instruction(:vmul) => Instruction(:vfmadd!),
    Instruction(:vnmul) => Instruction(:vfnmadd!),
    Instruction(:vmullog2) => Instruction(:vmullog2add!),
    Instruction(:vmullog10) => Instruction(:vmullog10add!),
    Instruction(:vdivlog2) => Instruction(:vdivlog2add!),
    Instruction(:vdivlog10) => Instruction(:vdivlog10add!)
)
const MAKEINPLACE = Dict{Instruction,Instruction}(
    Instruction(:*) => Instruction(:mul!),
    Instruction(:vmul) => Instruction(:mul!),
    Instruction(:vnmul) => Instruction(:nmul!)
)


for arity ∈ 2:8
    let sections = [ i > 1 ? (i:i) : (i+1):1 for i ∈ 0:arity+1 ], returns = collect(1:arity+1), deps = [ iszero(i) ? collect(-arity:-1) : [0] for i in 0:arity ]
        for add ∈ [:+, :vadd, :evadd]
            instructions = Instruction[ iszero(i) ? Instruction(add) : Instruction(:identity) for i ∈ 0:arity ]
            DERIVATIVERULES[InstructionArgs(add, arity)] = DiffRule(
                instructions, deps, sections, returns, arity
            )
        end
    end
    # let sections = [ 1:1, 2:1 ], returns = [ iszero(i) ? 1 : i - 1 - 2arity for i ∈ 0:arity ]
    #     DERIVATIVERULES[InstructionArgs(:logdensity, arity)] = DiffRule(
    #         [ :∂logdensity! ], deps, sections, returns, arity
    #     )
    # end
end
let deps = [ [-2, -1], [-1], [0,2], [-2], [4,0] ], sections = [ 1:1, 2:1, 2:3, 4:5], returns = [ 1, 3, 5 ]
    for mul ∈ [:*, :vmul, :evmul]
        DERIVATIVERULES[InstructionArgs(mul, 2)] = DiffRule(
            Instruction[ mul, :adjoint, :vmul, :adjoint, :vmul ],
            deps, sections, returns, 2
        )
    end
end
let deps = [ [ -2,-1], [0], [0] ], sections = [1:1,2:1,2:2,3:3], returns = [1,2,3]
    for sub ∈ [:-, :vsub, :evsub]
        instructions = fill(Instruction(:vsub), 3)
        instructions[1] = Instruction(sub)
        DERIVATIVERULES[InstructionArgs(sub,2)] = DiffRule(
            instructions, deps, sections, returns, 2
        )
    end
end
let deps = [ [-2,-1], [-1], [0,2], [1], [4,3,-3] ], sections = [ 1:1, 2:3, 4:3, 4:5 ], returns = [1,3,5]
    for div ∈ [:/, :vfdiv]
        instructions = [ div, :adjoint, :vfdiv, :adjoint, :vnmul ]
        DERIVATIVERULES[InstructionArgs(div,2)] = DiffRule(
            instructions, deps, sections, returns, 2
        )
    end
end

# fmadd for the ∂ updates so compiler can elide zero-initialization
let deps = [ [-3, -2, -1], [-2], [0,2], [-3], [4,0] ], sections = [ 1:1, 2:1, 2:3, 4:5, 6:5 ], returns = [ 1, 3, 5, 0 ]
    for fma_instr ∈ [:muladd, :fma, :vmuladd, :vfma, :vfmadd, :vfmadd_fast]
       # fma_instr2 = :vfmadd_fast
        DERIVATIVERULES[InstructionArgs(fma_instr, 3)] = DiffRule(
            Instruction[ fma_instr, :adjoint, :vmul, :adjoint, :vmul ],
            deps, sections, returns, 3
        )
    end
    for vfnmadd_instr ∈ [:vfnmadd, :vfnmadd_fast]
        # fnmaadd_instr2 = :vfnmadd_fast
        DERIVATIVERULES[InstructionArgs(vfnmadd_instr, 3)] = DiffRule(
            Instruction[ vfnmadd_instr, :adjoint, :vnmul, :adjoint, :vnmul ],
            deps, sections, returns, 3
        )
    end
end
let deps = [ [-3, -2, -1], [-2], [0,2], [-3], [4,0], [0] ], sections = [ 1:1, 2:1, 2:3, 4:5, 6:6 ], returns = [ 1, 3, 5, 6 ]
    for vfmsub_instr ∈ [:vfmsub, :vfmsub_fast]
        # fmadd = vfmsub_instr === :vfmsub ? :vfmadd : :vfmadd_fast
        DERIVATIVERULES[InstructionArgs(vfmsub_instr, 3)] = DiffRule(
            Instruction[ vfmsub_instr, :adjoint, :vmul, :adjoint, :vmul, :vsub ],
            deps, sections, returns, 3
        )
    end
    for vfnmsub_instr ∈ [:vfnmsub, :vfnmsub_fast]
        # fnmadd = vfnmsub_instr === :vfnmsub ? :vfnmadd : :vfnmadd_fast
        # fnmadd = :vfnmadd_fast
        DERIVATIVERULES[InstructionArgs(vfnmsub_instr, 3)] = DiffRule(
            Instruction[ vfnmsub_instr, :adjoint, :vnmul, :adjoint, :vnmul, :vsub ],
            deps, sections, returns, 3
        )
    end
end # let


DERIVATIVERULES[InstructionArgs(:exp, 1)] = DiffRule(
    Instruction[ :exp, :vmul ],
    [ [-1], [1,0] ],
    [ 1:1, 2:1, 2:2 ],
    [ 1, 2 ],
    1
)
DERIVATIVERULES[InstructionArgs(:expm1, 1)] = DiffRule(
    Instruction[ :expm1, :vadd1, :vmul ],
    [ [-1], [1], [2,0] ],
    [ 1:1, 2:1, 2:3 ],
    [ 1, 3 ],
    1
)
DERIVATIVERULES[InstructionArgs(:exp2, 1)] = DiffRule(
    Instruction[ :exp, :vmullog2, :vmul ],
    [ [-1], [1], [2,0] ],
    [ 1:1, 2:1, 2:3 ],
    [ 1, 3 ],
    1
)
DERIVATIVERULES[InstructionArgs(:exp10, 1)] = DiffRule(
    Instruction[ :exp, :vmullog10, :vmul ],
    [ [-1], [1], [2,0] ],
    [ 1:1, 2:1, 2:3 ],
    [ 1, 3 ],
    1
)


for sq ∈ [:sqrt, :vsqrt]
    DERIVATIVERULES[InstructionArgs(sq, 1)] = DiffRule(
        Instruction[ sq, :vadd, :vfdiv ],
        [ [-1], [1,1], [0,2] ],
        [ 1:1, 2:1, 2:3 ],
        [ 1, 3 ],
        1
    )
end
for cb ∈ [:cbrt, :cbrt_fast]
    DERIVATIVERULES[InstructionArgs(cb,1)] = DiffRule(
        Instruction[ cb, :vabs2, :vmul3, :vfdiv ],
        [ [-1], [1], [2], [0,3] ],
        [ 1:1, 2:1, 2:4 ],
        [ 1, 4 ],
        1
    )
end

for ln ∈ [:log, :log_fast, :vlog]
    DERIVATIVERULES[InstructionArgs(ln,1)] = DiffRule(
        Instruction[ ln, :vfdiv ],
        [ [-1], [0,-1] ],
        [ 1:1, 2:1, 2:2 ],
        [ 1, 2 ],
        1
    )
end
for (ln, comb) ∈ [(:log2,Instruction(:vmullog2)), (:log10,Instruction(:vmullog10))]
    DERIVATIVERULES[InstructionArgs(ln,1)] = DiffRule(
        Instruction[ ln, :vfdiv, comb ],
        [ [-1], [0,-1], [2] ],
        [ 1:1, 2:1, 2:3 ],
        [ 1, 3 ],
        1
    )
end

DERIVATIVERULES[InstructionArgs(:log1p,1)] = DiffRule(
    Instruction[ :log1p, :vadd1, :vfdiv ],
    [ [-1], [-1], [0, 2] ],
    [ 1:1, 2:1, 2:3 ],
    [ 1, 3 ],
    1
)

for p ∈ [:^, :pow]
    DERIVATIVERULES[InstructionArgs(p,2)] = DiffRule(
        Instruction[ :log, :vmul, :exp, :vfdiv, :vmul, :vmul ],
        [ [-2], [1,-1], [2], [-1,-2], [4,0], [3,0] ],
        [ 1:3, 4:3, 4:5, 6:6 ],
        [ 3, 5, 6 ],
        2
    )
end

DERIVATIVERULES[InstructionArgs(:sin,1)] = DiffRule(
    Instruction[ :sincos, :first, :last ],
    [ [-1], [1], [1] ],
    [ 1:3, 4:3, 4:3 ],
    [ 2, 3 ],
    1
)
DERIVATIVERULES[InstructionArgs(:cos,1)] = DiffRule(
    Instruction[ :sincos, :first, :last, :vsub ],
    [ [-1], [1], [1], [2] ],
    [ 1:3, 4:3, 4:4 ],
    [ 3, 4 ],
    1
)

DERIVATIVERULES[InstructionArgs(:tan,1)] = DiffRule(
    Instruction[ :tan, Instruction(:vfmaddaddone), :vmul ],
    [ [-1], [1], [2,0] ],
    [ 1:1, 2:1, 2:3 ],
    [ 1, 3 ],
    1
)
DERIVATIVERULES[InstructionArgs(:cot,1)] = DiffRule(
    Instruction[ :cot, Instruction(:vfmaddaddone), :vnmul ],
    [ [-1], [1], [2,0] ],
    [ 1:1, 2:1, 2:3 ],
    [ 1, 3 ],
    1
)

DERIVATIVERULES[InstructionArgs(Instruction(:DistributionParameters,:constrain),3)] = DiffRule(
    # Args are θ, descript
    # caller should calc gep(θ, offset) 
    Instruction[ :constrain_pullback, :first, :last, :constrain_reverse! ],
    [ [-3, -2, -1], [1], [1], [0, 3, -1] ],
    [ 1:2, 3:2, 3:4, 5:4, 5:4 ],
    [ 2, 4, 0, 0 ],
    3
)

DERIVATIVERULES[InstructionArgs(:identity,1)] = DiffRule(
    Instruction[ :identity, :identity ],
    [ [-1], [0] ],
    [ 1:1, 2:1, 2:2 ],
    [ 1, 2 ],
    1
)

for f ∈ [:abs2, :vabs2]
    DERIVATIVERULES[InstructionArgs(f,1)] = DiffRule(
        Instruction[ f, :vadd, :vmul ],
        [ [-1], [-1,-1], [2,0] ],
        [ 1:1, 2:1, 2:3 ],
        [ 1, 3 ],
        1
    )
end
for at ∈ [:atan, :atan_fast]
    DERIVATIVERULES[InstructionArgs(at, 2)] = DiffRule(
        Instruction[ at, :vabs2, :vfmadd_fast, :vfdiv, :vnmul, :vmul ],
        [ [-2,-1], [ -2 ], [-1,-1,1], [0,3], [-2,4], [-1,4] ],
        [ 1:1, 2:4, 5:5, 6:6 ],
        [ 1, 5, 6 ],
        2
    )
end

@inline callunthunk(f::F, x) where {F} = f(unthunk(x))
const FALLBACK_RULES = Vector{DiffRule}(undef, 8);
let getters = [:second, :third, :fourth, :fifth, :sixth, :seventh, :eighth, :ninth]
    for i ∈ 1:8
        # Special case `rrule` in handling to add func?
        FALLBACK_RULES[i] = DiffRule( 
            Instruction[:rrule, :first, :last, :callunthunk, (getters[1:i])...],
            [ collect(-i:-1), [1], [1], [3, 0], ([4] for _ ∈ 1:i)... ],
            [ 1:2, 3:4, (j:j for j ∈ 5:i+4)... ],
            [ 2, 4, (j for j ∈ 5:i+4)... ],
            i
        )
    end
end
              

