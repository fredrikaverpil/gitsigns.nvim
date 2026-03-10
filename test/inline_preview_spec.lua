local helpers = require('test.gs_helpers')

local setup_gitsigns = helpers.setup_gitsigns
local test_file = helpers.test_file
local edit = helpers.edit
local exec_lua = helpers.exec_lua
local test_config = helpers.test_config
local clear = helpers.clear
local setup_test_repo = helpers.setup_test_repo
local eq = helpers.eq
local expectf = helpers.expectf
local cleanup = helpers.cleanup

helpers.env()

describe('inline preview', function()
  before_each(function()
    clear()
  end)

  after_each(function()
    cleanup()
  end)

  it('toggle_inline_preview shows extmarks for all hunks', function()
    setup_test_repo({
      test_file_text = {
        'aaa',
        'bbb',
        'ccc',
        'ddd',
        'eee',
      },
    })
    setup_gitsigns(test_config)
    edit(test_file)

    -- Create two hunks: modify line 1, delete line 4
    helpers.api.nvim_buf_set_lines(0, 0, 1, false, { 'AAA' })
    helpers.api.nvim_buf_set_lines(0, 3, 4, false, {})

    expectf(function()
      local hunks = exec_lua("return require('gitsigns').get_hunks()")
      eq(2, #hunks)
    end)

    -- Toggle on
    local enabled = exec_lua(function()
      return require('gitsigns').toggle_inline_preview()
    end)
    eq(true, enabled)

    local marks = exec_lua(function()
      local ns = vim.api.nvim_get_namespaces().gitsigns_inline_preview
      return vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, { details = true })
    end)

    assert(#marks > 0, 'expected extmarks to be placed')
  end)

  it('toggle_inline_preview clears extmarks when toggled off', function()
    setup_test_repo({
      test_file_text = {
        'aaa',
        'bbb',
      },
    })
    setup_gitsigns(test_config)
    edit(test_file)

    helpers.api.nvim_buf_set_lines(0, 0, 1, false, { 'AAA' })

    expectf(function()
      local hunks = exec_lua("return require('gitsigns').get_hunks()")
      eq(1, #hunks)
    end)

    -- Toggle on then off
    exec_lua(function()
      require('gitsigns').toggle_inline_preview()
    end)

    local disabled = exec_lua(function()
      return not require('gitsigns').toggle_inline_preview()
    end)
    eq(true, disabled)

    local marks = exec_lua(function()
      local ns = vim.api.nvim_get_namespaces().gitsigns_inline_preview
      return vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, { details = true })
    end)

    eq(0, #marks)
  end)

  it('global toggle applies to all buffers', function()
    setup_test_repo({
      test_file_text = { 'aaa' },
    })
    setup_gitsigns(test_config)
    edit(test_file)

    helpers.api.nvim_buf_set_lines(0, 0, 1, false, { 'AAA' })

    expectf(function()
      local hunks = exec_lua("return require('gitsigns').get_hunks()")
      eq(1, #hunks)
    end)

    local enabled = exec_lua(function()
      return require('gitsigns').toggle_inline_preview(nil, true)
    end)
    eq(true, enabled)

    local config_val = exec_lua(function()
      return require('gitsigns.config').config.inline_preview
    end)
    eq(true, config_val)
  end)
end)
