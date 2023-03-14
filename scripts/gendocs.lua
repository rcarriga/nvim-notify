-- TODO: A lot of this is private code from minidoc, which could be removed if made public

local minidoc = require("mini.doc")

local H = {}
--stylua: ignore start
H.pattern_sets = {
  -- Patterns for working with afterlines. At the moment deliberately crafted
  -- to work only on first line without indent.

  -- Determine if line is a function definition. Captures function name and
  -- arguments. For reference see '2.5.9 – Function Definitions' in Lua manual.
  afterline_fundef = {
    '^function%s+(%S-)(%b())', -- Regular definition
    '^local%s+function%s+(%S-)(%b())', -- Local definition
    '^(%S+)%s*=%s*function(%b())', -- Regular assignment
    '^local%s+(%S+)%s*=%s*function(%b())', -- Local assignment
  },

  -- Determine if line is a general assignment
  afterline_assign = {
    '^(%S-)%s*=', -- General assignment
    '^local%s+(%S-)%s*=', -- Local assignment
  },

  -- Patterns to work with type descriptions
  -- (see https://github.com/sumneko/lua-language-server/wiki/EmmyLua-Annotations#types-and-type)
  types = {
    'table%b<>',
    'fun%b(): %S+', 'fun%b()', 'async fun%b(): %S+', 'async fun%b()',
    'nil', 'any', 'boolean', 'string', 'number', 'integer', 'function', 'table', 'thread', 'userdata', 'lightuserdata',
    '%.%.%.',
    "%S+",

  },
}


H.apply_config = function(config)
  MiniDoc.config = config
end

H.is_disabled = function()
  return vim.g.minidoc_disable == true or vim.b.minidoc_disable == true
end

H.get_config = function(config)
  return vim.tbl_deep_extend("force", MiniDoc.config, vim.b.minidoc_config or {}, config or {})
end

-- Work with project specific script ==========================================
H.execute_project_script = function(input, output, config)
  -- Don't process script if there are more than one active `generate` calls
  if H.generate_is_active then
    return
  end

  -- Don't process script if at least one argument is not default
  if not (input == nil and output == nil and config == nil) then
    return
  end

  -- Store information
  local global_config_cache = vim.deepcopy(MiniDoc.config)
  local local_config_cache = vim.b.minidoc_config

  -- Pass information to a possible `generate()` call inside script
  H.generate_is_active = true
  H.generate_recent_output = nil

  -- Execute script
  local success = pcall(vim.cmd, "luafile " .. H.get_config(config).script_path)

  -- Restore information
  MiniDoc.config = global_config_cache
  vim.b.minidoc_config = local_config_cache
  H.generate_is_active = nil

  return success
end

-- Default documentation targets ----------------------------------------------
H.default_input = function()
  -- Search in current and recursively in other directories for files with
  -- 'lua' extension
  local res = {}
  for _, dir_glob in ipairs({ ".", "lua/**", "after/**", "colors/**" }) do
    local files = vim.fn.globpath(dir_glob, "*.lua", false, true)

    -- Use full paths
    files = vim.tbl_map(function(x)
      return vim.fn.fnamemodify(x, ":p")
    end, files)

    -- Put 'init.lua' first among files from same directory
    table.sort(files, function(a, b)
      if vim.fn.fnamemodify(a, ":h") == vim.fn.fnamemodify(b, ":h") then
        if vim.fn.fnamemodify(a, ":t") == "init.lua" then
          return true
        end
        if vim.fn.fnamemodify(b, ":t") == "init.lua" then
          return false
        end
      end

      return a < b
    end)
    table.insert(res, files)
  end

  return vim.tbl_flatten(res)
end

H.default_output = function()
  local cur_dir = vim.fn.fnamemodify(vim.loop.cwd(), ":t:r")
  return ("doc/%s.txt"):format(cur_dir)
end

-- Parsing --------------------------------------------------------------------
H.lines_to_block_arr = function(lines, config)
  local matched_prev, matched_cur

  local res = {}
  local block_raw = { annotation = {}, section_id = {}, afterlines = {}, line_begin = 1 }

  for i, l in ipairs(lines) do
    local from, to, section_id = config.annotation_extractor(l)
    matched_prev, matched_cur = matched_cur, from ~= nil

    if matched_cur then
      if not matched_prev then
        -- Finish current block
        block_raw.line_end = i - 1
        table.insert(res, H.raw_block_to_block(block_raw, config))

        -- Start new block
        block_raw = { annotation = {}, section_id = {}, afterlines = {}, line_begin = i }
      end

      -- Add annotation line without matched annotation pattern
      table.insert(block_raw.annotation, ("%s%s"):format(l:sub(0, from - 1), l:sub(to + 1)))

      -- Add section id (it is empty string in case of no section id capture)
      table.insert(block_raw.section_id, section_id or "")
    else
      -- Add afterline
      table.insert(block_raw.afterlines, l)
    end
  end
  block_raw.line_end = #lines
  table.insert(res, H.raw_block_to_block(block_raw, config))

  return res
end

-- Raw block structure is an intermediate step added for convenience. It is
-- a table with the following keys:
-- - `annotation` - lines (after removing matched annotation pattern) that were
--   parsed as annotation.
-- - `section_id` - array with length equal to `annotation` length with strings
--   captured as section id. Empty string of no section id was captured.
-- - Everything else is used as block info (like `afterlines`, etc.).
H.raw_block_to_block = function(block_raw, config)
  if #block_raw.annotation == 0 and #block_raw.afterlines == 0 then
    return nil
  end

  local block = H.new_struct("block", {
    afterlines = block_raw.afterlines,
    line_begin = block_raw.line_begin,
    line_end = block_raw.line_end,
  })
  local block_begin = block.info.line_begin

  -- Parse raw block annotation lines from top to bottom. New section starts
  -- when section id is detected in that line.
  local section_cur = H.new_struct(
    "section",
    { id = config.default_section_id, line_begin = block_begin }
  )

  for i, annotation_line in ipairs(block_raw.annotation) do
    local id = block_raw.section_id[i]
    if id ~= "" then
      -- Finish current section
      if #section_cur > 0 then
        section_cur.info.line_end = block_begin + i - 2
        block:insert(section_cur)
      end

      -- Start new section
      section_cur = H.new_struct("section", { id = id, line_begin = block_begin + i - 1 })
    end

    section_cur:insert(annotation_line)
  end

  if #section_cur > 0 then
    section_cur.info.line_end = block_begin + #block_raw.annotation - 1
    block:insert(section_cur)
  end

  return block
end

-- Hooks ----------------------------------------------------------------------
H.apply_structure_hooks = function(doc, hooks)
  for _, file in ipairs(doc) do
    for _, block in ipairs(file) do
      hooks.block_pre(block)

      for _, section in ipairs(block) do
        hooks.section_pre(section)

        local hook = hooks.sections[section.info.id]
        if hook ~= nil then
          hook(section)
        end

        hooks.section_post(section)
      end

      hooks.block_post(block)
    end

    hooks.file(file)
  end

  hooks.doc(doc)
end

H.alias_register = function(s)
  if #s == 0 then
    return
  end

  -- Remove first word (with bits of surrounding whitespace) while capturing it
  local alias_name
  s[1] = s[1]:gsub("%s*(%S+) ?", function(x)
    alias_name = x
    return ""
  end, 1)
  if alias_name == nil then
    return
  end

  MiniDoc.current.aliases = MiniDoc.current.aliases or {}
  MiniDoc.current.aliases[alias_name] = table.concat(s, "\n")
end

H.alias_replace = function(s)
  if MiniDoc.current.aliases == nil then
    return
  end

  for i, _ in ipairs(s) do
    for alias_name, alias_desc in pairs(MiniDoc.current.aliases) do
      -- Escape special characters. This is done here and not while registering
      -- alias to allow user to refer to aliases by its original name.
      -- Store escaped words in separate variables because `vim.pesc()` returns
      -- two values which might conflict if outputs are used as arguments.
      local name_escaped = vim.pesc(alias_name)
      local desc_escaped = vim.pesc(alias_desc)
      s[i] = s[i]:gsub(name_escaped, desc_escaped)
    end
  end
end

H.toc_register = function(s)
  MiniDoc.current.toc = MiniDoc.current.toc or {}
  table.insert(MiniDoc.current.toc, s)
end

H.toc_insert = function(s)
  if MiniDoc.current.toc == nil then
    return
  end

  -- Render table of contents
  local toc_lines = {}
  for _, toc_entry in ipairs(MiniDoc.current.toc) do
    local _, tag_section = toc_entry.parent:has_descendant(function(x)
      return type(x) == "table" and x.type == "section" and x.info.id == "@tag"
    end)
    tag_section = tag_section or {}

    local lines = {}
    for i = 1, math.max(#toc_entry, #tag_section) do
      local left = toc_entry[i] or ""
      -- Use tag refernce instead of tag enclosure
      local right = string.match(tag_section[i], "%*.*%*"):gsub("%*", "|")
      -- local right = vim.trim((tag_section[i] or ""):gsub("%*", "|"))
      -- Add visual line only at first entry (while not adding trailing space)
      local filler = i == 1 and "." or (right == "" and "" or " ")
      -- Make padding of 2 spaces at both left and right
      local n_filler = math.max(74 - H.visual_text_width(left) - H.visual_text_width(right), 3)
      table.insert(lines, ("  %s%s%s"):format(left, filler:rep(n_filler), right))
    end

    table.insert(toc_lines, lines)

    -- Don't show `toc_entry` lines in output
    toc_entry:clear_lines()
  end

  for _, l in ipairs(vim.tbl_flatten(toc_lines)) do
    s:insert(l)
  end
end

H.add_section_heading = function(s, heading)
  if #s == 0 or s.type ~= "section" then
    return
  end

  -- Add heading
  s:insert(1, ("%s~"):format(heading))
end

H.enclose_var_name = function(s)
  if #s == 0 or s.type ~= "section" then
    return
  end

  s[1] = s[1]:gsub("(%S+)", "{%1}", 1)
end

---@param init number Start of searching for first "type-like" string. It is
---   needed to not detect type early. Like in `@param a_function function`.
---@private
H.enclose_type = function(s, enclosure, init)
  if #s == 0 or s.type ~= "section" then
    return
  end
  enclosure = enclosure or "`%(%1%)`"
  init = init or 1

  local cur_type = H.match_first_pattern(s[1], H.pattern_sets["types"], init)
  if #cur_type == 0 then
    return
  end

  -- Add `%S*` to front and back of found pattern to support their combination
  -- with `|`. Also allows using `[]` and `?` prefixes.
  local type_pattern = ("(%%S*%s%%S*)"):format(vim.pesc(cur_type[1]))

  -- Avoid replacing possible match before `init`
  local l_start = s[1]:sub(1, init - 1)
  local l_end = s[1]:sub(init):gsub(type_pattern, enclosure, 1)
  s[1] = ("%s%s"):format(l_start, l_end)
end

-- Infer data from afterlines -------------------------------------------------
H.infer_header = function(b)
  local has_signature = b:has_descendant(function(x)
    return type(x) == "table" and x.type == "section" and x.info.id == "@signature"
  end)
  local has_tag = b:has_descendant(function(x)
    return type(x) == "table" and x.type == "section" and x.info.id == "@tag"
  end)

  if has_signature and has_tag then
    return
  end

  local l_all = table.concat(b.info.afterlines, " ")
  local tag, signature

  -- Try function definition
  local fun_capture = H.match_first_pattern(l_all, H.pattern_sets["afterline_fundef"])
  if #fun_capture > 0 then
    tag = tag or ("%s()"):format(fun_capture[1])
    signature = signature or ("%s%s"):format(fun_capture[1], fun_capture[2])
  end

  -- Try general assignment
  local assign_capture = H.match_first_pattern(l_all, H.pattern_sets["afterline_assign"])
  if #assign_capture > 0 then
    tag = tag or assign_capture[1]
    signature = signature or assign_capture[1]
  end

  if tag ~= nil then
    -- First insert signature (so that it will appear after tag section)
    if not has_signature then
      b:insert(1, H.as_struct({ signature }, "section", { id = "@signature" }))
    end

    -- Insert tag
    if not has_tag then
      b:insert(1, H.as_struct({ tag }, "section", { id = "@tag" }))
    end
  end
end

function H.is_module(name)
  if string.find(name, "%(") then
    return false
  end
  if string.find(name, "[A-Z]") then
    return false
  end
  return true
end

H.format_signature = function(line)
  -- Try capture function signature
  local name, args = line:match("(%S-)(%b())")


  -- Otherwise pick first word
  name = name or line:match("(%S+)")
  if not args and H.is_module(name) then
    return ""
  end
  local name_elems = vim.split(name, ".", { plain = true })
  name = name_elems[#name_elems]

  if not name then
    return ""
  end

  -- Tidy arguments
  if args and args ~= "()" then
    local arg_parts = vim.split(args:sub(2, -2), ",")
    local arg_list = {}
    for _, a in ipairs(arg_parts) do
      -- Enclose argument in `{}` while controlling whitespace
      table.insert(arg_list, ("{%s}"):format(vim.trim(a)))
    end
    args = ("(%s)"):format(table.concat(arg_list, ", "))
  end

  return ("`%s`%s"):format(name, args or "")
end

-- Work with structures -------------------------------------------------------
-- Constructor
H.new_struct = function(struct_type, info)
  local output = {
    info = info or {},
    type = struct_type,
  }

  output.insert = function(self, index, child)
    -- Allow both `x:insert(child)` and `x:insert(1, child)`
    if child == nil then
      child, index = index, #self + 1
    end

    if type(child) == "table" then
      child.parent = self
      child.parent_index = index
    end

    table.insert(self, index, child)

    H.sync_parent_index(self)
  end

  output.remove = function(self, index)
    index = index or #self
    table.remove(self, index)

    H.sync_parent_index(self)
  end

  output.has_descendant = function(self, predicate)
    local bool_res, descendant = false, nil
    H.apply_recursively(function(x)
      if not bool_res and predicate(x) then
        bool_res = true
        descendant = x
      end
    end, self)
    return bool_res, descendant
  end

  output.has_lines = function(self)
    return self:has_descendant(function(x)
      return type(x) == "string"
    end)
  end

  output.clear_lines = function(self)
    for i, x in ipairs(self) do
      if type(x) == "string" then
        self[i] = nil
      else
        x:clear_lines()
      end
    end
  end

  return output
end

H.sync_parent_index = function(x)
  for i, _ in ipairs(x) do
    if type(x[i]) == "table" then
      x[i].parent_index = i
    end
  end
  return x
end

-- Converter (this ensures that children have proper parent-related data)
H.as_struct = function(array, struct_type, info)
  -- Make default info `info` for cases when structure is created manually
  local default_info = ({
    section = { id = "@text", line_begin = -1, line_end = -1 },
    block = { afterlines = {}, line_begin = -1, line_end = -1 },
    file = { path = "" },
    doc = { input = {}, output = "", config = H.get_config() },
  })[struct_type]
  info = vim.tbl_deep_extend("force", default_info, info or {})

  local res = H.new_struct(struct_type, info)
  for _, x in ipairs(array) do
    res:insert(x)
  end
  return res
end

-- Work with text -------------------------------------------------------------
H.ensure_indent = function(text, n_indent_target)
  local lines = vim.split(text, "\n")
  local n_indent, n_indent_cur = math.huge, math.huge

  -- Find number of characters in indent
  for _, l in ipairs(lines) do
    -- Update lines indent: minimum of all indents except empty lines
    if n_indent > 0 then
      _, n_indent_cur = l:find("^%s*")
      -- Condition "current n-indent equals line length" detects empty line
      if (n_indent_cur < n_indent) and (n_indent_cur < l:len()) then
        n_indent = n_indent_cur
      end
    end
  end

  -- Ensure indent
  local indent = string.rep(" ", n_indent_target)
  for i, l in ipairs(lines) do
    if l ~= "" then
      lines[i] = indent .. l:sub(n_indent + 1)
    end
  end

  return table.concat(lines, "\n")
end

H.align_text = function(text, width, direction)
  if type(text) ~= "string" then
    return
  end
  text = vim.trim(text)
  width = width or 78
  direction = direction or "left"

  -- Don't do anything if aligning left or line is a whitespace
  if direction == "left" or text:find("^%s*$") then
    return text
  end

  local n_left = math.max(0, 78 - H.visual_text_width(text))
  if direction == "center" then
    n_left = math.floor(0.5 * n_left)
  end

  return (" "):rep(n_left) .. text
end

H.visual_text_width = function(text)
  -- Ignore concealed characters (usually "invisible" in 'help' filetype)
  local _, n_concealed_chars = text:gsub("([*|`])", "%1")
  return vim.fn.strdisplaywidth(text) - n_concealed_chars
end

--- Return earliest match among many patterns
---
--- Logic here is to test among several patterns. If several got a match,
--- return one with earliest match.
---
---@private
H.match_first_pattern = function(text, pattern_set, init)
  local start_tbl = vim.tbl_map(function(pattern)
    return text:find(pattern, init) or math.huge
  end, pattern_set)

  local min_start, min_id = math.huge, nil
  for id, st in ipairs(start_tbl) do
    if st < min_start then
      min_start, min_id = st, id
    end
  end

  if min_id == nil then
    return {}
  end
  return { text:match(pattern_set[min_id], init) }
end

-- Utilities ------------------------------------------------------------------
H.apply_recursively = function(f, x, used)
  used = used or {}
  if used[x] then
    return
  end
  f(x)
  used[x] = true

  if type(x) == "table" then
    for _, t in ipairs(x) do
      H.apply_recursively(f, t, used)
    end
  end
end

H.collect_strings = function(x)
  local res = {}
  H.apply_recursively(function(y)
    if type(y) == "string" then
      -- Allow `\n` in strings
      table.insert(res, vim.split(y, "\n"))
    end
  end, x)
  -- Flatten to only have strings and not table of strings (from `vim.split`)
  return vim.tbl_flatten(res)
end

H.file_read = function(path)
  local file = assert(io.open(path))
  local contents = file:read("*all")
  file:close()

  return vim.split(contents, "\n")
end

H.file_write = function(path, lines)
  -- Ensure target directory exists
  local dir = vim.fn.fnamemodify(path, ":h")
  vim.fn.mkdir(dir, "p")

  -- Write to file
  vim.fn.writefile(lines, path, "b")
end

H.full_path = function(path)
  return vim.fn.resolve(vim.fn.fnamemodify(path, ":p"))
end

H.message = function(msg)
  vim.cmd("echomsg " .. vim.inspect("(mini.doc) " .. msg))
end

minidoc.setup({})
minidoc.generate(
  {
    "./lua/notify/init.lua",
    "./lua/notify/config/init.lua",
    "./lua/notify/render/init.lua",
  },
  nil,
  {
    hooks = vim.tbl_extend("force", minidoc.default_hooks, {
      block_post = function(b)
        if not b:has_lines() then return end

        local found_param, found_field = false, false
        local n_tag_sections = 0
        H.apply_recursively(function(x)
          if not (type(x) == 'table' and x.type == 'section') then return end

          -- Add headings before first occurence of a section which type usually
          -- appear several times
          if not found_param and x.info.id == '@param' then
            H.add_section_heading(x, 'Parameters')
            found_param = true
          end
          if not found_field and x.info.id == '@field' then
            H.add_section_heading(x, 'Fields')
            found_field = true
          end

          if x.info.id == '@tag' then
            local text = x[1]
            local tag = string.match(text, "%*.*%*")
            local prefix = (string.sub(tag, 2, #tag - 1))
            if not H.is_module(prefix) then
              prefix = ""
            end
            local n_filler = math.max(78 - H.visual_text_width(prefix) - H.visual_text_width(tag), 3)
            local line = ("%s%s%s"):format(prefix, (" "):rep(n_filler), tag)
            x:remove(1)
            x:insert(1, line)
            x.parent:remove(x.parent_index)
            n_tag_sections = n_tag_sections + 1
            x.parent:insert(n_tag_sections, x)
          end
        end, b)

        -- b:insert(1, H.as_struct({ string.rep('=', 78) }, 'section'))
        b:insert(H.as_struct({ '' }, 'section'))
      end,


      doc = function(d)
        -- Render table of contents
        H.apply_recursively(function(x)
          if not (type(x) == 'table' and x.type == 'section' and x.info.id == '@toc') then return end
          H.toc_insert(x)
        end, d)

        -- Insert modeline
        d:insert(
          H.as_struct(
            { H.as_struct({ H.as_struct({ ' vim:tw=78:ts=8:noet:ft=help:norl:' }, 'section') }, 'block') },
            'file'
          )
        )
      end,
      sections = {
        ['@generic'] = function(s)
          s:remove(1)
        end,
        ['@field'] = function(s)
          -- H.mark_optional(s)
          if string.find(s[1], "^private ") then
            s:remove(1)
            return
          end
          H.enclose_var_name(s)
          H.enclose_type(s, '`%(%1%)`', s[1]:find('%s'))
        end,
        ['@alias'] = function(s)
          local name = s[1]:match('%s*(%S*)')
          local alias = s[1]:match('%s(.*)$')
          s[1] = ("`%s` → `%s`"):format(name, alias)
          H.add_section_heading(s, 'Alias')
          s:insert(1, H.as_struct({ ("*%s*"):format(name) }, "section", { id = "@tag" }))
        end,

        ['@param'] = function(s)
          H.enclose_var_name(s)
          H.enclose_type(s, '`%(%1%)`', s[1]:find('%s'))
        end,
        ['@return'] = function(s)
          H.enclose_type(s, '`%(%1%)`', 1)
          H.add_section_heading(s, 'Return')
        end,
        ['@nodoc'] = function(s) s.parent:clear_lines() end,
        ['@class'] = function(s)
          H.enclose_var_name(s)
          -- Add heading
          local line = s[1]
          s:remove(1)
          local class_name = string.match(line, "%{(.*)%}")
          local inherits = string.match(line, ": (.*)")
          if inherits then
            s:insert(1, ("Inherits: `%s`"):format(inherits))
            s:insert(2, "")
          end
          s:insert(1, H.as_struct({ ("*%s*"):format(class_name) }, "section", { id = "@tag" }))
        end,

        ['@signature'] = function(s)
          s[1] = H.format_signature(s[1])
          if s[1] ~= "" then
            table.insert(s, "")
          end
        end,

      },

      file = function(f)
        if not f:has_lines() then
          return
        end

        if f.info.path ~= "./lua/notify/init.lua" then
          f:insert(1, H.as_struct({ H.as_struct({ string.rep("=", 78) }, "section") }, "block"))
          f:insert(H.as_struct({ H.as_struct({ "" }, "section") }, "block"))
        else
          f:insert(
            1,
            H.as_struct(
              {
                H.as_struct(
                  { "*nvim-notify.txt*   A fancy, configurable notification manager for NeoVim" },
                  "section"
                ),
              },
              "block"
            )
          )
          f:insert(2, H.as_struct({ H.as_struct({ "" }, "section") }, "block"))
          f:insert(3, H.as_struct({ H.as_struct({ string.rep("=", 78) }, "section") }, "block"))
          f:insert(H.as_struct({ H.as_struct({ "" }, "section") }, "block"))
        end
      end,
    }),
  }
)
