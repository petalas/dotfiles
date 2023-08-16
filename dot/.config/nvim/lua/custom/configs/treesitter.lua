local installed, treesitter = pcall(require, "nvim-treesitter")
if not installed then
	vim.notify("treesitter not installed")
	return
end

treesitter.setup({
	auto_install = true,
})
