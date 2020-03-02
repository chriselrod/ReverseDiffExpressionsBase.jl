struct Target{W,T}
    v::NTuple{W,Core.VecElement{T}}
end
@inline Target() = Target(LoopVectorization.SIMDPirates.extract_data(LoopVectorization.vbroadcast(LoopVectorization.pick_vector_width_val(Float64), 0.0)))
@inline Target(::Type{T}) where {T} = Target(LoopVectorization.SIMDPirates.extract_data(LoopVectorization.vbroadcast(LoopVectorization.pick_vector_width_val(T), zero(T))))
@inline Base.:(+)(t::Target, s) = Target(LoopVectorization.addscalar(t.v, s))
@inline Base.:(+)(s, t::Target) = Target(LoopVectorization.addscalar(t.v, s))
@inline Base.:(+)(t::Target{WT,T}, v::LoopVectorization.SVec{WV,T}) where {WT,WV,T} = Target(LoopVectorization.vadd(t.v, LoopVectorization.SIMDPirates.extract_data(v)))
@inline Base.:(+)(t::Target{WT,T}, v::NTuple{WV,Core.VecElement{T}}) where {WT,WV,T} = Target(LoopVectorization.vadd(t.v, v))
@inline Base.:(+)(v::LoopVectorization.SVec{WV,T}, t::Target{WT,T}) where {WT,WV,T} = Target(LoopVectorization.vadd(t.v, LoopVectorization.SIMDPirates.extract_data(v)))
@inline Base.:(+)(v::NTuple{WV,Core.VecElement{T}}, t::Target{WT,T}) where {WT,WV,T} = Target(LoopVectorization.vadd(t.v, v))
@inline Base.:(+)(t₁::Target, t₂::Target) = Target(LoopVectorization.vadd(t₁.v, t₂.v))
@inline Base.sum(t::Target) = LoopVectorization.vsum(t.v)
@inline VectorizatrionBase.extract_data(t::Target) = t.v

