local M = {}

local config = require("herdr-watch.config")
local state = require("herdr-watch.state")

local group_name = "HerdrWatchNotifications"

local function agent_label(pane_id)
  local agent = state.get().agents_by_pane[pane_id]
  if not agent then
    return "agent"
  end
  return agent.display_agent or agent.agent or "agent"
end

local function on_status_changed(args)
  local data = args.data or {}
  local status = data.status
  local options = config.get().presence.notifications
  if status ~= "idle" and status ~= "done" and status ~= "blocked" then
    return
  end
  if not options[status] then
    return
  end

  local pane_id = data.pane_id or "unknown"
  local label = agent_label(pane_id)
  local level = status == "blocked" and vim.log.levels.WARN or vim.log.levels.INFO
  vim.notify(("Herdr %s (%s) is %s"):format(label, pane_id, status), level, {
    title = "herdr-watch.nvim",
  })
end

local function on_connection_changed(args)
  if not config.get().presence.notifications.disconnected then
    return
  end
  local connected = args.data and args.data.connected
  if connected then
    vim.notify("Herdr reconnected", vim.log.levels.INFO, { title = "herdr-watch.nvim" })
  else
    vim.notify("Herdr disconnected; presence data may be stale", vim.log.levels.WARN, { title = "herdr-watch.nvim" })
  end
end

function M.stop()
  pcall(vim.api.nvim_del_augroup_by_name, group_name)
end

function M.setup()
  M.stop()
  if not config.get().presence.enabled then
    return
  end
  local group = vim.api.nvim_create_augroup(group_name, { clear = true })
  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "HerdrWatchAgentStatusChanged",
    callback = on_status_changed,
  })
  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "HerdrWatchConnected",
    callback = function()
      on_connection_changed({ data = { connected = true } })
    end,
  })
  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "HerdrWatchDisconnected",
    callback = function()
      on_connection_changed({ data = { connected = false } })
    end,
  })
end

return M
