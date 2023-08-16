local plugins = {
	{
		"neovim/nvim-lspconfig",
		config = function()
			require("plugins.configs.lspconfig")
			require("custom.configs.lspconfig")
		end,
	},
	{
		"nvimdev/guard.nvim",
		config = function()
			require("custom.configs.guard")
		end,
		lazy = false,
	},
	{
		"williamboman/mason.nvim",
		config = function()
			require("plugins.configs.mason")
			require("custom.configs.mason")
		end,
	},
	{
		"nvim-treesitter/nvim-treesitter",
		config = function()
			require("plugins.configs.treesitter")
			require("custom.configs.treesitter")
		end,
		lazy = false,
	},
}

return plugins
