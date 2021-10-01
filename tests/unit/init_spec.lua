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
          time = notifs[1].time,
          title = { "", notifs[1].title[2] },
        },
      }, notifs)
    end)
  end)
end)
