require 'cairo'
require 'imlib2'

-- Converts degrees to radians
function deg_to_rad(deg)
    local rad = (deg - 90) * (math.pi/180)
    return rad
end

-- Converts celsius to fahrenheit
function degc_to_degf(degc)
    return math.floor(1.8 * degc + 32)
end

-- Returns rgb(x, y, z) in a form that Cairo can use.
function rgb(r, g, b)
    local red = r/255
    local green = g/255
    local blue = b/255

    return {red, green, blue}
end

-- Draws a line. Points are given as a 2d array [[x, y], [x2, y2] ...]
function draw_line(points, rgb, alpha, width)
    cairo_set_line_width(cr, width)
    cairo_set_line_cap(cr, CAIRO_LINE_CAP_SQUARE)
    cairo_set_source_rgba(cr, rgb[1], rgb[2], rgb[3], alpha)
    cairo_move_to(cr, points[1][1], points[1][2])
    for i = 2, #points do
        cairo_line_to(cr, points[i][1], points[i][2])   
    end
    cairo_stroke(cr)
end

-- Draws a polygon. Points are given as a 2d array [[x, y], [x2, y2] ...]
function draw_poly(points, fill_rgb, fill_alpha, stroke_rgb, stroke_alpha, stroke_width)
    cairo_move_to(cr, points[1][1], points[1][2])
    for i = 2, #points do
        cairo_line_to(cr, points[i][1], points[i][2])   
    end
    cairo_close_path(cr)
    cairo_set_source_rgba(cr, fill_rgb[1], fill_rgb[2], fill_rgb[3], fill_alpha)
    cairo_fill_preserve(cr)
    cairo_set_source_rgba(cr, stroke_rgb[1], stroke_rgb[2], stroke_rgb[3], stroke_alpha)
    cairo_set_line_width(cr, stroke_width)
    cairo_stroke(cr)
end

-- Draws text at {x, y}. Align can be "LEFT," "CENTER," or "RIGHT"
function draw_text(point, text, font, font_size, align, rgb, alpha)
    cairo_select_font_face(cr, font, CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_NORMAL)
    cairo_set_font_size(cr, font_size)
    cairo_set_source_rgba(cr, rgb[1], rgb[2], rgb[3], alpha)
    if align == "CENTER" then
        local extents = cairo_text_extents_t:create()
        tolua.takeownership(extents)
        cairo_text_extents(cr, text, extents)
        point[1] = point[1] - extents.width / 2 + extents.x_bearing
    end
    if align == "RIGHT" then
        local extents = cairo_text_extents_t:create()
        tolua.takeownership(extents)
        cairo_text_extents(cr, text, extents)
        point[1] = point[1] - extents.width - extents.x_bearing
    end
    cairo_move_to(cr, point[1], point[2])
    cairo_show_text(cr, text)
    cairo_stroke(cr)
end

-- Draws multi-line text anchored top-left at point {x, y}
function multiline_text(point, text, font, font_size, align, rgb, alpha)
    local index = 0
    for i in string.gmatch(text, "[^\r\n]+") do
        draw_text({point[1], point[2] + ((font_size + 2) * index)}, i, font, font_size, align, rgb, alpha)
        index = index + 1
    end
end

-- Renders an image from file at {x, y}.
function draw_image(point, file)
    local show = imlib_load_image(file)
    if show == nil then return end
    imlib_context_set_image(show)
    local width=imlib_image_get_width()
    local height=imlib_image_get_height()
    imlib_context_set_image(show)
    imlib_render_image_on_drawable(point[1], point[2])
    imlib_free_image()
end

