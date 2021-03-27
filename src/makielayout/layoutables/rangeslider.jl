function layoutable(::Type{RangeSlider}, fig_or_scene; bbox = nothing, kwargs...)

    topscene = get_topscene(fig_or_scene)

    default_attrs = default_attributes(RangeSlider, topscene).attributes
    theme_attrs = subtheme(topscene, :RangeSlider)
    attrs = merge!(merge!(Attributes(kwargs), theme_attrs), default_attrs)

    decorations = Dict{Symbol, Any}()

    @extract attrs (
        halign, valign, horizontal, linewidth, snap,
        startvalues, values, color_active, color_active_dimmed, color_inactive
    )

    sliderrange = attrs.range

    protrusions = Node(GridLayoutBase.RectSides{Float32}(0, 0, 0, 0))
    layoutobservables = LayoutObservables{RangeSlider}(attrs.width, attrs.height, attrs.tellwidth, attrs.tellheight,
        halign, valign, attrs.alignmode; suggestedbbox = bbox, protrusions = protrusions)

    onany(linewidth, horizontal) do lw, horizontal
        if horizontal
            layoutobservables.autosize[] = (nothing, Float32(lw))
        else
            layoutobservables.autosize[] = (Float32(lw), nothing)
        end
    end

    sliderbox = lift(identity, layoutobservables.computedbbox)

    endpoints = lift(sliderbox, horizontal) do bb, horizontal

        h = height(bb)
        w = width(bb)

        if horizontal
            y = bottom(bb) + h / 2
            [Point2f0(left(bb) + h/2, y),
             Point2f0(right(bb) - h/2, y)]
        else
            x = left(bb) + w / 2
            [Point2f0(x, bottom(bb) + w/2),
             Point2f0(x, top(bb) - w/2)]
        end
    end

    # this is the index of the selected value in the slider's range
    # selected_index = Node(1)
    # add the selected index to the attributes so it can be manipulated later
    attrs.selected_indices = (1, 1)
    selected_indices = attrs.selected_indices

    # the fraction on the slider corresponding to the selected_indices
    # this is only used after dragging
    sliderfractions = lift(selected_indices, sliderrange) do is, r
        map(is) do i
            (i - 1) / (length(r) - 1)
        end
    end

    dragging = Node(false)

    # what the slider actually displays currently (also during dragging when
    # the slider position is in an "invalid" position given the slider's range)
    displayed_sliderfractions = Node((0.0, 0.0))

    on(sliderfractions) do fracs
        # only update displayed fraction through sliderfraction if not dragging
        # dragging overrides the value so there is clear mouse interaction
        if !dragging[]
            displayed_sliderfractions[] = fracs
        end
    end

    on(selected_indices) do is
        values[] = getindex.(Ref(sliderrange[]), is)
    end

    # initialize slider value with closest from range
    selected_indices[] = if startvalues[] === AbstractPlotting.automatic
        (1, lastindex(sliderrange[]))
    else
        closest_index.(Ref(sliderrange[]), startvalues[])
    end

    middlepoints = lift(endpoints, displayed_sliderfractions) do ep, sfs
        [Point2f0(ep[1] .+ sf .* (ep[2] .- ep[1])) for sf in sfs]
    end

    linepoints = lift(endpoints, middlepoints) do eps, middles
        [eps[1], middles[1], middles[1], middles[2], middles[2], eps[2]]
    end

    linecolors = lift(color_active_dimmed, color_inactive) do ca, ci
        [ci, ca, ci]
    end

    endbuttoncolors = lift(color_active_dimmed, color_inactive) do ca, ci
        [ci, ci]
    end

    endbuttons = scatter!(topscene, endpoints, color = endbuttoncolors, markersize = linewidth, strokewidth = 0, raw = true)
    decorations[:endbuttons] = endbuttons

    linesegs = linesegments!(topscene, linepoints, color = linecolors, linewidth = linewidth, raw = true)
    decorations[:linesegments] = linesegs

    state = Node(:none)
    button_magnifications = lift(state) do state
        if state == :none
            [1.0, 1.0]
        elseif state == :min
            [1.25, 1.0]
        elseif state == :both
            [1.25, 1.25]
        else
            [1.0, 1.25]
        end
    end
    buttonsizes = @lift($linewidth .* $button_magnifications)
    buttons = scatter!(topscene, middlepoints, color = color_active, strokewidth = 0, markersize = buttonsizes, raw = true)
    decorations[:buttons] = buttons

    mouseevents = addmouseevents!(topscene, linesegs, buttons)

    # we need to record where a drag started for the case where the center of the
    # range is shifted, because the difference in indices always needs to stay the same
    # and the slider is moved relative to this start position
    startfraction = Ref(0.0)
    start_disp_fractions = Ref((0.0, 0.0))
    startindices = Ref((1, 1))

    onmouseleftdrag(mouseevents) do event

        dragging[] = true
        fraction = if horizontal[]
            (event.px[1] - endpoints[][1][1]) / (endpoints[][2][1] - endpoints[][1][1])
        else
            (event.px[2] - endpoints[][1][2]) / (endpoints[][2][2] - endpoints[][1][2])
        end
        fraction = clamp(fraction, 0, 1)

        if state[] in (:min, :max)
            if snap[]
                snapindex = closest_fractionindex(sliderrange[], fraction)
                fraction = (snapindex - 1) / (length(sliderrange[]) - 1)
            end
            if state[] == :min
                displayed_sliderfractions[] = (fraction, displayed_sliderfractions[][2])
            else
                displayed_sliderfractions[] = (displayed_sliderfractions[][1], fraction)
            end
            newindices = closest_fractionindex.(Ref(sliderrange[]), displayed_sliderfractions[])
            if selected_indices[] != newindices
                selected_indices[] = newindices
            end
        elseif state[] == :both
            fracdif = fraction - startfraction[]

            clamped_fracdif = clamp(fracdif, -start_disp_fractions[][1], 1 - start_disp_fractions[][2])

            ntarget = round(Int, length(sliderrange[]) * clamped_fracdif)

            nlow = -startindices[][1] + 1
            nhigh = length(sliderrange[]) - startindices[][2]
            nchange = clamp(ntarget, nlow, nhigh)

            newindices = startindices[] .+ nchange

            displayed_sliderfractions[] = if snap[]
                (newindices .- 1) ./ (length(sliderrange[]) - 1)
            else
                start_disp_fractions[] .+ clamped_fracdif
            end

            if selected_indices[] != newindices
                selected_indices[] = newindices
            end
        else
            error("The state should not be $state[] while dragging.")
        end
        

        # displayed_sliderfractions[] = minmax(if i_closer == 1
        #     (fraction, displayed_sliderfractions[][2])
        # else
        #     (displayed_sliderfractions[][1], fraction)
        # end...)

        
    end

    onmouseleftdragstop(mouseevents) do event
        dragging[] = false
        # adjust slider to closest legal value
        sliderfractions[] = sliderfractions[]
    end

    onmouseleftdown(mouseevents) do event

        pos = event.px
        
        dim = horizontal[] ? 1 : 2
        frac = clamp(
            (pos[dim] - endpoints[][1][dim]) / (endpoints[][2][dim] - endpoints[][1][dim]),
            0, 1
        )

        startfraction[] = frac
        startindices[] = selected_indices[]
        start_disp_fractions[] = displayed_sliderfractions[]

        if state[] in (:both, :none)
            return
        end

        newindex = closest_fractionindex(sliderrange[], frac)
        if abs(newindex - selected_indices[][1]) < abs(newindex - selected_indices[][2])
            selected_indices[] = (newindex, selected_indices[][2])
        else
            selected_indices[] = (selected_indices[][1], newindex)
        end
        # linecolors[] = [color_active[], color_inactive[]]
    end

    onmouseleftdoubleclick(mouseevents) do event
        selected_indices[] = selected_indices[] = if startvalues[] === AbstractPlotting.automatic
            (1, lastindex(sliderrange[]))
        else
            closest_index.(Ref(sliderrange[]), startvalues[])
        end
    end

    onmouseover(mouseevents) do event
        fraction = if horizontal[]
            (event.px[1] - endpoints[][1][1]) / (endpoints[][2][1] - endpoints[][1][1])
        else
            (event.px[2] - endpoints[][1][2]) / (endpoints[][2][2] - endpoints[][1][2])
        end
        fraction = clamp(fraction, 0, 1)

        buttondistance = displayed_sliderfractions[][2] - displayed_sliderfractions[][1]

        state[] = if fraction < displayed_sliderfractions[][1] + 0.25 * buttondistance
            :min
        elseif fraction < displayed_sliderfractions[][1] + 0.75 * buttondistance
            :both
        else
            :max
        end
    end

    onmouseout(mouseevents) do event
        state[] = :none
    end

    # trigger autosize through linewidth for first layout
    linewidth[] = linewidth[]

    RangeSlider(fig_or_scene, layoutobservables, attrs, decorations)
end

function valueindex(sliderrange, value)
    for (i, val) in enumerate(sliderrange)
        if val == value
            return i
        end
    end
    nothing
end

function closest_fractionindex(sliderrange, fraction)
    n = length(sliderrange)
    onestepfrac = 1 / (n - 1)
    i = round(Int, fraction / onestepfrac) + 1
    min(max(i, 1), n)
end

function closest_index(sliderrange, value)
    for (i, val) in enumerate(sliderrange)
        if val == value
            return i
        end
    end
    # if the value wasn't found this way try inexact
    closest_index_inexact(sliderrange, value)
end

function closest_index_inexact(sliderrange, value)
    distance = Inf
    selected_i = 0
    for (i, val) in enumerate(sliderrange)
        newdist = abs(val - value)
        if newdist < distance
            distance = newdist
            selected_i = i
        end
    end
    selected_i
end

"""
Set the `slider` to the value in the slider's range that is closest to `value`.
"""
function set_close_to!(slider, value)
    closest = closest_index(slider.range[], value)
    slider.selected_index = closest
end
