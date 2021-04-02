# Axis3

## Data aspects and view mode

The attributes `data_aspect` and `viewmode` both influence the apparent relative scaling of the three axes.

### `data_aspect`

The `data_aspect` changes how long each axis is relative to the other two.

If you set it to `:data`, the axes will be scaled according to their lengths in data space.
The visual result is that objects with known real-world dimensions look correct and not squished or 

```@example
using GLMakie
using FileIO
GLMakie.activate!() # hide
AbstractPlotting.inline!(true) # hide

f = Figure(resolution = (1000, 800), fontsize = 14)

brain = load(assetpath("brain.stl"))

data_aspects = [:data, (1, 1, 1), (1, 2, 3), (3, 2, 1)]

for (i, daspect) in enumerate(data_aspects)
    ax = Axis3(f[fldmod1(i, 2)...], data_aspect = daspect, title = "$daspect")
    mesh!(brain, color = :bisque)
end

f
```

### `viewmode`

The `viewmode` changes how the final projection is adjusted to fit the axis into its scene.

The default is `:fitzoom`, which scales the final projection evenly, so that the farthest corner of the axis goes right up to the scene boundary.
If you rotate an axis with this mode, the apparent size will shrink and grow depending on the viewing angles, but the plot objects will never look skewed relative to their `data_aspect`.

The next option `:fit` is like `:fitzoom`, but without the zoom component.
The axis is scaled so that no matter what the viewing angles are, the axis does not clip the scene boundary and its apparent size doesn't change, even though this makes less efficient use of the available space.
You can imagine a sphere around the axis, which is zoomed right up until it touches the scene boundary.

The last option is `:stretch`.
In this mode, scaling in both x and y direction is applied to fit the axis right into its scene box.
Be aware that this mode can skew the axis a lot and doesn't keep the `data_aspect` intact.
On the other hand, it uses the available space most efficiently.

```@example
using GLMakie
GLMakie.activate!() # hide
AbstractPlotting.inline!(true) # hide

f = Figure(resolution = (1200, 1000), fontsize = 14)

r = LinRange(-1, 1, 100)
cube = [(x.^2 + y.^2 + z.^2) for x = r, y = r, z = r]
cube_with_holes = cube .* (cube .> 1.4)

viewmodes = [:fitzoom, :fit, :stretch]

for (j, viewmode) in enumerate(viewmodes)
    for (i, azimuth) in enumerate([1.1, 1.275, 1.45] .* pi)
        Box(f[i, j], color = :transparent, strokecolor = :gray80)
        ax = Axis3(f[i, j], data_aspect = :data,
            azimuth = azimuth,
            viewmode = viewmode, title = "$viewmode")
        volume!(cube_with_holes, algorithm = :iso, isorange = 0.05, isovalue = 1.7)
    end
end

f
```