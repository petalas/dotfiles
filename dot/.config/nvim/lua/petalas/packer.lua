local fn = vim.fn
local install_path = fn.stdpath('data') .. '/site/pack/packer/start/packer.nvim'
if fn.empty(fn.glob(install_path)) > 0 then
    packer_bootstrap = fn.system({'git', 'clone', '--depth', '1', 'https://github.com/wbthomason/packer.nvim', install_path})
    vim.api.nvim_command('packadd packer.nvim')
end

return require('packer').startup(function(use)
    -- Packer can manage itself
    use 'wbthomason/packer.nvim'

    -- LSP Zero: https://github.com/VonHeikemen/lsp-zero.nvim
    use {
        'VonHeikemen/lsp-zero.nvim',
        branch = 'v2.x',
        requires = {
          -- LSP Support
          {'neovim/nvim-lspconfig'},                -- Required
          {'williamboman/mason.nvim'},              -- Optional
          {'williamboman/mason-lspconfig.nvim'},    -- Optional
          {'hrsh7th/cmp-buffer'},                   -- Optional
          {'hrsh7th/cmp-path'},                     -- Optional
      
          -- Autocompletion
          {'hrsh7th/nvim-cmp'},                     -- Required
          {'hrsh7th/cmp-nvim-lsp'},                 -- Required

          -- Snippets
          { "rafamadriz/friendly-snippets" },       -- Required
          {'L3MON4D3/LuaSnip'},                     -- Required
        }
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
        requires = {{'nvim-lua/plenary.nvim'}}
    }

    -- Harpoon: https://github.com/ThePrimeagen/harpoon
    use("theprimeagen/harpoon")

    -- CHADTree: https://github.com/ms-jpq/chadtree
    use({
        'ms-jpq/chadtree',
        branch = 'chad',
        -- FIXME: how to avoid errors during first run?
        run = function()
            vim.fn.system({'python3', '-m', 'chadtree', 'deps'})
            vim.api.nvim_command('CHADdeps')
        end,
        requires = {{'ryanoasis/vim-devicons'}}
    })

    --  Color scheme: https://github.com/folke/tokyonight.nvim
    use( "folke/tokyonight.nvim")

    -- Automatically set up your configuration after cloning packer.nvim
    -- Put this at the end after all plugins
    if packer_bootstrap then
        require('packer').sync()
    end

end)

