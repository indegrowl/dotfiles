# qutebrowser config. See :help and https://qutebrowser.org/doc/help/configuring.html
# Load settings changed via :set / the UI (autoconfig.yml)
config.load_autoconfig()

# Catppuccin Mocha, Peach accent
p = {
    "rosewater": "#f5e0dc", "red": "#f38ba8", "peach": "#fab387",
    "yellow": "#f9e2af", "green": "#a6e3a1", "blue": "#89b4fa",
    "text": "#cdd6f4", "subtext0": "#a6adc8", "overlay0": "#6c7086",
    "surface1": "#45475a", "surface0": "#313244",
    "base": "#1e1e2e", "mantle": "#181825", "crust": "#11111b",
}
accent = p["peach"]

c.fonts.default_family = "CaskaydiaCove Nerd Font"
c.fonts.default_size = "10pt"

# Web pages
c.colors.webpage.bg = p["base"]
c.colors.webpage.preferred_color_scheme = "dark"
c.colors.webpage.darkmode.enabled = True
c.colors.webpage.darkmode.policy.images = "never"

# Completion
c.colors.completion.fg = p["subtext0"]
c.colors.completion.odd.bg = p["mantle"]
c.colors.completion.even.bg = p["mantle"]
c.colors.completion.category.fg = accent
c.colors.completion.category.bg = p["base"]
c.colors.completion.category.border.top = p["base"]
c.colors.completion.category.border.bottom = p["base"]
c.colors.completion.item.selected.fg = p["text"]
c.colors.completion.item.selected.bg = p["surface1"]
c.colors.completion.item.selected.border.top = p["surface1"]
c.colors.completion.item.selected.border.bottom = p["surface1"]
c.colors.completion.item.selected.match.fg = accent
c.colors.completion.match.fg = accent
c.colors.completion.scrollbar.fg = p["surface1"]
c.colors.completion.scrollbar.bg = p["crust"]

# Context menu
c.colors.contextmenu.menu.bg = p["base"]
c.colors.contextmenu.menu.fg = p["text"]
c.colors.contextmenu.selected.bg = p["surface1"]
c.colors.contextmenu.selected.fg = p["text"]
c.colors.contextmenu.disabled.bg = p["mantle"]
c.colors.contextmenu.disabled.fg = p["overlay0"]

# Downloads
c.colors.downloads.bar.bg = p["base"]
c.colors.downloads.start.bg = p["blue"]
c.colors.downloads.start.fg = p["base"]
c.colors.downloads.stop.bg = p["green"]
c.colors.downloads.stop.fg = p["base"]
c.colors.downloads.error.bg = p["base"]
c.colors.downloads.error.fg = p["red"]

# Hints
c.colors.hints.bg = accent
c.colors.hints.fg = p["crust"]
c.colors.hints.match.fg = p["subtext0"]
c.hints.border = "1px solid " + p["crust"]
c.hints.radius = 0
c.colors.keyhint.bg = p["mantle"]
c.colors.keyhint.fg = p["text"]
c.colors.keyhint.suffix.fg = accent

# Messages
c.colors.messages.error.bg = p["base"]
c.colors.messages.error.fg = p["red"]
c.colors.messages.error.border = p["red"]
c.colors.messages.warning.bg = p["base"]
c.colors.messages.warning.fg = p["yellow"]
c.colors.messages.warning.border = p["yellow"]
c.colors.messages.info.bg = p["base"]
c.colors.messages.info.fg = p["text"]
c.colors.messages.info.border = p["surface1"]

# Prompts
c.colors.prompts.bg = p["mantle"]
c.colors.prompts.fg = p["text"]
c.colors.prompts.border = "1px solid " + accent
c.colors.prompts.selected.bg = p["surface1"]
c.colors.prompts.selected.fg = p["text"]
c.prompt.radius = 0

# Statusbar
c.colors.statusbar.normal.bg = p["base"]
c.colors.statusbar.normal.fg = p["text"]
c.colors.statusbar.insert.bg = p["crust"]
c.colors.statusbar.insert.fg = p["green"]
c.colors.statusbar.command.bg = p["base"]
c.colors.statusbar.command.fg = p["text"]
c.colors.statusbar.passthrough.bg = p["base"]
c.colors.statusbar.passthrough.fg = p["blue"]
c.colors.statusbar.caret.bg = p["base"]
c.colors.statusbar.caret.fg = accent
c.colors.statusbar.caret.selection.bg = p["base"]
c.colors.statusbar.caret.selection.fg = accent
c.colors.statusbar.private.bg = p["mantle"]
c.colors.statusbar.private.fg = p["subtext0"]
c.colors.statusbar.command.private.bg = p["mantle"]
c.colors.statusbar.command.private.fg = p["subtext0"]
c.colors.statusbar.progress.bg = accent
c.colors.statusbar.url.fg = p["text"]
c.colors.statusbar.url.hover.fg = p["blue"]
c.colors.statusbar.url.success.http.fg = p["text"]
c.colors.statusbar.url.success.https.fg = p["green"]
c.colors.statusbar.url.warn.fg = p["yellow"]
c.colors.statusbar.url.error.fg = p["red"]

# Tabs: square, flat
c.colors.tabs.bar.bg = p["crust"]
c.colors.tabs.odd.bg = p["mantle"]
c.colors.tabs.even.bg = p["mantle"]
c.colors.tabs.odd.fg = p["overlay0"]
c.colors.tabs.even.fg = p["overlay0"]
c.colors.tabs.selected.odd.bg = p["base"]
c.colors.tabs.selected.even.bg = p["base"]
c.colors.tabs.selected.odd.fg = accent
c.colors.tabs.selected.even.fg = accent
c.colors.tabs.pinned.odd.bg = p["mantle"]
c.colors.tabs.pinned.even.bg = p["mantle"]
c.colors.tabs.pinned.odd.fg = p["blue"]
c.colors.tabs.pinned.even.fg = p["blue"]
c.colors.tabs.pinned.selected.odd.bg = p["base"]
c.colors.tabs.pinned.selected.even.bg = p["base"]
c.colors.tabs.pinned.selected.odd.fg = accent
c.colors.tabs.pinned.selected.even.fg = accent
c.colors.tabs.indicator.start = p["blue"]
c.colors.tabs.indicator.stop = p["green"]
c.colors.tabs.indicator.error = p["red"]
c.tabs.indicator.width = 0
c.tabs.padding = {"top": 4, "bottom": 4, "left": 8, "right": 8}
c.tabs.favicons.scale = 1.0

c.colors.tooltip.bg = p["base"]
c.colors.tooltip.fg = p["text"]
