-- Use a protected call so we don't error out on first use
local installed, configs = pcall(require, "nvim-treesitter.configs")
if not installed then
	return
end

configs.setup({
	-- A list of parser names, or "all" (the five listed parsers should always be installed)
	ensure_installed = { "comment", "markdown_inline" },

	-- Install parsers synchronously (only applied to `ensure_installed`)
	sync_install = false,

	-- Automatically install missing parsers when entering buffer
	-- Recommendation: set to false if you don't have `tree-sitter` CLI installed locally
	auto_install = true,

	-- List of parsers to ignore installing (for "all")
	ignore_install = { "" },

	-- If you need to change the installation directory of the parsers (see -> Advanced Setup)
	-- parser_install_dir = "/some/path/to/store/parsers", -- Remember to run vim.opt.runtimepath:append("/some/path/to/store/parsers")!

	highlight = {
		enable = true,
		disable = { "" },
		additional_vim_regex_highlighting = false,
	},

	context_commentstring = {
		enable = true,
	},
})
