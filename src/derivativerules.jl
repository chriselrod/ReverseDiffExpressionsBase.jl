
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
sections = [ 1, 1, 2 ]
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
sections = [ 1,5,7,8 ]
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
sections = [ 1, 1, 7 ]
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
end

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
function Base.hash(ia::InstructionArgs, h)
    hash(ia.instr, hash(ia.num_args, h))
end
function Base.:(=)(ia1::InstructionArgs, ia2::InstructionArgs)
    instr1 = ia1.instr; instr2 = ia2.instr
    # Rough order of likelihood they differ
    instr1.instr === instr2.instr && ia1.num_args == ia2.num_args && instr1.mod === instr2.mod
end

const DERIVATIVERULES = Dict{InstructionArgs,DiffRule}()
# Sometimes we may want to drop additions and set equal to a value rather than update.
"""
Drop last argument to the function
"""
const NOADDITION = Dict{Instruction,Instruction}(
    Instruction(:+) => Instruction(:identity),
    Instruction(:vadd) => Instruction(:identity),
    Instruction(:vnsub) => Instruction(:vsub),
    Instruction(:muladd) => Instruction(:*),
    Instruction(:vmuladd) => Instruction(:vmul),
    Instruction(:vfma) => Instruction(:vmul),
    Instruction(:vfmadd) => Instruction(:vmul),
    Instruction(:vfmadd_fast) => Instruction(:vmul),
    Instruction(:vfnmadd) => Instruction(:vnmul),
    Instruction(:vfnmadd_fast) => Instruction(:vnmul)
)

for arity ∈ 2:8
    let deps = [ i == -2arity-1 ? collect(-arity:-1) : [0,i] for i ∈ -2arity-1:-arity-1 ], sections = [ (i<2?i+1:i):max(i,1) for i ∈ 0:arity+1 ], returns = collect(1:arity+1)
        for add ∈ (:+, :vadd, :evadd)
            instructions = fill(Instruction(:vadd), 1+arity);
            add === :vadd || (instructions[1] = Instruction(add))
            DERIVATIVERULES[InstructionArgs(add, arity)] = DiffRule(
                instructions, deps, sections, returns
            )
        end
    end
end
let deps = [ [-2, -1], [-1], [0,2,-4], [-2], [4,0,-3] ], sections = [ 1:1, 2:1, 2:3, 4:5], returns = [ 1, 3, 5 ]
    for mul ∈ (:*, :vmul, :evmul)
        DERIVATIVERULES[InstructionArgs(mul, 2)] = DiffRule(
            Instruction[ mul, :adjoint, :muladd, :adjoint, :muladd ],
            deps, sections, returns
        )
    end
end
let deps = [ [ -2,-1], [0,-4], [0,-3] ], sections = [1:1,2:1,2:2,3:3], returns = [1,2,3]
    for sub ∈ (:-, :vsub, :evsub)
        instructions = fill(Instruction(:vnsub), 3)
        instructions[1] = Instruction(sub)
        DERIVATIVERULES[InstructionArgs(sub,2)] = DiffRule(
            instructions, deps, sections, returns
        )
    end
end
let deps = [ [-2,-1], [-1], [0,2], [3,-4], [1], [4,3,-3] ], sections = [ 1:1, 2:3, 4:4, 5:6 ], returns = [1,4,6]
    for div ∈ (:/, :vfdiv)
        instructions = [ div, :adjoint, :vfdiv, :vadd, :adjoint, :vfnmadd_fast ]
        DERIVATIVERULES[InstructionArgs(sub,2)] = DiffRule(
            instructions, deps, sections, returns
        )
    end
end

# fmadd for the ∂ updates so compiler can elide zero-initialization
let deps = [ [-3, -2, -1], [-2], [0,2,-6], [-3], [4,0,-5], [0, -4] ], sections = [ 1:1, 2:1, 2:3, 4:5, 5:6 ], returns = [ 1, 3, 5, 6 ]
    for fma_instr ∈ (:muladd, :vmuladd, :vfma, :vfmadd, :vfmadd_fast)
        DERIVATIVERULES[InstructionArgs(fma_instr, 3)] = DiffRule(
            Instruction[ fma_instr, :adjoint, :vfmadd_fast, :adjoint, :vfmadd_fast, :vadd ],
            deps, sections
        )
    end
    for vfnmadd_instr ∈ (:vfnmadd, :vfnmadd_fast)
        DERIVATIVERULES[InstructionArgs(vfnmadd_instr, 3)] = DiffRule(
            Instruction[ vfnmadd_instr, :adjoint, :vfnmadd_fast, :adjoint, :vfnmadd_fast, :vadd ],
            deps, sections
        )
    end
    for vfmsub_instr ∈ (:vfmsub, :vfmsub_fast)
        DERIVATIVERULES[InstructionArgs(vfmsub_instr, 3)] = DiffRule(
            Instruction[ vfnmadd_instr, :adjoint, :vfmadd_fast, :adjoint, :vfmadd_fast, :vnsub ],
            deps, sections
        )
    end
    for vfnmsub_instr ∈ (:vfnmsub, :vfnmsub_fast)
        DERIVATIVERULES[InstructionArgs(vfnmsub_instr, 3)] = DiffRule(
            Instruction[ vfnmadd_instr, :adjoint, :vfnmadd_fast, :adjoint, :vfnmadd_fast, :vnsub ],
            deps, sections
        )
    end
end # let

DERIVATIVERULES[InstructionArgs(:exp, 1)] = DiffRule(
    Instruction[ :exp, :fmadd_fast ],
    [ [-1], [1,0,-2] ],
    [ 1:1, 2:1, 2:2 ],
    [ 1, 2 ]
)

DERIVATIVERULES[InstructionArgs(:atan, 2)] = DiffRule(
    Instruction[ :atan, :vabs2, :vfmadd_fast, :vfdiv, :vfnmadd_fast, :vfmadd_fast ],
    [ [-2,-1], [ -2 ], [-1,-1,1], [0,3], [-2,4,-4], [-1,4,-3] ],
    [ 1:1, 2:4, 5:5, 6:6 ],
    [ 1, 5, 6 ]
)


