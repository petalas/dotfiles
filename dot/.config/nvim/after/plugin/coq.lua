local cmd = ':COQnow --shut-up'
local status, _ = pcall(vim.api.nvim_command, cmd)
if not status then
    return
end
