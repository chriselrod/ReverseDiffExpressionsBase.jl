
using LoopVectorization: Instruction

"""
Contains a sequence of instructions and dependencies for each instruction.
Dependencies are vectors of integers, indicating all the arguments for the instruction.
Arguments ≥ 1 are intermediaries.
Arguments < 1 are inputs.

partials indicates the partial derivatives with respect to the inputs.
returnvalue indicates which value is returned.

A couple examples:

    exp(x)
instructions = [   exp,     *    ]
dependencies = [ [ -1 ], [ 1,0 ] ]
partials = [ 2 ]
returnvalue = 1

Means that we use the following instruction sequence for calculating the value and derivative of `y = exp(x)`:
%-1 = x
%0 = ∂y
%1 = exp(%-1)
%2 = %1 * %0

then `y = %1` and `∂x = %2`.

    atan(x, y)
instructions = [   atan,  abs2, abs2,  +,     /,      *,     -,    *   ]
dependencies = [ [-2,-1], [-2], [-1], [1,2], [0,4], [-1,5], [-2], [7,5] ]
partials = [ 8, 6 ]
returnvalue = 1

This corresponds to the following instruction sequence for `z = atan(x,y)`:
%-2 = x
%-1 = y
%0 = ∂z
%1 = atan(%-2, %-1)
%2 = abs2(%-2)
%3 = abs2(%-1)
%4 = %2 + %3
%5 = %0 / %4
%6 = %-1 * %5
%7 = - %-2
%9 = %7 * %5

With
z = %1
∂x = %8
∂y = %6

    sincos(x)
instructions = [ sincos, first,  last,    -,     *,     *,    tuple   ]
dependencies = [ [ -1 ],  [ 1 ], [ 1 ], [ 2 ], [3,0], [4,0], [ 3, 4 ] ]
partials = [ 7 ]
returnvalue = 1

For `y = sincos(x)`
%-1 = x
%0 = ∂y
%1 = sincos(x)
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
    partials::Vector{NTuple{Int}}
    returnvalue::Int
end

struct InstructionArgs
    instr::Instruction
    args::UInt
    argcount::Int
end
function InstructionArgs(instr::Instruction, args)
    uargs = zero(UInt)
    for b ∈ args
        uargs <<= 1
        uargs |= b
    end
    InstructionArgs(instr, uargs, length(args))
end
InstructionArgs(instr::Symbol, args) = InstructionArgs(Instruction(instr), args)
function Base.hash(ia::InstructionArgs, h)
    hash(ia.instr, hash(ia.argcount, hash(ia.args, h)))
end
function Base.:(=)(ia1::InstructionArgs, ia2::InstructionArgs)
    instr1 = ia1.instr; instr2 = ia2.instr
    # Rough order of likelihood they differ
    instr1.instr === instr2.instr || return false
    ia1.argcount == ia2.argcount || return false
    ia1.args == ia2.args || return false
    instr1.mod === instr2.mod
end

const DERIVATIVERULES = Dict{InstructionArgs,DiffRule}()

let
    global DERIVATIVERULES
    OneInstr = Instruction(:ReverseDiffExpressionsBase, :One)
    ZeroInstr = Instruction(:ReverseDiffExpressionsBase, :Zero)
    for arity ∈ 2:8
        DERIVATIVERULES[InstructionArgs(:+, typemax(UInt), arity)] = DiffRule( Instruction[ :+ ], [ collect(-arity:-1) ], zeros(Int, arity), 1 )
    end
    mulrule = DiffRule(
        Instruction[ :*, :Adjoint, :*, :Adjoint, :* ],
        [ [-2, -1], [-1], [0,2], [-2], [4,0] ],
        [ 3, 5 ]
        1
    )
    DERIVATIVERULES[InstructionArgs(:*, (true,true))] = mulrule
    mulrule = DiffRule(
        Instruction[ :*, :Adjoint, :* ],
        [ [-2, -1], [-1], [0,2] ],
        [ 3 ]
        1
    )
    DERIVATIVERULES[InstructionArgs(:*, (true,false))] = mulrule
    mulrule = DiffRule(
        Instruction[ :*, :Adjoint, :* ],
        [ [-2, -1], [-2], [2,0] ],
        [ 3 ]
        1
    )
    DERIVATIVERULES[InstructionArgs(:*, (false,true))] = mulrule

    muladdrule = DiffRule(
        Instruction[ :muladd, :Adjoint, :*, :Adjoint, :*, :Adjoint, :* ],
        [ [-2, -1], [-2], [2,0] ],
        [ 3, 5, 0 ]
        1
    )
    DERIVATIVERULES[InstructionArgs(:*, (true,true,true))] = mulrule

    
    plusrule = DiffRule(
        Instruction[ :+, OneInstr, OneInstr ],
        [ [-1, 0], Int[] ],
        [ 2, ]
        1        
    )
    DERIVATIVERULES[InstructionArgs(:+, (false,true))] = plusrule
    DERIVATIVERULES[InstructionArgs(:+, (true,false))] = plusrule

    
end #let

