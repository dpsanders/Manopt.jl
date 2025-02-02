# # [Get started: Optimize!](@id Optimize)
#
# This example illustrates how to set up and solve optimization problems and how
# to further get data from the algorithm using [`DebugOptions`](@ref) and
# [`RecordOptions`](@ref). We will use the Riemannian mean and median as simple examples.
#
# To start from the quite general case: A __Solver__ is an algorithm that aims
# to solve
#
# $\operatorname*{argmin}_{x∈\mathcal M} f(x)$
#
# where $\mathcal M$ is a [Manifold](https://juliamanifolds.github.io/Manifolds.jl/stable/interface.html#ManifoldsBase.Manifold) and
# $f:\mathcal M → ℝ$ is the cost function.
#
# In `Manopt.jl` a __Solver__ is an algorithm that requires a [`Problem`](@ref)
# `p` and [`Options`](@ref) `o`. While former contains __static__ data,
# most prominently the manifold $\mathcal M$ (usually as `p.M`) and the cost
# function $f$ (usually as `x->get_cost(p, x)`), the latter contains __dynamic__
# data, i.e. things that usually change during the algorithm, are allowed to
# change, or specify the details of the algorithm to use. Together they form a
# `plan`. A `plan` uniquely determines the algorithm to use and provide all
# necessary information to run the algorithm.
#
# ## Example
#
# A gradient plan consists of a [`GradientProblem`](@ref) with the fields `M`,
# cost function $f$ as well as `gradient` storing the gradient function
# corresponding to $f$. Accessing both functions can be done directly but should
# be encapsulated using [`get_cost`](@ref)`(p,x)` and [`get_gradient`](@ref)`(p,x)`,
# where in both cases `x` is a point on the [Manifold](https://juliamanifolds.github.io/Manifolds.jl/stable/interface.html#ManifoldsBase.Manifold) `M`.
# Second, the [`GradientDescentOptions`](@ref) specify that the algorithm to solve
# the [`GradientProblem`](@ref) will be the [gradient
# descent](https://en.wikipedia.org/wiki/Gradient_descent) algorithm. It requires
# an initial value `o.x0`, a [`StoppingCriterion`](@ref) `o.stop`, a
# [`Stepsize`](@ref) `o.stepsize` and a retraction `o.retraction` and it
# internally stores the last evaluation of the gradient at `o.gradient` for convenience.
# The only mandatory parameter is the initial value `x0`, though the defaults for
# both the stopping criterion ([`StopAfterIteration`](@ref)`(100)`) as well as the
# stepsize ([`ConstantStepsize`](@ref)`(1.)` are quite conservative, but are
# chosen to be as simple as possible.
#
# With these two at hand, running the algorithm just requires to call `x_opt = solve(p,o)`.
#
# In the following two examples we will see, how to use a higher level interface
# that allows to more easily activate for example a debug output or record values during the iterations
#
# ## The given Dataset
#
export_folder = joinpath( #src
    @__DIR__, #src
    "..", #src
    "..", #src
    "docs", #src
    "src", #src
    "assets", #src
    "images", #src
    "tutorials", #src
) #src
using Manopt, Manifolds
using Random, Colors
# For a persistent random set we use
n = 100
σ = π / 8
M = Sphere(2)
x = 1 / sqrt(2) * [1.0, 0.0, 1.0]
Random.seed!(42)
data = [exp(M, x, random_tangent(M, x, Val(:Gaussian), σ)) for i in 1:n]
nothing #hide
# and we define some colors from [Paul Tol](https://personal.sron.nl/~pault/)
black = RGBA{Float64}(colorant"#000000")
TolVibrantOrange = RGBA{Float64}(colorant"#EE7733")
TolVibrantBlue = RGBA{Float64}(colorant"#0077BB")
TolVibrantTeal = RGBA{Float64}(colorant"#009988")
TolVibrantMagenta = RGBA{Float64}(colorant"#EE3377")
nothing #hide
#
# Then our data rendered using [`asymptote_export_S2_signals`](@ref) looks like
#
asymptote_export_S2_signals( #src
    export_folder * "/startDataAndCenter.asy"; #src
    points=[[x], data], #src
    colors=Dict(:points => [TolVibrantBlue, TolVibrantTeal]), #src
    dot_size=3.5, #src
    camera_position=(1.0, 0.5, 0.5), #src
) #src
render_asymptote(export_folder * "/startDataAndCenter.asy"; render=2) #src
#md # ```julia
#md # asymptote_export_S2_signals("startDataAndCenter.asy";
#md #     points = [ [x], data],
#md #     colors=Dict(:points => [TolVibrantBlue, TolVibrantTeal]),
#md #     dot_size = 3.5, camera_position = (1.,.5,.5)
#md # )
#md # render_asymptote("startDataAndCenter.asy"; render = 2)
#md # ```
#md #
#md # ![The data of noisy versions of $x$](../assets/images/tutorials/startDataAndCenter.png)
#
# ## Computing the Mean
#
# To compute the mean on the manifold we use the characterization, that the
# Euclidean mean minimizes the sum of squared distances, and end up with the
# following cost function. Its minimizer is called
# [Riemannian Center of Mass](https://arxiv.org/abs/1407.2087).
#
# !!! note
#
#     There are more sophisticated methods tailored for the specific manifolds available in
#     [Manifolds.jl](https://juliamanifolds.github.io/Manifolds.jl/) see [`mean`](https://juliamanifolds.github.io/Manifolds.jl/stable/features/statistics.html#Statistics.mean-Tuple{Manifold,AbstractArray{T,1}%20where%20T,AbstractArray{T,1}%20where%20T,ExtrinsicEstimation}).
#
F(M, y) = sum(1 / (2 * n) * distance.(Ref(M), Ref(y), data) .^ 2)
gradF(M, y) = sum(1 / n * grad_distance.(Ref(M), data, Ref(y)))
nothing #hide
#
# note that the [`grad_distance`](@ref) defaults to the case `p=2`, i.e. the
# gradient of the squared distance. For details on convergence of the gradient
# descent for this problem, see [[Afsari, Tron, Vidal, 2013](#AfsariTronVidal2013)]
#
# The easiest way to call the gradient descent is now to call
# [`gradient_descent`](@ref)
xMean = gradient_descent(M, F, gradF, data[1])
nothing; #hide
# but in order to get more details, we further add the `debug=` options, which
# act as a [decorator pattern](https://en.wikipedia.org/wiki/Decorator_pattern)
# using the [`DebugOptions`](@ref) and [`DebugAction`](@ref)s. The latter store
# values if that's necessary, for example for the [`DebugChange`](@ref) that prints
# the change during the last iteration. The following debug prints
#
# `# i | x: | Last Change: | F(x): ``
#
# as well as the reason why the algorithm stopped at the end.
# Here, the format shorthand and the [`DebugFactory`] are used, which returns a
# [`DebugGroup`](@ref) of [`DebugAction`](@ref) performed each iteration and the stop,
# respectively.
xMean = gradient_descent(
    M,
    F,
    gradF,
    data[1];
    debug=[:Iteration, " | ", :x, " | ", :Change, " | ", :Cost, "\n", :Stop],
)
nothing #hide
#
# A way to get better performance and for convex and coercive costs a guaranteed convergence is to switch the default 
# [`ConstantStepsize`](@ref)(1.0) with a step size that performs better, for 
# example the [`ArmijoLinesearch`](@ref)().
# We can tweak the default values for the contractionFactor and the sufficientDecrease 
# beyond constant step size which is already quite fast.  This gives
xMean2 = gradient_descent(
    M,
    F,
    gradF,
    data[1];
    stepsize=ArmijoLinesearch(1.0, ExponentialRetraction(), 0.99, 0.5),
    debug=[:Iteration, " | ", :x, " | ", :Change, " | ", :Cost, "\n", :Stop],
)
# which finishes in 5 steaps, just slightly better than the previous computation.
F(M, xMean) - F(M, xMean2)
# Note that other optimization tasks may have other speedup opportunities.
#
# For even more precision, we can further require a smaller gradient norm. 
# This is done by changing the [`StoppingCriterion`](@ref) used, where several 
# criteria can be combined using `&` and/or `|`.  If we want to decrease the final 
# gradient (from less that 1e-8) norm but keep the maximal number of iterations 
# to be 200, we can run
xMean3 = gradient_descent(
    M,
    F,
    gradF,
    data[1];
    stepsize=ArmijoLinesearch(1.0, ExponentialRetraction(), 0.99, 0.5),
    stopping_criterion=StopAfterIteration(200) | StopWhenGradientNormLess(1e-15),
    debug=[:Iteration, " | ", :x, " | ", :Change, " | ", :Cost, "\n", :Stop],
)
#
# which takes 10 iterations but gets a very small gradient, and not much is gained in the cost itself
F(M, xMean2) - F(M, xMean3)
#
asymptote_export_S2_signals( #src
    export_folder * "/startDataCenterMean.asy"; #src
    points=[[x], data, [xMean]], #src
    colors=Dict(:points => [TolVibrantBlue, TolVibrantTeal, TolVibrantOrange]), #src
    dot_size=3.5, #src
    camera_position=(1.0, 0.5, 0.5), #src
) #src
render_asymptote(export_folder * "/startDataCenterMean.asy"; render=2) #src
#md # ```julia
#md # asymptote_export_S2_signals("startDataCenterMean.asy";
#md #     points = [ [x], data, [xMean] ],
#md #     colors=Dict(:points => [TolVibrantBlue, TolVibrantTeal, TolVibrantOrange]),
#md #     dot_size = 3.5, camera_position = (1.,.5,.5)
#md # )
#md # render_asymptote("startDataCenterMean.asy"; render = 2)
#md # ```
#md #
#md # ![The resulting mean (orange)](../assets/images/tutorials/startDataCenterMean.png)
#
#
# ## Computing the Median
#
# !!! note
#
#     There are more sophisticated methods tailored for the specific manifolds available in
#     [Manifolds.jl](https://juliamanifolds.github.io/Manifolds.jl/) see [`median`](https://juliamanifolds.github.io/Manifolds.jl/stable/features/statistics.html#Statistics.median-Tuple{Manifold,AbstractArray{T,1}%20where%20T,AbstractArray{T,1}%20where%20T,CyclicProximalPointEstimation}).
#
# Similar to the mean you can also define the median as the minimizer of the
# distances, see for example [[Bačák, 2014](#Bačák2014)], but since
# this problem is not differentiable, we employ the Cyclic Proximal Point (CPP)
# algorithm, described in the same reference. We define
#
F2(M, y) = sum(1 / (2 * n) * distance.(Ref(M), Ref(y), data))
proxes = Function[(M, λ, y) -> prox_distance(M, λ / n, di, y, 1) for di in data]
nothing #hide
# where the `Function` is a helper for global scope to infer the correct type.
#
# We then call the [`cyclic_proximal_point`](@ref) as
o = cyclic_proximal_point(
    M,
    F2,
    proxes,
    data[1];
    debug=[:Iteration, " | ", :x, " | ", :Change, " | ", :Cost, "\n", 50, :Stop],
    record=[:Iteration, :Change, :Cost],
    return_options=true,
)
xMedian = get_solver_result(o)
values = get_record(o)
nothing # hide
# where the differences to [`gradient_descent`](@ref) are as follows
#
# * the third parameter is now an Array of proximal maps
# * debug is reduces to only every 50th iteration
# * we further activated a [`RecordAction`](@ref) using the `record=` optional
#   parameter. These work very similar to those in debug, but they
#   collect their data in an array. The high level interface then returns two
#   variables; the `values` do contain an array of recorded
#   datum per iteration. Here a Tuple containing the iteration, last change and
#   cost respectively; see [`RecordGroup`](@ref), [`RecordIteration`](@ref),
#   [`RecordChange`](@ref), [`RecordCost`](@ref) as well as the [`RecordFactory`](@ref)
#   for details. The `values` contains hence a tuple per iteration,
#   that itself consists of (by order of specification) the iteration number,
#   the last change and the cost function value.
#
# These recorded entries read
values
# The resulting median and mean for the data hence are
#
asymptote_export_S2_signals( #src
    export_folder * "/startDataCenterMedianAndMean.asy"; #src
    points=[[x], data, [xMean], [xMedian]], #src
    colors=Dict( #src
        :points => [TolVibrantBlue, TolVibrantTeal, TolVibrantOrange, TolVibrantMagenta], #src
    ), #src
    dot_size=3.5, #src
    camera_position=(1.0, 0.5, 0.5), #src
) #src
render_asymptote(export_folder * "/startDataCenterMedianAndMean.asy"; render=2) #src
#md # ```julia
#md # asymptote_export_S2_signals("startDataCenterMean.asy";
#md #     points = [ [x], data, [xMean], [xMedian] ],
#md #     colors=Dict(:points => [TolVibrantBlue, TolVibrantTeal, TolVibrantOrange, TolVibrantMagenta]),
#md #     dot_size = 3.5, camera_position = (1.,.5,.5)
#md # )
#md # render_asymptote("startDataCenterMedianAndMean.asy"; render = 2)
#md # ```
#md #
#md # ![The resulting mean (orange) and median (magenta)](../assets/images/tutorials/startDataCenterMedianAndMean.png)
#
# ## Literature
#
# ```@raw html
# <ul>
# <li id="Bačák2014">[<a>Bačák, 2014</a>]
#   Bačák, M: <emph>Computing Medians and Means in Hadamard Spaces.</emph>,
#   SIAM Journal on Optimization, Volume 24, Number 3, pp. 1542–1566,
#   doi: <a href="https://doi.org/10.1137/140953393">10.1137/140953393</a>,
#   arxiv: <a href="https://arxiv.org/abs/1210.2145">1210.2145</a>.</li>
#   <li id="AfsariTronVidal2013">[<a>Afsari, Tron, Vidal, 2013</a>]
#    Afsari, B; Tron, R.; Vidal, R.: <emph>On the Convergence of Gradient
#    Descent for Finding the Riemannian Center of Mass</emph>,
#    SIAM Journal on Control and Optimization, Volume 51, Issue 3,
#    pp. 2230–2260.
#    doi: <a href="https://doi.org/10.1137/12086282X">10.1137/12086282X</a>,
#    arxiv: <a href="https://arxiv.org/abs/1201.0925">1201.0925</a></li>
# </ul>
# ```
