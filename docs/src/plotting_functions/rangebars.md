# rangebars

```@docs
rangebars
```

### Examples

```@example
using CairoMakie
CairoMakie.activate!() # hide
AbstractPlotting.inline!(true) # hide

f = Figure()
Axis(f[1, 1])

vals = -1:0.1:1
lows = zeros(length(vals))
highs = LinRange(0.1, 0.4, length(vals))

rangebars!(vals, lows, highs, color = :red)

f
```


```@example
using CairoMakie
CairoMakie.activate!() # hide
AbstractPlotting.inline!(true) # hide

f = Figure()
Axis(f[1, 1])

vals = -1:0.1:1
lows = zeros(length(vals))
highs = LinRange(0.1, 0.4, length(vals))

rangebars!(vals, lows, highs, color = LinRange(0, 1, length(vals)),
    whiskerwidth = 10, direction = :x)

f
```

