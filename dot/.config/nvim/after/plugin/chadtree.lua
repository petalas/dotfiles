local installed, chadtree = pcall(require, 'chadtree')
if not installed then
    return
end

vim.keymap.set("n", "<leader>v", "<cmd>CHADopen<cr>")