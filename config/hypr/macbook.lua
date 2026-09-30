-- MacBook Pro Touch Bar (2016-2017) input settings for Omarchy.
-- install.sh appends a require for this file to ~/.config/hypr/input.lua.

-- MacBook ISO keyboard: US layout with § / ± on the key left of 1.
-- No kb_options: Omarchy's default "compose:caps" turns Caps Lock into Compose.
hl.config({ input = { kb_layout = "usmac", kb_options = "" } })

-- macOS-style workspace switching: swipe left/right with 4 fingers.
hl.gesture({ fingers = 4, direction = "horizontal", action = "workspace" })

-- Two-finger tap = right click, three-finger tap = middle click.
hl.config({ input = { touchpad = { tap_to_click = true, tap_button_map = "lrm" } } })

-- macOS-style natural scrolling: content moves with your fingers.
hl.config({ input = { touchpad = { natural_scroll = true } } })

-- Select/drag without pressing hard (the Force Touch pad only "clicks" on a firm press):
-- slide with three fingers = drag/select (macOS-style three-finger drag).
-- tap-and-drag and drag lock are off: a stray tap plus a touch started selections by itself.
hl.config({ input = { touchpad = { tap_and_drag = false, drag_lock = 0, drag_3fg = 1 } } })
