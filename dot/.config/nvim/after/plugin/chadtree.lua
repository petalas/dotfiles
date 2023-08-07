local installed, chadtree = pcall(require, "chadtree")
if not installed then
	return
end

local chadtree_settings = {
	["options.close_on_open"] = false, -- stay open when opening a file
}
vim.api.nvim_set_var("chadtree_settings", chadtree_settings)

-- keybind to toggle
vim.keymap.set("n", "<leader>v", "<cmd>CHADopen<cr>")

-- open automatically
vim.cmd("CHADopen")
