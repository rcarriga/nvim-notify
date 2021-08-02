# nvim-notify

**This is in proof of concept stage right now, changes are very likely but you are free to try it out and give feedback!**

A fancy, configurable, notification manager for NeoVim

![notify](https://user-images.githubusercontent.com/24252670/128085627-d1c0d929-5a98-4743-9cf0-5c1bc3367f0a.gif)

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

TODO!
