local fn = vim.fn
local install_path = fn.stdpath('data') .. '/site/pack/packer/start/packer.nvim'
if fn.empty(fn.glob(install_path)) > 0 then
    packer_bootstrap = fn.system({'git', 'clone', '--depth', '1', 'https://github.com/wbthomason/packer.nvim', install_path})
    vim.api.nvim_command('packadd packer.nvim')
end

return require('packer').startup(function(use)
    -- Packer can manage itself
    use 'wbthomason/packer.nvim'

    use {
        'nvim-telescope/telescope.nvim',
        tag = '0.1.0', 
		-- or                            , branch = '0.1.x',
        requires = {{'nvim-lua/plenary.nvim'}}
    }

    use({
        'rose-pine/neovim',
        as = 'rose-pine',
        config = function()
            vim.cmd('colorscheme rose-pine')
        end
    })

    use({
        "nvim-treesitter/nvim-treesitter",
        run = function()
            local ts_update = require('nvim-treesitter.install').update({
                with_sync = true
            })
            ts_update()
        end
    })
    use("nvim-treesitter/playground")
    use("theprimeagen/harpoon")
    use("mbbill/undotree")
    use("nvim-treesitter/nvim-treesitter-context")

    use {
        'VonHeikemen/lsp-zero.nvim',
        branch = 'v1.x',
        requires = { -- LSP Support
        {'neovim/nvim-lspconfig'}, {'williamboman/mason-lspconfig.nvim'}, {'williamboman/mason.nvim'},

        -- Autocompletion
        {'hrsh7th/cmp-buffer'}, {'hrsh7th/cmp-nvim-lsp'}, {'hrsh7th/cmp-nvim-lua'}, {'hrsh7th/cmp-path'},
        {'hrsh7th/nvim-cmp'}, {'saadparwaiz1/cmp_luasnip'}, -- Snippets
        {'L3MON4D3/LuaSnip'}, {'rafamadriz/friendly-snippets'}}
    }

    use('ThePrimeagen/vim-be-good')

    -- Automatically set up your configuration after cloning packer.nvim
    -- Put this at the end after all plugins
    if packer_bootstrap then
        require('packer').sync()
    end

end)

