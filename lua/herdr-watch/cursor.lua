local M = {}

local events = require("herdr-watch.events")
local herdr = require("herdr-watch.herdr")

local uv = vim.uv or vim.loop

local active = false
local generation = 0
local cfg
local dependencies
local poll_timer
local positions = {}

local function close_timer(timer)
  if timer then
    timer:stop()
    if not timer:is_closing() then
      timer:close()
    end
  end
end

local function stop_polling()
  close_timer(poll_timer)
  poll_timer = nil
end

local function extract_positions(snapshot)
  local result = {}
  for _, pane in ipairs(snapshot.panes or {}) do
    local tokens = pane.tokens
    if type(tokens) == "table" and type(tokens.file) == "string" and tokens.file ~= "" then
      result[pane.pane_id] = {
        pane_id = pane.pane_id,
        file = tokens.file,
        line = tonumber(tokens.line) or 0,
        agent = pane.agent,
        agent_status = pane.agent_status,
        cwd = pane.cwd,
      }
    end
  end
  return result
end

local function changed(a, b)
  if not a or not b then
    return true
  end
  return a.file ~= b.file or a.line ~= b.line
end

local function poll_once()
  if not active then
    return
  end
  local expected_generation = generation
  dependencies.session_snapshot(cfg, {}, function(snapshot, err)
    if not active or expected_generation ~= generation then
      return
    end
    if not snapshot then
      return
    end
    local updated = extract_positions(snapshot)
    for pane_id, position in pairs(updated) do
      if changed(positions[pane_id], position) then
        positions[pane_id] = position
        events.emit("HerdrCursorUpdated", position)
      end
    end
    for pane_id in pairs(positions) do
      if not updated[pane_id] then
        positions[pane_id] = nil
        events.emit("HerdrCursorUpdated", { pane_id = pane_id, file = nil, line = nil })
      end
    end
  end)
end

function M.start(options, opts)
  opts = opts or {}
  M.stop()
  cfg = options
  dependencies = {
    session_snapshot = opts.session_snapshot or herdr.session_snapshot,
  }
  active = true
  generation = generation + 1
  positions = {}

  local interval = cfg.cursor_dashboard.poll_interval_ms
  poll_timer = uv.new_timer()
  poll_timer:start(interval, interval, function()
    vim.schedule(poll_once)
  end)
  poll_once()
end

function M.stop()
  active = false
  generation = generation + 1
  stop_polling()
end

function M.running()
  return active
end

function M.get()
  return vim.deepcopy(positions)
end

return M