-- Draws a bar graph showing value as a percentage of value_max anchord top-left on point {x, y}.
-- Type can be "HORIZONTAL" or "VERTICAL"
function draw_bar_graph(point, type, value, value_max, bar_width, bar_height, label, font, font_size, rgb, alpha, rgb_background, alpha_background, rgb_font, alpha_font)
    if tonumber(value) == nil then
        return false;
    end
    -- Draw background
    cairo_set_source_rgba(cr, rgb_background[1], rgb_background[2], rgb_background[3], alpha_background)
    cairo_rectangle(cr, point[1], point[2], bar_width, bar_height)
    cairo_fill (cr)

    -- Draw bar
    local meter_size = 0
    cairo_select_font_face(cr, font, CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_BOLD)
    cairo_set_font_size(cr, font_size)
    cairo_set_source_rgba (cr, rgb[1], rgb[2], rgb[3], alpha + ((0.4 * alpha) * (value / value_max)) - (0.2 * alpha))
    if type == "HORIZONTAL" then
        meter_size = bar_width * (value / value_max)
        cairo_rectangle (cr, point[1], point[2], meter_size, bar_height)
        cairo_fill (cr)
        -- Label
        if label then
            local extents = cairo_text_extents_t:create()
            tolua.takeownership(extents)
            cairo_text_extents(cr, label, extents)
            draw_text({point[1], point[2] - extents.height}, label, font, font_size, "LEFT", rgb_font, alpha_font)
            local val_txt = value .. "%"
            draw_text({point[1] + bar_width + 4, point[2] + (bar_height / 2) + (extents.height / 2)}, val_txt, font, font_size, "LEFT", rgb_font, alpha_font)
        end
    end
    if type == "VERTICAL" then
        meter_size = bar_height * (value / value_max)
        cairo_rectangle (cr, point[1], point[2] + bar_height, bar_width, -1 * meter_size)
        cairo_fill (cr)
        -- Label
        if label then
            local extents = cairo_text_extents_t:create()
            tolua.takeownership(extents)
            cairo_text_extents(cr, label, extents)
            draw_text({point[1] + (bar_width / 2), point[2] + bar_height + extents.height + 8}, label, font, font_size, "CENTER", rgb_font, alpha_font)
            local val_txt = value .. "%"
            draw_text({point[1] + (bar_width / 2), point[2] - extents.height}, val_txt, font, font_size, "CENTER", rgb_font, alpha_font)
        end
    end
end

-- Draws a circular graph showing value as a percentage of value_max centered on point {x, y}.
-- Type can be "CIRCLE", "GAUGE", "TOP", "TOP_RIGHT", "RIGHT", ... for quarter and half circles.
function draw_circle_graph(point, type, value, value_max, radius, bar_width, label, font, font_size, rgb, alpha, rgb_background, alpha_background, rgb_font, alpha_font)
    if tonumber(value) == nil then
        return false;
    end
    local arc_tbl = {
        ["CIRCLE"] = {1.5 * math.pi, 3.5 * math.pi, 0, 0},
        ["GAUGE"] = {0.75 * math.pi, 2.25 * math.pi, 0, 0.15},
        ["LEFT"] = {0.5 * math.pi, 1.5 * math.pi, -0.4, 0},
        ["TOP"] = {math.pi, 2 * math.pi, 0, -0.4},
        ["RIGHT"] = {1.5 * math.pi, 2.5 * math.pi, 0.4, 0},
        ["BOTTOM"] = {0, math.pi, 0, 0.4},
        ["TOP_LEFT"] = {math.pi, 1.5 * math.pi, -0.4, -0.4},
        ["TOP_RIGHT"] = {1.5 * math.pi, 2 * math.pi, 0.4, -0.4},
        ["BOTTOM_RIGHT"] = {2 * math.pi, 2.5 * math.pi, 0.4, 0.4},
        ["BOTTOM_LEFT"] = {0.5 * math.pi, math.pi, -0.4, 0.4}
    }
    local arc_start = arc_tbl[type][1]
    local arc_end = arc_tbl[type][2]
    -- Draw background
    cairo_set_line_width(cr, bar_width)
    cairo_set_source_rgba(cr, rgb_background[1], rgb_background[2], rgb_background[3], alpha_background)
    cairo_arc(cr, point[1], point[2], radius, arc_start, arc_end)
    cairo_stroke(cr)

    local angle_start = arc_start
    local angle_end = arc_start + (tonumber(value) * (math.abs(arc_end - arc_start) / tonumber(value_max)))

    -- Draw bar
    cairo_set_source_rgba(cr, rgb[1], rgb[2], rgb[3], alpha + ((0.4 * alpha) * (tonumber(value) / tonumber(value_max))) - (0.2 * alpha))
    cairo_arc(cr, point[1], point[2], radius, angle_start, angle_end)
    cairo_stroke(cr)

    -- Label
    if label then
        local extents = cairo_text_extents_t:create()
        tolua.takeownership(extents)
        cairo_select_font_face(cr, font, CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_BOLD)
        cairo_set_font_size(cr, font_size)

        local text_mod_x = arc_tbl[type][3] * radius
        local text_mod_y = arc_tbl[type][4] * radius

        cairo_text_extents(cr, label, extents)
        local label_x = point[1]  + text_mod_x
        local label_y = point[2] - (extents.height / 2 + extents.y_bearing) + text_mod_y - 9
        draw_text({label_x, label_y}, label, font, font_size, "CENTER", rgb_font, alpha_font)

        local val_txt = value .. "%"
        cairo_text_extents(cr, val_txt, extents)
        local val_x = point[1] + text_mod_x
        local val_y = point[2] - (extents.height / 2 + extents.y_bearing) + text_mod_y + 9

        draw_text({val_x, val_y}, val_txt, font, font_size, "CENTER", rgb_font, alpha_font)
    end
