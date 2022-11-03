# HotTest.jl - Keep your tests hot!

[![Build Status](https://github.com/jkrumbiegel/HotTest.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/jkrumbiegel/HotTest.jl/actions/workflows/CI.yml?query=branch%3Amain)

Using `]test` (or `Pkg.test()`) in Julia can be annoying, because each run starts a new Julia session.
That means compilation delays, and you don't want to wait long while testing to keep feedback loops short.

Another drawback of `]test` is that it always runs all tests specified in `test/runtests.jl`.
This means that even if the delay until the tests start isn't that long, you will have to wait until all tests were successfully completed.

HotTest.jl is an **experimental** package which works in conjunction with Julia's default testing pipeline in Pkg.jl.
The tests are run in a sandbox module in the current session, this means that compilation delays only matter for the first run, but each run is still independent from session state.
Rerunning the tests afterwards should be quick.

Also, HotTest.jl can filter out testsets by name using regular expressions, so you can choose to run only a subset of them, shortening your waiting periods further.
This also works for nested testsets.

## Example code

First, you need to activate a test environment so that the tests' dependencies can be loaded correctly.
HotTest.jl reexports `TestEnv.activate()` for this purpose:

```julia
using HotTest
# you should be cd'ed into the package's root directory that you want to test
HotTest.activate()

# run all tests in `test/runtests.jl`
HotTest.test()

# run all tests in a manually specified location
HotTest.test("path_to/some_file.jl")

# only run testsets with `xyz` in their title
HotTest.test(; filter = r"xyz")

# specify filters for levels of nested testsets using a tuple.
# the `nothing` filter accepts any title.
HotTest.test(; filter = (r"abc", nothing, r"xyz"))
```

## Example video

Here is a screen recording of a session in which I use HotTest.jl to run some tests of GridLayoutBase.jl.

https://user-images.githubusercontent.com/22495855/199820250-dbbaed99-035c-4a65-bce8-9c55d626839b.mov

## How it works

The code in `test/runtests.jl` is included after applying a transformation function to each
expression.
This function replaces all occurrences of `@testset` macros with `if else` statements
which only allow the testsets to run if their names match the filter.

In order to be able to correctly transform and match nested testsets, any occurrence of
`include("some_file.jl")` is resolved immediately at parse time and replaced with the code it references.
This means that HotTest.jl can only work correctly if there are no _dynamic_ `include` statements.
Currently, only string literals inside `include` are accepted.
