local async = require("plenary.async")
async.tests.add_to_env()
vim.opt.termguicolors = true
A = vim.schedule_wrap(function(...)
  print(vim.inspect(...))
end)

describe("checking public interface", function()
  local notify = require("notify")
  local async_notify = require("notify").async
  assert:add_formatter(vim.inspect)

  before_each(function()
    notify.setup({ background_colour = "#000000" })
    notify.dismiss({ pending = true, silent = true })
  end)

  describe("notifications", function()
    it("returns all previous notifications", function()
      notify("test", "error")
      local notifs = notify.history()
      assert.are.same({
        {
          icon = "",
          id = 1,
          level = "ERROR",
          message = { "test" },
          render = notifs[1].render,
          time = notifs[1].time,
          title = { "", notifs[1].title[2] },
        },
      }, notifs)
    end)

    describe("rendering", function()
      a.it("uses custom render in config", function()
        local called = false
        notify.setup({
          background_colour = "#000000",
          render = function()
            called = true
          end,
        })
        notify.async("test", "error").events.open()
        assert.is.True(called)
      end)

      a.it("uses custom render in call", function()
        local called = false
        notify
          .async("test", "error", {
            render = function()
              called = true
            end,
          }).events
          .open()
        assert.is.True(called)
      end)
    end)

    describe("replacing", function()
      it("inherits options", function()
        local orig = notify("first", "info", { title = "test", icon = "x" })
        local next = notify("second", nil, { replace = orig })

        assert.are.same(
          next,
          vim.tbl_extend("force", orig, { id = next.id, message = next.message })
        )
      end)

      a.it("uses same window", function()
        local orig = async_notify("first", "info", { timeout = false })
        local win = orig.events.open()
        async_notify("second", nil, { replace = orig, timeout = 100 })
        async.util.scheduler()
        local found = false
        local bufs = vim.api.nvim_list_bufs()
        for _, buf in ipairs(bufs) do
          if vim.api.nvim_buf_get_lines(buf, 0, -1, false)[1] == "second" then
            assert.Not(found)
            assert.same(vim.fn.bufwinid(buf), win)
            found = true
          end
        end
      end)
    end)
  end)

  a.it("uses the confgured minimum width", function()
    notify.setup({
      background_colour = "#000000",
      minimum_width = 20,
    })
    local win = notify.async("test").events.open()
    assert.equal(vim.api.nvim_win_get_width(win), 20)
  end)

  a.it("uses the configured max width", function()
    notify.setup({
      background_colour = "#000000",
      max_width = function()
        return 3
      end,
    })
    local win = notify.async("test").events.open()
    assert.equal(vim.api.nvim_win_get_width(win), 3)
  end)

  a.it("uses the configured max height", function()
    local instance = notify.instance({
      background_colour = "#000000",
      max_height = function()
        return 3
      end,
    }, false)
    local win = instance.async("test").events.open()
    assert.equal(vim.api.nvim_win_get_height(win), 3)
  end)

  a.it("renders title as longest line", function()
    local instance = notify.instance({
      background_colour = "#000000",
      minimum_width = 10,
    }, false)
    local win = instance.async("test", nil, { title = { string.rep("a", 16), "" } }).events.open()
    assert.equal(21, vim.api.nvim_win_get_width(win))
  end)

  a.it("renders notification above config level", function()
    local win =
      notify.async("test", "info", { message = { string.rep("a", 16), "" } }).events.open()
    assert.Not.Nil(vim.api.nvim_win_get_config(win))
  end)

  a.it("doesn't render notification below config level", function()
    async.run(function()
      local notif = notify.async("test", "debug", { message = { string.rep("a", 16), "" } })
      local win = notif.events.open()
      async.api.nvim_buf_set_option(async.api.nvim_win_get_buf(win), "filetype", "test")
    end)
    async.util.sleep(100)
    local bufs = vim.api.nvim_list_bufs()
    for _, buf in ipairs(bufs) do
      assert.Not.same(vim.api.nvim_buf_get_option(buf, "filetype"), "test")
    end
  end)
  a.it("refreshes timeout on replace", function()
    -- Don't want to spend time animating
    notify.setup({ background_colour = "#000000", stages = "static" })

    local notif = notify.async("test", "error", { timeout = 500 })
    local win = notif.events.open()
    a.util.sleep(300)
    notify.async("test2", "error", { replace = notif })
    a.util.sleep(300)
    a.util.scheduler()
    assert(vim.api.nvim_win_is_valid(win))
  end)
end)
