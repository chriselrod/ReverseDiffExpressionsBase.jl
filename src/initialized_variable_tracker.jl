# Consider tuple case: out = (a1, a2, a3); how to properly record which has been initialized?
# Defined as an alias rather than wrapper.
struct InitializedVarTracker
    aliases::Dict{Symbol,Vector{Vector{Symbol}}}
    initialized::Set{Symbol}
    uninitialized::Set{Symbol}
end
InitializedVarTracker() = InitializedVarTracker(Dict{Symbol,Vector{Vector{Symbol}}}(), Set{Symbol}())

isinitialized(ivt::InitializedVarTracker, s::Symbol) = s ∈ ivt.initialized

function add_aliases!(ivt::InitializedVarTracker, a::Symbol, b::Symbol)
    if a ∈ ivt.initialized
        push!(ivt.initialized, b)
    elseif b ∈ ivt.initialized
        push!(ivt.initialized, a)
    end
    push!(get!(() -> Vector{Symbol}[], ivt.aliases, a), [b])
    push!(get!(() -> Vector{Symbol}[], ivt.aliases, b), [a])
    nothing
end
function add_aliases!(ivt::InitializedVarTracker, a::Symbol, B::Vector{Symbol})
    #A is a collection, aliasing all members of B
    if a ∈ ivt.initialized
        for b ∈ B
            push!(ivt.initialized, b)
        end
    elseif all(b -> b ∈ ivt.initialized, B)
        push!(ivt.initialized, a)
    end
    push!( get!(() -> Vector{Symbol}[], ivt.aliases, a),  B )
    for b ∈ B
        push!(get!(() -> Vector{Symbol}[], ivt.aliases, b), [Symbol("####AGGREGATE####"), a])
    end
    nothing
end
function add_aliases!(ivt::InitializedVarTracker, a::Symbol, B)
    Bsyms = Symbol[s for s ∈ B if s isa Symbol]
    add_aliases!(ivt, a, Bsyms)
end

"""
Return value indicates whether it must uninitialize arg
"""
function initialize!(ivt::InitializedVarTracker, pass::Vector{Any}, root::Symbol, skip::Symbol, mod::Symbol)
    root ∈ ivt.initialized && return false
    push!(ivt.initialized, root)
    root ∈ keys(ivt.aliases) || return true
    must_declare_uninitialized = true
    # We're traversing a diverging tree. We just have to move through all branches of each node and avoid back tracking.
    # Each node can only map to up to 1 collection of components.
    # ie, if it is declared a collection of one set, it cannot then be declared of another set.
    for alias ∈ ivt.aliases[root]
        a = first(alias)
        if length(alias) == 1
            if a !== skip
                must_declare_uninitialized &= initialize!(ivt, pass, a, root, mod)
            end
        else
            if a === Symbol("####AGGREGATE####")
                # then rooot is a member of collection A, corresponding specifically to that found in alias[3]
                A = alias[2]
                if A !== skip
                    init = false
                    for aalias ∈ ivt.aliases[A]
                        if root ∈ aalias
                            init = all(s -> s ∈ ivt.initialized, ivt.aliases[A])
                            break
                        end
                    end
                    if init
                        must_declare_uninitialized &= initialize!(ivt, pass, A, root, mod)
                    end
                end
            else # root is a collection
                # Check if we're supposed to skip
                any(s -> s === skip, alias) && continue
                if any(s -> s ∈ ivt.initialized, alias)
                    must_declare_uninitialized = false
                    for a ∈ alias
                        if a ∉ ivt.initialized
                            push!(pass, :($mod.zero_initialize!($a)))
                            initialize!(ivt, pass, a, root, mod)
                        end
                    end
                else# all must be uninitialized
                    for a ∈ alias
                        must_declare_uninitialized &= initialize!(ivt, pass, a, root, mod)
                    end
                end
            end
        end
    end
    must_declare_uninitialized
end

function uninitialize!(ivt::InitializedVarTracker, pass::Vector{Any}, root::Symbol, skip::Symbol, mod::Symbol)
    push!(ivt.uninitialized, root)
    # if any aliases are not uninitialized, we cannot endlife.
    # So we search aliases to see if any are still live.
    # if there are no aliases, we can go ahead and return true
    root ∈ keys(ivt.aliases) || return true
    # If any alias is not uninitialized, we return false
    for alias ∈ ivt.aliases[root]
        for a ∈ alias
            search_for_uninitialized!(ivt, a, root) || return false
        end
    end
    true
end
function search_for_uninitialized!(ivt, root::Symbol, skip::Symbol)
    root ∈ ivt.uninitialized || return false
    # if not uninitialized, we go ahead and abort

    # We're traversing a diverging tree. We just have to move through all branches of each node and avoid back tracking.
    # Each node can only map to up to 1 collection of components.
    # ie, if it is declared a collection of one set, it cannot then be declared of another set.
    for alias ∈ ivt.aliases[root]
        a = first(alias)
        if length(alias) == 1
            if a !== skip
                search_for_uninitialized!(ivt, a, root) || return false
            end
        else
            if first(alias) === Symbol("####AGGREGATE####")
                # then rooot is a member of collection A
                A = alias[2]
                if A !== skip
                    search_for_uninitialized!(ivt, A, root) || return false
                end
            else # root is a collection
                for a ∈ alias
                    if a !== skip
                        search_for_uninitialized!(ivt, a, root) || return false
                    end
                end
            end
        end
    end
    true
end


