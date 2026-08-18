local M = {}

local config = require("herdr-watch.config")
local cursor = require("herdr-watch.cursor")

local namespace = vim.api.nvim_create_namespace("herdr-watch-dashboard")
local bufnr
local winid
local line_to_pane = {}
local follow_pane_id
local augroup

local function notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO, { title = "herdr-watch.nvim" })
end

local function valid_buffer()
  return bufnr and vim.api.nvim_buf_is_valid(bufnr)
end

local function valid_window()
  return winid and vim.api.nvim_win_is_valid(winid)
end

local function pane_for_cursor()
  if not valid_window() then
    return nil
  end
  return line_to_pane[vim.api.nvim_win_get_cursor(winid)[1]]
end

local function shorten(path)
  if not path or path == "" then
    return "?"
  end
  return vim.fn.fnamemodify(path, ":~:.")
end

function M.render()
  if not valid_buffer() then
    return
  end
  local positions = cursor.get()
  local lines = { " Herdr Cursor Dashboard" }
  line_to_pane = {}

  local pane_ids = vim.tbl_keys(positions)
  table.sort(pane_ids)

  if #pane_ids == 0 then
    lines[#lines + 1] = ""
    lines[#lines + 1] = " No agent activity detected yet"
  else
    lines[#lines + 1] = ""
    for _, pane_id in ipairs(pane_ids) do
      local position = positions[pane_id]
      local follow_marker = follow_pane_id == pane_id and "▶ " or "  "
      local agent = position.agent or "agent"
      local line_suffix = position.line and position.line > 0 and (":" .. position.line) or ""
      lines[#lines + 1] =
        string.format("%s%-10s %-14s %s%s", follow_marker, agent, pane_id, shorten(position.file), line_suffix)
      line_to_pane[#lines] = pane_id
    end
  end

  lines[#lines + 1] = ""
  lines[#lines + 1] = " <CR> jump   f follow/unfollow   r refresh   q close"

  vim.bo[bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
  vim.api.nvim_buf_set_extmark(bufnr, namespace, 0, 1, {
    end_col = #lines[1],
    hl_group = "Title",
  })
  vim.bo[bufnr].modifiable = false
end

local function jump_to(position)
  if not position or not position.file then
    return
  end
  local target_win
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if win ~= winid and vim.api.nvim_win_get_config(win).relative == "" then
      target_win = win
      break
    end
  end
  if target_win then
    vim.api.nvim_set_current_win(target_win)
  else
    vim.cmd("wincmd p")
  end
  local ok = pcall(vim.cmd.edit, vim.fn.fnameescape(position.file))
  if not ok then
    notify("Could not open " .. position.file, vim.log.levels.ERROR)
    return
  end
  if position.line and position.line > 0 then
    local last_line = vim.api.nvim_buf_line_count(0)
    pcall(vim.api.nvim_win_set_cursor, 0, { math.min(position.line, last_line), 0 })
  end
end

function M.jump()
  local pane_id = pane_for_cursor()
  if not pane_id then
    return
  end
  jump_to(cursor.get()[pane_id])
end

function M.toggle_follow()
  local pane_id = pane_for_cursor()
  if not pane_id then
    return
  end
  if follow_pane_id == pane_id then
    follow_pane_id = nil
    notify("Stopped following " .. pane_id)
  else
    follow_pane_id = pane_id
    notify("Following " .. pane_id)
    jump_to(cursor.get()[pane_id])
  end
  M.render()
end

function M.refresh()
  M.render()
end

local function cleanup()
  cursor.stop()
  if augroup then
    pcall(vim.api.nvim_del_augroup_by_id, augroup)
    augroup = nil
  end
  bufnr = nil
  winid = nil
  line_to_pane = {}
  follow_pane_id = nil
end

function M.close()
  if valid_window() then
    vim.api.nvim_win_close(winid, true)
  elseif valid_buffer() then
    vim.api.nvim_buf_delete(bufnr, { force = true })
  else
    cleanup()
  end
end

function M.open()
  if valid_window() then
    vim.api.nvim_set_current_win(winid)
    return bufnr
  end

  vim.cmd("botright vsplit")
  winid = vim.api.nvim_get_current_win()
  bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(winid, bufnr)
  vim.wo[winid].winfixwidth = true
  vim.wo[winid].number = false
  vim.wo[winid].relativenumber = false
  vim.wo[winid].signcolumn = "no"
  vim.wo[winid].foldcolumn = "0"
  vim.wo[winid].wrap = false
  vim.bo[bufnr].buftype = "nofile"
  vim.bo[bufnr].bufhidden = "wipe"
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].filetype = "herdr-watch-dashboard"
  vim.bo[bufnr].modifiable = false

  local function map(lhs, callback, description)
    vim.keymap.set("n", lhs, callback, { buffer = bufnr, silent = true, desc = description })
  end
  map("q", M.close, "Close Herdr cursor dashboard")
  map("<Esc>", M.close, "Close Herdr cursor dashboard")
  map("r", M.refresh, "Refresh Herdr cursor dashboard")
  map("<CR>", M.jump, "Jump to Herdr agent cursor")
  map("f", M.toggle_follow, "Toggle follow Herdr agent cursor")

  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = bufnr,
    once = true,
    callback = cleanup,
  })

  augroup = vim.api.nvim_create_augroup("HerdrWatchDashboard", { clear = true })
  vim.api.nvim_create_autocmd("User", {
    group = augroup,
    pattern = "HerdrCursorUpdated",
    callback = function(args)
      local data = args.data or {}
      if follow_pane_id and data.pane_id == follow_pane_id and data.file then
        jump_to(data)
      end
      vim.schedule(function()
        if valid_buffer() then
          M.render()
        end
      end)
    end,
  })

  cursor.start(config.get())
  M.render()
  return bufnr
end

function M.toggle()
  if valid_window() then
    M.close()
  else
    M.open()
  end
end

return M
