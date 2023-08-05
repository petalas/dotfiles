local installed, lualine = pcall(require, 'lualine')
if not installed then
    return
end

lualine.setup()
