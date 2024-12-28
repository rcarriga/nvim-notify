local M = {}

function M.pick()
  if pcall(_G.require, "telescope.config") then
    require("telescope").extensions.notify.noitfy({})
  elseif pcall(_G.require, "fzf-lua") then
    require("notify.integrations.fzf").open({})
  else
    error("No picker available")
  end
end
return M
