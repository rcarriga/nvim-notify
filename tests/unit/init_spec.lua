require("plenary.async").tests.add_to_env()

describe("checking public interface", function()
  local notify = require("notify")
  require("notify").setup({ background_colour = "#000000" })
  assert:add_formatter(vim.inspect)

  describe("notifications", function()
    it("returns all previous notifications", function()
      notify("test", "error")
      local notifs = notify.history()
      assert.are.same({
        {
          icon = "",
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
        notify.async("test", "error").open()
        assert.is.True(called)
      end)

      a.it("uses custom render in call", function()
        local called = false
        notify.async("test", "error", {
          render = function()
            called = true
          end,
        }).open()
        assert.is.True(called)
      end)
    end)
  end)
end)
