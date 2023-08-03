local cmd = ':COQnow --shut-up'
local ok, _ = pcall(vim.api.nvim_command, cmd)
if not ok then
    return
end
