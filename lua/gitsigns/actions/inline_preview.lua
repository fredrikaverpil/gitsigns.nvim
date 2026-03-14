local cache = require('gitsigns.cache').cache
local config = require('gitsigns.config').config

local api = vim.api

--- @class gitsigns.actions.inline_preview
local M = {}

local ns = api.nvim_create_namespace('gitsigns_inline_preview')

local VIRT_LINE_LEN = 300

--- @param bufnr integer
function M.clear(bufnr)
  api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
end

--- @param bufnr integer
--- @return boolean
function M.is_enabled(bufnr)
  local bcache = cache[bufnr]
  if bcache and bcache.inline_preview ~= nil then
    return bcache.inline_preview
  end
  return config.inline_preview
end

--- Apply added-line highlights for a hunk.
--- @param bufnr integer
--- @param hunk Gitsigns.Hunk.Hunk
local function show_added(bufnr, hunk)
  local start_row = hunk.added.start - 1
  local line_hl = hunk.type == 'add' and 'GitSignsAddLn' or 'GitSignsAddPreview'

  for offset = 0, hunk.added.count - 1 do
    local row = start_row + offset
    api.nvim_buf_set_extmark(bufnr, ns, row, 0, {
      end_row = row + 1,
      hl_group = line_hl,
      hl_eol = true,
      priority = 1000,
    })
  end

  local _, added_regions =
    require('gitsigns.diff_int').run_word_diff(hunk.removed.lines, hunk.added.lines)

  for _, region in ipairs(added_regions) do
    local offset, rtype, scol, ecol = region[1] - 1, region[2], region[3] - 1, region[4] - 1

    local cr_at_eol_change = rtype == 'change'
      and vim.endswith(assert(hunk.added.lines[offset + 1]), '\r')

    api.nvim_buf_set_extmark(bufnr, ns, start_row + offset, scol, {
      end_col = ecol,
      strict = not cr_at_eol_change,
      hl_group = rtype == 'add' and 'GitSignsAddInline'
        or rtype == 'change' and 'GitSignsChangeInline'
        or 'GitSignsDeleteInline',
      priority = 1001,
    })
  end
end

--- Show deleted lines as virtual lines for a hunk.
--- @param bufnr integer
--- @param hunk Gitsigns.Hunk.Hunk
local function show_deleted(bufnr, hunk)
  local virt_lines = {} --- @type [string, string][][]

  for i, line in ipairs(hunk.removed.lines) do
    local vline = {} --- @type [string, string][]
    local last_ecol = 1

    local regions = require('gitsigns.diff_int').run_word_diff(
      { hunk.removed.lines[i] },
      { hunk.added.lines[i] }
    )

    for _, region in ipairs(regions) do
      local rline, scol, ecol = region[1], region[3], region[4]
      if rline > 1 then
        break
      end
      vline[#vline + 1] = { line:sub(last_ecol, scol - 1), 'GitSignsDeleteVirtLn' }
      vline[#vline + 1] = { line:sub(scol, ecol - 1), 'GitSignsDeleteVirtLnInline' }
      last_ecol = ecol
    end

    if #line > 0 then
      vline[#vline + 1] = { line:sub(last_ecol, -1), 'GitSignsDeleteVirtLn' }
    end

    local padding = string.rep(' ', VIRT_LINE_LEN - #line)
    vline[#vline + 1] = { padding, 'GitSignsDeleteVirtLn' }

    virt_lines[i] = vline
  end

  local topdelete = hunk.added.start == 0 and hunk.type == 'delete'

  local row = topdelete and 0 or hunk.added.start - 1
  api.nvim_buf_set_extmark(bufnr, ns, row, -1, {
    virt_lines = virt_lines,
    virt_lines_above = hunk.type ~= 'delete' or topdelete,
  })
end

--- Apply inline preview for all hunks in a buffer.
--- @param bufnr integer
--- @param hunks? Gitsigns.Hunk.Hunk[]
function M.apply(bufnr, hunks)
  M.clear(bufnr)
  if not M.is_enabled(bufnr) then
    return
  end
  for _, hunk in ipairs(hunks or {}) do
    if hunk.added.count > 0 then
      show_added(bufnr, hunk)
    end
    if hunk.removed.count > 0 then
      show_deleted(bufnr, hunk)
    end
  end
end

return M
