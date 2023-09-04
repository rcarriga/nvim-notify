# nvim-notify

A fancy, configurable, notification manager for NeoVim

![notify](https://user-images.githubusercontent.com/24252670/130856848-e8289850-028f-4f49-82f1-5ea1b8912f5e.gif)

Credit to [sunjon](https://github.com/sunjon) for [the design](https://neovim.discourse.group/t/wip-animated-notifications-plugin/448) that inspired the appearance of this plugin.

* [Installation](#Installation)
* [Usage](#usage)
  - [Viewing History](#viewing-history)
* [Configuration](#configuration)
  - [Setup](#setup)
  - [Highlights](#highlights)
  - [Render Style](#render-style)
  - [Animation Style](#animation-style)
    + [Opening the window](#opening-the-window)
    + [Changing the window](#changing-the-window)

## Installation

### Prerequisites

Make sure to use a font which supported glyphs (icons), font can be found [here](https://github.com/ryanoasis/nerd-fonts).

24-bit colour is required, which can be enabled by adding this to your init.lua
```lua
vim.opt.termguicolors = true
```

Then you can install nvim-notify with the package manager of your choice.

[**dein**](https://github.com/Shougo/dein.vim):

```vim
call dein#add("rcarriga/nvim-notify")
```

[**vim-plug**](https://github.com/junegunn/vim-plug):

```vim
Plug 'rcarriga/nvim-notify'
```

[**packer**](https://github.com/wbthomason/packer.nvim):

```lua
use 'rcarriga/nvim-notify'
```

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

Updating an existing notification is also possible!

![](https://user-images.githubusercontent.com/24252670/152641078-92f3da72-f49f-4705-aec8-86512693445f.gif)


Use treesitter highlighting inside notifications with opacity changing

![](https://user-images.githubusercontent.com/24252670/165042795-565878a3-9c6d-4c0b-ab0d-6858515835c5.gif)

There are a number of custom options that can be supplied in a table as the third argument.
See `:h NotifyOptions` for details.

Sample code for the first GIF above:

```lua
local plugin = "My Awesome Plugin"

vim.notify("This is an error message.\nSomething went wrong!", "error", {
  title = plugin,
  on_open = function()
    vim.notify("Attempting recovery.", vim.log.levels.WARN, {
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

You can also use plenary's async library to avoid using callbacks:
```lua
local async = require("plenary.async")
local notify = require("notify").async

async.run(function()
  notify("Let's wait for this to close").events.close()
  notify("It closed!")
end)
```

Set a custom filetype to take advantage of treesitter highlighting:

```lua
vim.notify(text, "info", {
  title = "My Awesome Plugin",
  on_open = function(win)
    local buf = vim.api.nvim_win_get_buf(win)
    vim.api.nvim_buf_set_option(buf, "filetype", "markdown")
  end,
})
```


Check out the wiki for more examples!

### Viewing History

If you have [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) installed then you can use the `notify` extension to search the history:

```vim
:Telescope notify
```
or in lua
```lua
require('telescope').extensions.notify.notify(<opts>)
```

**Note:** If you lazy load `telescope` you should manually call `require("telescope").load_extension("notify")` before using the above commands. If you don't lazy load `telescope` then `notify` does this for you.

<p align="center">
  <img src="https://user-images.githubusercontent.com/24252670/136264308-2fcdfe57-a8f6-4b34-8ea1-e3a8349bc581.png" />
</p>

There is a command to display a log of the history.

```vim
:Notifications
```

<p align="center">
  <img src="https://user-images.githubusercontent.com/24252670/136264653-83038119-634b-48e7-8e8a-0edf4546efe2.png" />
</p>

You can get a list of past notifications with the history function
```lua
require("notify").history()
```

## Configuration

### Setup

You can optionally call the `setup` function to provide configuration options

See `:h notify.Config` for options and `:h notify.setup()` for default values.

### Highlights

You can define custom highlights by supplying highlight groups for each of the levels.
The naming scheme follows a simple structure: `Notify<upper case level name><section>`.
If you want to use custom levels, you can define the highlights for them or
they will follow the `INFO` highlights by default.

Here are the defaults:

```vim
highlight NotifyERRORBorder guifg=#8A1F1F
highlight NotifyWARNBorder guifg=#79491D
highlight NotifyINFOBorder guifg=#4F6752
highlight NotifyDEBUGBorder guifg=#8B8B8B
highlight NotifyTRACEBorder guifg=#4F3552
highlight NotifyERRORIcon guifg=#F70067
highlight NotifyWARNIcon guifg=#F79000
highlight NotifyINFOIcon guifg=#A9FF68
highlight NotifyDEBUGIcon guifg=#8B8B8B
highlight NotifyTRACEIcon guifg=#D484FF
highlight NotifyERRORTitle  guifg=#F70067
highlight NotifyWARNTitle guifg=#F79000
highlight NotifyINFOTitle guifg=#A9FF68
highlight NotifyDEBUGTitle  guifg=#8B8B8B
highlight NotifyTRACETitle  guifg=#D484FF
highlight link NotifyERRORBody Normal
highlight link NotifyWARNBody Normal
highlight link NotifyINFOBody Normal
highlight link NotifyDEBUGBody Normal
highlight link NotifyTRACEBody Normal
```

### Render Style

The appearance of the notifications can be configured, using either built-in methods or custom functions.
See `:help notify-render()` for details

1. "default"

![default](https://user-images.githubusercontent.com/24252670/141534868-fdcc9d03-9f7b-47fd-acfc-5a20b98e4e0a.png)

2. "minimal"

![image](https://user-images.githubusercontent.com/24252670/141534952-bb0cf491-5bb4-473c-9a67-8adb5b23b232.png)

3. "simple"

![image](https://user-images.githubusercontent.com/24252670/191683325-220208a0-90bf-4daa-b375-01b573ca524c.png)

4. "compact"

![image](https://user-images.githubusercontent.com/24252670/212632432-86621888-f885-4074-aed4-d12b5e291ab2.png)

5. "wrapped-compact"

Mostly same as `compact`, but lines are wrapped based on `max_width`, some padding is added.

![image](https://github.com/rcarriga/nvim-notify/assets/73286100/72237d45-6e3b-4c2a-8010-513a26871682)

Feel free to submit custom rendering functions to share with others!

### Animation Style

The animation is designed to work in stages. The first stage is the opening of
the window, and all subsequent stages can changes the position or opacity of
the window. You can use one of the built-in styles or provide your own in the setup.

1. "fade_in_slide_out"

![fade_slide](https://user-images.githubusercontent.com/24252670/130924913-f3a61f2c-2330-4426-a787-3cd7494fccc0.gif)

2. "fade"

![fade](https://user-images.githubusercontent.com/24252670/130924911-a89bef9b-e815-4aa5-a255-84bc23dd8c8e.gif)

3. "slide"

![slide](https://user-images.githubusercontent.com/24252670/130924905-656cabfc-9eb7-4e22-b6da-8a2a1f508fa5.gif)

4. "static"

![static](https://user-images.githubusercontent.com/24252670/130924902-8c77b5a1-6d13-48f4-98a9-866e58cb76e4.gif)

Custom styles can be provided by setting the config `stages` value to a list of
functions.

If you create a custom style, feel free to open a PR to submit it as a built-in style!

**NB.** This is a prototype API that is open to change. I am looking for
feedback on both issues or extra data that could be useful in creating
animation styles.

Check the [built-in styles](./lua/notify/stages/) to see examples

#### Opening the window

The first function in the list should return a table to be provided to
`nvim_open_win`, optionally including an extra `opacity` key which can be
between 0-100.

The function is given a state table that contains the following keys:

- `message: table` State of the message to be shown
  - `width` Width of the message buffer
  - `height` Height of the message buffer
- `open_windows: integer[]` List of all window IDs currently showing messages
- `buffer: integer` The buffer containing the rendered notification message.

If a notification can't be shown at the moment the function should return `nil`.

#### Changing the window

All following functions should return the goal values for the window to reach from it's current point.
They will receive the same state object as the initial function and a second argument of the window ID.

The following fields can be returned in a table:
- `col`
- `row`
- `height`
- `width`
- `opacity`

These can be provided as either numbers or as a table. If they are
provided as numbers then they will change instantly the value given.

If they are provided as a table, they will be treated as a value to animate towards.
This uses a dampened spring algorithm to provide a natural feel to the movement.

The table must contain the goal value as the 1st index (e.g. `{10}`)

All other values are provided with keys:

- `damping: number` How motion decays over time. Values less than 1 mean the spring can overshoot.
  - Bounds: >= 0
  - Default: 1
- `frequency: number` How fast the spring oscillates
  - Bounds: >= 0
  - Default: 1
- `complete: fun(value: number): bool` Function to determine if value has reached its goal. If not
  provided it will complete when the value rounded to 2 decimal places is equal
  to the goal.

Once the last function has reached its goals, the window is removed.

One of the stages should also return the key `time` set to true. This is
treated as the stage which the notification is on a timer. The goals of this
stage are not used to check if it is complete. The next stage will start
once the notification reaches its timeout.
