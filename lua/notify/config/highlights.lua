local M = {}

function M.setup()
  vim.cmd([[
    hi default NotifyERROR guifg=#8A1F1F
    hi default NotifyWARN guifg=#79491D
    hi default NotifyINFO guifg=#4F6752
    hi default NotifyDEBUG guifg=#8B8B8B
    hi default NotifyTRACE guifg=#4F3552
    hi default NotifyTRACE guifg=#4F3552
    hi default NotifyERRORTitle guifg=#F70067
    hi default NotifyWARNTitle guifg=#F79000
    hi default NotifyINFOTitle guifg=#A9FF68
    hi default NotifyDEBUGTitle guifg=#8B8B8B
    hi default NotifyTRACETitle guifg=#D484FF
    hi default link NotifyERRORBody Normal
    hi default link NotifyWARNBody Normal
    hi default link NotifyINFOBody Normal
    hi default link NotifyDEBUGBody Normal
    hi default link NotifyTRACEBody Normal
]])
end

M.setup()

vim.cmd([[
  augroup NvimNotifyRefreshHighlights
    autocmd!
    autocmd ColorScheme * lua require('notify.config.highlights').setup()
  augroup END
]])

return M
