module HotTest

import Pkg
import MacroTools
import TestEnv: activate

export activate

function test(file = "test/runtests.jl"; filter = nothing, verbose = false)
    Sandbox = Module(:Sandbox)
    Core.eval(Sandbox, quote
        eval(x) = Core.eval($Sandbox, x)
        include(f, str) = Base.include(f, $Sandbox, str)
        include(str) = Base.include($Sandbox, str)
    end)

    function transform_filtered(exp)
        transform_source(exp, filter, file, 1; verbose)
    end

    expr = :(include($transform_filtered, $file))
    Core.eval(Sandbox, expr)
end

function list(file = "test/runtests.jl")
    exp = parsecode(read(file, String), file)
    exp = transform_source(exp, nothing, file, 1; verbose = false)
    print_testsets(exp, 1)
end

function print_testsets(exp::Expr, level)
    if MacroTools.@capture exp @testset name_ block_
        println(" " ^ (2 * (level-1)), repr(name))
        print_testsets(block, level + 1)
    else
        for arg in exp.args
            print_testsets(arg, level)
        end
    end
end

print_testsets(x, level) = nothing

macro hottest_testset(name, block)
    quote
        @testset $name $block
    end
end

evaluate_filter(filter::Nothing, name) = true

function evaluate_filter(filter::Regex, name)
    match(filter, name) !== nothing
end

function evaluate_filter(filter::Tuple, name, level)
    if level > length(filter)
        return false
    end
    evaluate_filter(filter[level], name)
end

evaluate_filter(filter, name, level) = evaluate_filter(filter, name)

function parsecode(code::String, sourcefile)
    expr = Meta.parse(join(["begin", code, "end"], ";"))
    # for @__DIR__ and @__FILE__ to work, the LineNumberNodes have to
    # be populated with the file path from which the code was read
    MacroTools.postwalk(expr) do x
        if x isa LineNumberNode
            LineNumberNode(x.line, sourcefile)
        else
            x
        end
    end
end

function transform_source(expr::Expr, filter, file, level; verbose)

    # directly resolve include("path.jl") so that we can check for nested testsets

    expr = MacroTools.prewalk(expr) do ex
        ex = if MacroTools.@capture ex include(x_)
            if x isa String
                include_file = normpath(joinpath(dirname(file), x))
                parsecode(read(include_file, String), include_file)
            else
                @warn "Can't resolve dynamic include expression $ex"
                ex
            end
        else
            ex
        end
    end

    expr = transform_testset_expressions(expr, level; verbose, filter)

    expr
end

function transform_testset_expressions(ex::Expr, level; verbose, filter)
    if MacroTools.@capture ex @testset(name_, block_)
        # transform testsets with for loops such that the loop goes to the outside
        if MacroTools.isexpr(block, :for)
            inner_block = block.args[2]
            inner_block_transformed = transform_testset_expressions(inner_block, level + 1; filter, verbose)
            Expr(:for, block.args[1], quote
                if $evaluate_filter($filter, $name, $level)
                    @testset $name $inner_block_transformed
                else
                    @static if $verbose
                        @info "$($name) skipped"
                    end
                end
            end)
        else
            block_transformed = transform_testset_expressions(block, level + 1; filter, verbose)
            quote
                if $evaluate_filter($filter, $name, $level)
                    @testset $name $block_transformed
                else
                    @static if $verbose
                        @info "$($name) skipped"
                    end
                end
            end
        end
    else
        Expr(ex.head, [transform_testset_expressions(arg, level; filter, verbose) for arg in ex.args]...)
    end
end

transform_testset_expressions(other, level; filter, verbose) = other

transform_source(x, filter, file, level; verbose) = x

end
