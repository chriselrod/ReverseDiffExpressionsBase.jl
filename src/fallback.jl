
"""
```
function ∂evaluate(::Val{track}, f::F, args...) where {track, F}
end
```

To add direct support to ProbabilityModels for differentiating a function, you need to extend ∂evaluate to add an appropriate method of the signature:

`∂evaluate(::Val{track}, f::typeof(extendedfunction), args...)`

returning the tuple:

`f(args...), ∇`

where `∇` is a callable object (eg, an anonymous function or a callable user defined struct) such that
∇(x̄)
returns a gradient (`length(args)==1`) or a tuple of the gradients with respect to the args, where `x̄` contains the gradient with respect to `f(args...)`.

`track` is a N-tuple of booleans, indicating whether the `n`-th argument is being tracked. The gradients where `track==false` are ignored; it may be possible
to use that information to save on computation time, although if `∇` are lazy or everything gets inlined so the compiler can DCE unused results, it may be able
to avoid that computation regardless.
"""
function ∂evaluate end

