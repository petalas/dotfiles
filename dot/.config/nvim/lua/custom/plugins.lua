local plugins = {
    {
        "neovim/nvim-lspconfig",
        config = function()
            require "plugins.configs.lspconfig"
            require "custom.configs.lspconfig"
        end,
    },
    {
        "nvimdev/guard.nvim",
        config = function()
            require "custom.configs.guard"
        end,
        lazy = false
    },
}

return plugins
