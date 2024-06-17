-- PENDING https://github.com/rcarriga/nvim-notify/pull/280
-- Like `minimal`, but wrapped.
--------------------------------------------------------------------------------

---@param line string
---@param width number
---@return string[]
local function split_length(line, width)
	local text = {}
	local next_line
	while true do
		if #line == 0 then return text end
		next_line, line = line:sub(1, width), line:sub(width + 1)
		text[#text + 1] = next_line
	end
end

---@param lines string[]
---@param max_width number
---@return string[]
local function custom_wrap(lines, max_width)
	local right_pad = "  "
	local wrapped_lines = {}
	for _, line in pairs(lines) do
		local new_lines = split_length(line, max_width - #right_pad)
		for _, nl in ipairs(new_lines) do
			table.insert(wrapped_lines, nl:gsub("^%s+", "") .. right_pad)
		end
	end
	wrapped_lines[1] = " " .. (wrapped_lines[1] or "")
	return wrapped_lines
end

---@param bufnr number
---@param notif notify.Record
---@param highlights notify.Highlights
---@param config notify.Config
return function(bufnr, notif, highlights, config)
	local namespace = require("notify.render.base").namespace()
	local max_width = config.max_width() or 80
	local message = custom_wrap(notif.message, max_width)
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, message)

	-- add padding to the left/right
	for ln = 1, #message do
		vim.api.nvim_buf_set_extmark(bufnr, namespace, ln, 0, {
			virt_text = { { " ", highlights.body } },
			virt_text_pos = "inline",
			priority = 50,
		})
		vim.api.nvim_buf_set_extmark(bufnr, namespace, ln, 0, {
			virt_text = { { " ", highlights.body } },
			virt_text_pos = "right_align",
			priority = 50,
		})
	end
end
