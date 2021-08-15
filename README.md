# nvim-notify

**This is in proof of concept stage right now, changes are very likely but you are free to try it out and give feedback!**

A fancy, configurable, notification manager for NeoVim

![notify](https://user-images.githubusercontent.com/24252670/128085627-d1c0d929-5a98-4743-9cf0-5c1bc3367f0a.gif)

Credit to [sunjon](https://github.com/sunjon) for [the design](https://neovim.discourse.group/t/wip-animated-notifications-plugin/448) that inspired the appearance of this plugin.

## Usage

Simply call the module with a message!

```lua
require("notify")("My super important message")
```

Other plugins can use the notification windows by setting it as your default notify function

```lua
vim.notify = require("notify")
```

You can supply a level to change the border highlighting
```lua
vim.notify("This is an error message", "error")
```

There are a number of custom options that can be supplied in a table as the third argument:

- `timeout`: Number of milliseconds to show the window (default 5000)
- `on_open`: A function to call with the window ID as an argument after opening
- `on_close`: A function to call with the window ID as an argument after closing
- `title`: Title string for the header
- `icon`: Icon to use for the header

Sample code for the GIF above:
```lua
local plugin = "My Awesome Plugin"

vim.notify("This is an error message.\nSomething went wrong!", "error", {
	title = plugin,
	on_open = function()
		vim.notify("Attempting recovery.", vim.lsp.log_levels.WARN, {
			title = plugin,
		})
		local timer = vim.loop.new_timer()
		timer:start(2000, 0, function()
			vim.notify({ "Fixing problem.", "Please wait..." }, "info", {
				title = plugin,
				timeout = 3000,
				on_close = function()
					vim.notify("Problem solved", nil, { title = plugin })
					vim.notify("Error code 0x0395AF", 1, { title = plugin })
				end,
			})
		end)
	end,
})
```

## Configuration

You can set options by calling the `require("notify.config")setup()`. Here's an example of the default config:

```lua
require("notify.config").setup({
  -- Default level and default icon (must exist, name or integer)
  default_level = "info",

  -- Definition of each level (type of notification)
  levels = {
    -- Note: the default list matches vim.lsp.log_levels

    [0] = {  -- An integer, alternative to 'name'
      name = "trace",  -- minimal required field
      icon = "✎",
      border = {fg = "#848482"},  -- border highlight group
      title = {fg = "#797979"}  -- title hightligth group
    },
    [1] = {
      name = "debug",
      icon = "",
      border = {fg = "#008B8B"},
      title = {fg = "#008B8B"}
    },
    [2] = {
      name = "info",
      icon = "",
      border = {fg = "#6699CC"},
      title = {fg = "#6699CC"}
    },
    [3] = {
      name = "warn",
      icon = "",
      border = {fg = "#B6A642"},
      title = {fg = "#B5A642"}
    },
    [4] = {
      name = "error",
      icon = "",
      border = {fg = "#7A1F1F"},
      title = {fg = "#CC0000"}
    }
  }
})
```

If you want to add new notification themes (that do not necessarily match a log
level), you can just add a new entry (be careful not to overwrite existing
numbers):
```lua
config.setup({
  levels = {
    [#config.levels()] = {  -- If your levels are 1 indexed, use '+ 1' here
      name = "white",
      -- No 'icon =', this will use the default icon
      border = {fg = "#FFFFFF"},
      title = {fg = "#FFFFFF"}
    }
  }
})

vim.notify("This notification is entirely white", "white")
```
