local colorscheme = 'tokyonight'
local installed, _ = pcall(vim.cmd, 'colorscheme ' .. colorscheme)
if not installed then
    vim.notify("colorscheme " .. colorscheme .. " not found.")
    return
end