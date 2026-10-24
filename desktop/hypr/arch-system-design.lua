-- Arch System Design: shape, motion, cursor and keybinds for illogical-impulse.
-- install.py copies this to ~/.config/hypr/custom/ and loads it from custom/general.lua.
-- Colors are not here: apply-palette.py writes them to ~/.config/hypr/hyprland/colors.lua.

hl.config({
    general = {
        gaps_in = 4, -- applied on both sides, 8 px between windows
        gaps_out = 16,
        border_size = 2,
    },
    decoration = {
        rounding = 0,
        blur = {
            enabled = true,
            xray = false,
            size = 8,
            passes = 2,
            noise = 0,
            contrast = 1,
            brightness = 1,
            vibrancy = 0,
            vibrancy_darkness = 0,
        },
        shadow = {
            enabled = false,
        },
        dim_inactive = false,
    },
})

-- One ease-out curve, nothing over 225 ms, no overshoot. speed 1 = 100 ms
hl.curve("term", { type = "bezier", points = {{0.2, 0.0}, {0.0, 1.0}} })
hl.curve("termExit", { type = "bezier", points = {{0.4, 0.0}, {1.0, 1.0}} })
hl.curve("termLinear", { type = "bezier", points = {{0, 0}, {1, 1}} })

hl.animation({ leaf = "windowsIn", enabled = true, speed = 2, bezier = "term", style = "popin 96%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.5, bezier = "termExit", style = "popin 96%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 2, bezier = "term", style = "slide" })
hl.animation({ leaf = "fadeIn", enabled = true, speed = 1.5, bezier = "term" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 1.5, bezier = "termExit" })
hl.animation({ leaf = "border", enabled = true, speed = 1.5, bezier = "termLinear" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 1.75, bezier = "term", style = "slide" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 1.25, bezier = "termExit", style = "fade" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 1.75, bezier = "term" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.25, bezier = "termExit" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 2.25, bezier = "term", style = "slide" })
hl.animation({ leaf = "specialWorkspaceIn", enabled = true, speed = 2.25, bezier = "term", style = "slidevert" })
hl.animation({ leaf = "specialWorkspaceOut", enabled = true, speed = 1.5, bezier = "termExit", style = "slidevert" })

-- Layer blur samples what is really behind the layer
hl.layer_rule({ match = { namespace = ".*" }, xray = false })
-- ii's screen corners pop in at 120 %, which overshoots; plain fade instead
hl.layer_rule({ match = { namespace = "quickshell:screenCorners" }, animation = "fade" })

-- Cursor: Bibata-Original-Classic (install.py downloads it to ~/.local/share/icons)
hl.env("XCURSOR_THEME", "Bibata-Original-Classic")
hl.env("XCURSOR_SIZE", "24")
hl.on("hyprland.start", function ()
    hl.exec_cmd("hyprctl setcursor Bibata-Original-Classic 24")
end)

-- Keyboard layouts without a plain "/" key (German: Shift + 7) can't reach ii's
-- Super + / cheat sheet, so it also opens with Super + H
hl.bind("SUPER + H", hl.dsp.global("quickshell:cheatsheetToggle"), { description = "Shell: Toggle cheatsheet" })
