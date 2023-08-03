local fn = vim.fn
local install_path = fn.stdpath('data') .. '/site/pack/packer/start/packer.nvim'
if fn.empty(fn.glob(install_path)) > 0 then
    packer_bootstrap = fn.system({ 'git', 'clone', '--depth', '1', 'https://github.com/wbthomason/packer.nvim',
        install_path })
    vim.api.nvim_command('packadd packer.nvim')
end

-- Autocommand that reloads neovim whenever you save the plugins.lua file
vim.cmd([[
  augroup packer_user_config
    autocmd!
    autocmd BufWritePost plugins.lua source <afile> | PackerSync
  augroup end
]])

-- Use a protected call so we don't error out on first use
local installed, packer = pcall(require, "packer")
if not installed then
    return
end

-- Have packer use a popup window
packer.init({
    display = {
        open_fn = function()
            return require("packer.util").float({ border = "rounded" })
        end,
    },
})

return packer.startup(function(use)
    -- Packer can manage itself
    use 'wbthomason/packer.nvim'

    -- Completion engine: https://github.com/ms-jpq/coq_nvim
    use { 'ms-jpq/coq_nvim',
        branch = 'coq',
        run = 'python3 -m coq deps'
    }
    use { 'ms-jpq/coq.artifacts', branch = 'artifacts' }

    -- Mason is another manager for LSP, DAP, Linters, Formatters
    -- It's important that you set up the plugins in the following order:
    -- https://github.com/williamboman/mason-lspconfig.nvim#setup
    use {
        "williamboman/mason.nvim",
        "williamboman/mason-lspconfig.nvim",
        "neovim/nvim-lspconfig",
    }

    -- nvim-treesitter: https://github.com/nvim-treesitter/nvim-treesitter
    use({
        "nvim-treesitter/nvim-treesitter",
        run = function()
            local ts_update = require('nvim-treesitter.install').update({
                with_sync = true
            })
            ts_update()
        end
    })

    -- UndoTree: https://github.com/mbbill/undotree
    use("mbbill/undotree")

    -- Telescope: https://github.com/nvim-telescope/telescope.nvim
    use {
        'nvim-telescope/telescope.nvim', branch = '0.1.x',
        requires = { { 'nvim-lua/plenary.nvim' } }
    }

    -- Harpoon: https://github.com/ThePrimeagen/harpoon
    use("theprimeagen/harpoon")

    -- CHADTree: https://github.com/ms-jpq/chadtree
    use({
        'ms-jpq/chadtree',
        branch = 'chad',
        -- FIXME: how to avoid errors during first run?
        run = ":CHADdeps",
        -- run = "python3 -m chadtree deps --nvim",
        requires = { { 'ryanoasis/vim-devicons' } }
    })

    --  Color scheme: https://github.com/folke/tokyonight.nvim
    use("folke/tokyonight.nvim")

    -- Automatically set up your configuration after cloning packer.nvim
    -- Put this at the end after all plugins
    if packer_bootstrap then
        require('packer').sync()
    end
end)