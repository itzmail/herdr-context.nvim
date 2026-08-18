if vim.g.loaded_herdr_watch then
  return
end
vim.g.loaded_herdr_watch = true

local function command_opts(args)
  if args.range and args.range > 0 then
    return { line1 = args.line1, line2 = args.line2 }
  end
end

vim.api.nvim_create_user_command("HerdrWatchReference", function(args)
  require("herdr-watch").reference(command_opts(args))
end, { desc = "Stage a code reference in a Herdr agent prompt", range = true })

vim.api.nvim_create_user_command("HerdrWatchSend", function(args)
  require("herdr-watch").send(command_opts(args))
end, { desc = "Stage a code reference and selected content in a Herdr agent prompt", range = true })

vim.api.nvim_create_user_command("HerdrWatchDiagnostics", function(args)
  require("herdr-watch").diagnostics(command_opts(args))
end, { desc = "Stage diagnostics for a line or range in a Herdr agent prompt", range = true })

vim.api.nvim_create_user_command("HerdrWatchCompose", function(args)
  local opts = command_opts(args) or {}
  opts.preset = args.args ~= "" and args.args or nil
  require("herdr-watch").compose(opts)
end, {
  desc = "Compose and preview context for a Herdr agent",
  range = true,
  nargs = "?",
  complete = function()
    local names = vim.tbl_keys(require("herdr-watch.config").get().composer.presets)
    table.sort(names)
    return names
  end,
})

vim.api.nvim_create_user_command("HerdrWatchPrompt", function(args)
  require("herdr-watch").prompt(command_opts(args))
end, {
  desc = "Write a message with the current code context and send it to a Herdr agent",
  range = true,
})

vim.api.nvim_create_user_command("HerdrWatchDelegate", function(args)
  local values = vim.split(args.args, "%s+", { trimempty = true })
  if #values > 2 then
    error("HerdrWatchDelegate accepts an agent kind and optional composer preset")
  end
  require("herdr-watch").delegate({
    kind = values[1],
    preset = values[2],
    line1 = args.range > 0 and args.line1 or nil,
    line2 = args.range > 0 and args.line2 or nil,
  })
end, {
  desc = "Create a new Herdr agent and delegate the current context",
  range = true,
  nargs = "+",
})

vim.api.nvim_create_user_command("HerdrWatchSymbol", function()
  require("herdr-watch").symbol()
end, { desc = "Stage the current symbol in a Herdr agent prompt" })

vim.api.nvim_create_user_command("HerdrWatchHunk", function()
  require("herdr-watch").hunk()
end, { desc = "Stage the Git hunk under the cursor in a Herdr agent prompt" })

vim.api.nvim_create_user_command("HerdrWatchQuickfix", function()
  require("herdr-watch").quickfix()
end, { desc = "Stage the current quickfix list in a Herdr agent prompt" })

vim.api.nvim_create_user_command("HerdrWatchLocationList", function()
  require("herdr-watch").location_list()
end, { desc = "Stage the current location list in a Herdr agent prompt" })

vim.api.nvim_create_user_command("HerdrWatchTarget", function()
  require("herdr-watch").select_target()
end, { desc = "Select the destination Herdr agent" })

vim.api.nvim_create_user_command("HerdrWatchAgents", function()
  require("herdr-watch").agents()
end, { desc = "Toggle the live Herdr agent drawer" })

vim.api.nvim_create_user_command("HerdrWatchExplainAgent", function()
  require("herdr-watch").explain_agent()
end, { desc = "Explain Herdr agent detection and status" })

vim.api.nvim_create_user_command("HerdrWatchHistory", function()
  require("herdr-watch").history()
end, { desc = "Toggle staged Herdr context history" })

vim.api.nvim_create_user_command("HerdrWatchRefresh", function()
  require("herdr-watch").refresh()
end, { desc = "Force a refresh of live Herdr state" })