end

function conky_main()
    if conky_window == nil then
        return
    end

    local cs = cairo_xlib_surface_create(conky_window.display,
                                         conky_window.drawable,
                                         conky_window.visual,
                                         conky_window.width,
                                         conky_window.height)
    cr = cairo_create(cs)

    local ticks = tonumber(conky_parse("${updates}"))

    -- Font Settings
    local main_font = "TerminessTTF Nerd Font Mono"
    local accent_font = "Gunplay"
    local main_font_size = 16
    local accent_font_size = 24

    -- Line Width
    local primary_line_width = 3
    local secondary_line_width = 2

    -- RGBA Settings
    local poly_bg_rgb = rgb(33, 33, 33)
    local poly_bg_alpha = 0.6
    local primary_rgb = rgb(232, 107, 110)
    local primary_alpha = 0.85
    local secondary_rgb = rgb(255, 255, 255)
    local secondary_alpha = 0.55
    local graph_bg_rgb = rgb(0, 0, 0)
    local graph_bg_alpha = 0.9

    -- Angle slope ratio = 118/130 = .907692307692
    local poly_right = {
        {1940, -20},
        {1420, -20},
        {1420, 0},
        {1550, 118},
        {1680, 236},
        {1680, 418},
        {1720, 454},
        {1720, 743},
        {1547, 900},
        {900, 900},
        {792, 1080},
        {792, 1100},
        {1940, 1100}
    }
    --[[ Reversed poly, if you want to mirror the wallpaper.
    local poly_left = {
        {-20, 1100},
        {500, 1100},
        {500, 1080},
        {370, 962},
        {240, 844},
        {240, 662},
        {120, 553},
        {120, 410},
        {346, 180},
        {1020, 180},
        {1128, 0},
        {1128, -20},
        {-20, -20}
    }
    ]]
    draw_poly(poly_right, poly_bg_rgb, poly_bg_alpha, primary_rgb, primary_alpha, primary_line_width)
    draw_line({{1940, 118}, {1590, 118}}, primary_rgb, primary_alpha, primary_line_width)
    -- Secondary lines, top down
    draw_line({{1340, 20}, {1400, 20}, {1444, 60}}, secondary_rgb, secondary_alpha, secondary_line_width)
    draw_line({{1630, 227}, {1660, 254}, {1660, 284}}, secondary_rgb, secondary_alpha, secondary_line_width)
    draw_line({{1670, 439}, {1700, 469}, {1700, 558}}, secondary_rgb, secondary_alpha, secondary_line_width)
    draw_line({{930, 873}, {1537, 873}, {1597, 819}}, secondary_rgb, secondary_alpha, secondary_line_width)
    -- MCRN logo
    draw_image({1540, 6}, "/home/carrie/.conky/mcrn-transparency.png")
    -- Text
    draw_text({1610, 155}, "CPU", accent_font, accent_font_size, "LEFT", primary_rgb, primary_alpha)
    -- CPU Graphs
    -- local avg = (tonumber(conky_parse("${cpu cpu0}")) + tonumber(conky_parse("${cpu cpu1}")) + tonumber(conky_parse("${cpu cpu2}")) + tonumber(conky_parse("${cpu cpu3}"))) / 4
    draw_circle_graph({1695, 160}, "GAUGE", conky_parse("${cpu cpu0}"), 100, 26, 7, "1", main_font, main_font_size, primary_rgb, primary_alpha, graph_bg_rgb, graph_bg_alpha, secondary_rgb, primary_alpha)
    draw_circle_graph({1758, 160}, "GAUGE", conky_parse("${cpu cpu1}"), 100, 26, 7, "2", main_font, main_font_size, primary_rgb, primary_alpha, graph_bg_rgb, graph_bg_alpha, secondary_rgb, primary_alpha)
    draw_circle_graph({1821, 160}, "GAUGE", conky_parse("${cpu cpu2}"), 100, 26, 7, "3", main_font, main_font_size, primary_rgb, primary_alpha, graph_bg_rgb, graph_bg_alpha, secondary_rgb, primary_alpha)
    draw_circle_graph({1886, 160}, "GAUGE", conky_parse("${cpu cpu3}"), 100, 26, 7, "4", main_font, main_font_size, primary_rgb, primary_alpha, graph_bg_rgb, graph_bg_alpha, secondary_rgb, primary_alpha)
    for i = 1, 5 do
        draw_text({1700, 202 + (main_font_size + 2) * (i - 1)}, conky_parse("${top name " .. i .. "}"), main_font, main_font_size, "LEFT", secondary_rgb, secondary_alpha)
        draw_text({1908, 202 + (main_font_size + 2) * (i - 1)}, conky_parse("${top cpu " .. i .. "}"), main_font, main_font_size, "RIGHT", secondary_rgb, secondary_alpha)
    end
    -- RAM Graphs
    draw_text({1700, 315}, "RAM", accent_font, accent_font_size, "LEFT", primary_rgb, primary_alpha)
    draw_bar_graph({1770, 305}, "HORIZONTAL", conky_parse("${memperc}"), 100, 110, 10, conky_parse("${mem}") .. ' / ' .. conky_parse("${memmax}"), main_font, main_font_size, primary_rgb, primary_alpha, graph_bg_rgb, graph_bg_alpha, secondary_rgb, primary_alpha)
    for i = 1, 5 do
        draw_text({1700, 338 + (main_font_size + 2) * (i - 1)}, conky_parse("${top_mem name " .. i .. "}"), main_font, main_font_size, "LEFT", secondary_rgb, secondary_alpha)
        draw_text({1908, 338 + (main_font_size + 2) * (i - 1)}, conky_parse("${top_mem mem_res " .. i .. "}"), main_font, main_font_size, "RIGHT", secondary_rgb, secondary_alpha)
    end
    -- Battery Graphs
    draw_text({1740, 445}, "BATTERY", accent_font, accent_font_size, "LEFT", primary_rgb, primary_alpha)
    draw_bar_graph({1740, 510}, "HORIZONTAL", conky_parse("${battery_percent BAT0}"), 100, 140, 10, "INTERNAL", main_font, main_font_size, primary_rgb, primary_alpha, graph_bg_rgb, graph_bg_alpha, secondary_rgb, primary_alpha)
    draw_bar_graph({1740, 555}, "HORIZONTAL", conky_parse("${battery_percent BAT1}"), 100, 140, 10, "EXTERNAL", main_font, main_font_size, primary_rgb, primary_alpha, graph_bg_rgb, graph_bg_alpha, secondary_rgb, primary_alpha)
    -- Battery states on the T440 are weird because there are two batteries, so we need to guesstimate battery state a bit.
    local bat_state = {string.sub(conky_parse("${battery_short BAT0}"), 1, 1), string.sub(conky_parse("${battery_short BAT1}"), 1, 1)}
    local discharge_time = "Time Unknown"
    if bat_state[1] == "C" or bat_state[2] == "C" then
        bat_state = "C"
    elseif bat_state[1] == "D" then
        bat_state = "D"
        discharge_time = conky_parse("${battery_time BAT0}")
    elseif bat_state[2] == "D" then
        bat_state = "D"
        discharge_time = conky_parse("${battery_time BAT1}")
    elseif (bat_state[1] == "F" or bat_state[1] == "U") and (bat_state[2] == "F" or bat_state[2] == "U") then
        bat_state = "F"
    else
        bat_state = "U"
    end
    local bat_state_tbl = {
        ["C"] = "CHARGING",
        ["D"] = "DRAINING - " .. discharge_time,
        ["F"] = "FULL CHARGE",
        ["U"] = "UNKNOWN"
    }
    local bat_state_msg = bat_state_tbl[bat_state]
    draw_text({1823, 475}, bat_state_msg, accent_font, main_font_size, "CENTER", secondary_rgb, secondary_alpha)
    -- Network
    draw_text({1740, 610}, "NETWORK", accent_font, accent_font_size, "LEFT", primary_rgb, primary_alpha)
    draw_circle_graph({1775, 670}, "GAUGE", conky_parse("${wireless_link_qual_perc wlp3s0}"), 100, 35, 7, "Wi-Fi", main_font, main_font_size, primary_rgb, primary_alpha, graph_bg_rgb, graph_bg_alpha, secondary_rgb, primary_alpha)
    draw_text({1820, 640}, "SSID", main_font, main_font_size, "LEFT", secondary_rgb, secondary_alpha)
    draw_text({1830, 655}, conky_parse("${wireless_essid wlp3s0}"), main_font, main_font_size, "LEFT", secondary_rgb, secondary_alpha)
    draw_text({1820, 670}, "DOWN", main_font, main_font_size, "LEFT", secondary_rgb, secondary_alpha)
    draw_text({1830, 685}, conky_parse("${downspeed wlp3s0}"), main_font, main_font_size, "LEFT", secondary_rgb, secondary_alpha)
    draw_text({1820, 700}, "UP", main_font, main_font_size, "LEFT", secondary_rgb, secondary_alpha)
    draw_text({1830, 715}, conky_parse("${upspeed wlp3s0}"), main_font, main_font_size, "LEFT", secondary_rgb, secondary_alpha)
    -- Hard Disk
    draw_text({1740, 750}, "DISK", accent_font, accent_font_size, "LEFT", primary_rgb, primary_alpha)
    draw_bar_graph({1740, 785}, "HORIZONTAL", conky_parse("${fs_used_perc /}"), 100, 140, 10, conky_parse("${fs_used /}" .. " / " .. conky_parse("${fs_size /}")), main_font, main_font_size, primary_rgb, primary_alpha, graph_bg_rgb, graph_bg_alpha, secondary_rgb, primary_alpha)
    draw_text({1700, 820}, "READ", main_font, main_font_size, "LEFT", secondary_rgb, secondary_alpha)
    draw_text({1908, 820}, conky_parse("${diskio_read /dev/sda}"), main_font, main_font_size, "RIGHT", secondary_rgb, secondary_alpha)
    draw_text({1700, 836}, "WRITE", main_font, main_font_size, "LEFT", secondary_rgb, secondary_alpha)
    draw_text({1908, 836}, conky_parse("${diskio_write /dev/sda}"), main_font, main_font_size, "RIGHT", secondary_rgb, secondary_alpha)
    -- Alternate Distro
    --[[
    draw_text({1710, 890}, conky_parse("${execi 21600 echo $XDG_CURRENT_DESKTOP}"), main_font, 20, "RIGHT", primary_rgb, primary_alpha)
    draw_text({1710, 920}, conky_parse("${nodename}"), main_font, 24, "RIGHT", primary_rgb, primary_alpha)
    draw_text({1750, 890}, conky_parse("${execi 21600 lsb_release -c | cut -f 2}") .. " " .. conky_parse("${execi 21600 lsb_release -r | cut -f 2}"), main_font, 20, "LEFT", primary_rgb, primary_alpha)
    draw_text({1750, 920}, conky_parse("${execi 21600 lsb_release -d | cut -f 2}"), main_font, 24, "LEFT", primary_rgb, primary_alpha)
    draw_line({{1730, 865}, {1730, 935}}, primary_rgb, primary_alpha, primary_line_width)
    ]]
    -- Kernel & System Info
    draw_text({1908, 880}, conky_parse("Uptime: ${uptime}"), main_font, 20, "RIGHT", secondary_rgb, secondary_alpha)
    draw_text({1908, 920}, conky_parse("${kernel}"), main_font, 32, "RIGHT", primary_rgb, primary_alpha)
    -- Date / Time
    draw_text({1615, 985}, conky_parse("${time %Z}"), main_font, 36, "RIGHT", primary_rgb, primary_alpha)
    draw_text({1908, 985}, conky_parse("${time %H:%M:%S}"), main_font, 72, "RIGHT", primary_rgb, primary_alpha)
    draw_text({1565, 1052}, conky_parse("${time %a.}"), main_font, 48, "RIGHT", primary_rgb, primary_alpha)
    draw_text({1665, 1052}, conky_parse("${time %b}"), main_font, 56, "RIGHT", primary_rgb, primary_alpha)
    draw_text({1745, 1052}, conky_parse("${time %e}"), main_font, 64, "RIGHT", primary_rgb, primary_alpha)
    draw_text({1908, 1052}, conky_parse("${time %Y}"), main_font, 72, "RIGHT", primary_rgb, primary_alpha)
    -- Clock
    --[[
    draw_circle_graph({1630, 970}, "GAUGE", conky_parse("${time %S}"), 60, 10, 2, nil, main_font, main_font_size, primary_rgb, primary_alpha, graph_bg_rgb, graph_bg_alpha, secondary_rgb, primary_alpha)
    draw_circle_graph({1630, 970}, "GAUGE", conky_parse("${time %M}"), 60, 25, 3, nil, main_font, main_font_size, primary_rgb, primary_alpha, graph_bg_rgb, graph_bg_alpha, secondary_rgb, primary_alpha)
    draw_circle_graph({1630, 970}, "GAUGE", conky_parse("${time %H}"), 24, 40, 4, nil, main_font, main_font_size, primary_rgb, primary_alpha, graph_bg_rgb, graph_bg_alpha, secondary_rgb, primary_alpha)
    ]]
    -- Distro
    multiline_text({905, 920}, conky_parse("${execi 21600 screenfetch -LN}"), main_font, 8, "LEFT", primary_rgb, primary_alpha)
    draw_text({1032, 930}, conky_parse("${execi 21600 echo $XDG_CURRENT_DESKTOP}"), main_font, 24, "LEFT", primary_rgb, primary_alpha)
    draw_text({1036, 970}, conky_parse("${nodename}"), main_font, 24, "LEFT", primary_rgb, primary_alpha)
    draw_text({1036, 1010}, conky_parse("${execi 21600 lsb_release -c | cut -f 2}") .. " " .. conky_parse("${execi 21600 lsb_release -r | cut -f 2}"), main_font, 24, "LEFT", primary_rgb, primary_alpha)
    draw_text({1040, 1050}, conky_parse("${execi 21600 lsb_release -d | cut -f 2}"), main_font, 24, "LEFT", primary_rgb, primary_alpha)
    -- Cowsay
    -- multiline_text({1210, 910}, conky_parse("${texeci 600 cowsay -s $(fortune -s)}"), main_font, main_font_size, "LEFT", primary_rgb, primary_alpha)
    -- RSS Feed
    --[[
    local feed = "http://newsrss.bbc.co.uk/rss/newsonline_world_edition/americas/rss.xml"
    draw_text({1250, 930}, conky_parse("${rss " .. feed .. " 10 feed_title}"), accent_font, accent_font_size, "LEFT", primary_rgb, primary_alpha)
    local article_index = 0
    local line_index = 1
    while line_index < 8 do
        local str = conky_parse("${rss " .. feed .. " 30 item_title " .. article_index .. "}")
        if str == nil then break end -- We can assume RSS data is not yet loaded. Exit loop on this tick.
        if string.len(str) > 35 then -- An arbitrary value based on available space around other elements.
            draw_text({1250, 948 + (main_font_size + 2) * (line_index - 1)}, string.sub(str, 1, 35), main_font, main_font_size, "LEFT", secondary_rgb, secondary_alpha)
            line_index = line_index + 1
            if line_index == 8 then break end
            if string.len(string.sub(str, 36)) > 33 then
                draw_text({1260, 948 + (main_font_size + 2) * (line_index - 1)}, string.sub(str, 36, 66) .. "...", main_font, main_font_size, "LEFT", secondary_rgb, secondary_alpha)
            else
                draw_text({1260, 948 + (main_font_size + 2) * (line_index - 1)}, string.sub(str, 36), main_font, main_font_size, "LEFT", secondary_rgb, secondary_alpha)
            end
        else
            draw_text({1250, 948 + (main_font_size + 2) * (line_index - 1)}, str, main_font, main_font_size, "LEFT", secondary_rgb, secondary_alpha)
        end
        line_index = line_index + 1
        article_index = article_index + 1
    end
    ]]
    -- Cleanup
    cairo_destroy(cr)
    cairo_surface_destroy(cs)
    cr = nil
end
