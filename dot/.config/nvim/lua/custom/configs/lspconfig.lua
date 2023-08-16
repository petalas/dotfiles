local on_attach = require("plugins.configs.lspconfig").on_attach
local cababilities = require("plugins.configs.lspconfig").cababilities

local lspconfig = require "lspconfig"
local util = require 'lspconfig.util'

lspconfig.tsserver.setup({
    on_attach=on_attach,
    cababilities=cababilities,
    filetypes={ "javascript", "javascriptreact", "javascript.jsx", "typescript", "typescriptreact", "typescript.tsx" },
    init_options={
        hostInfo = "neovim"
    },
    root_dir = util.root_pattern("package.json", "tsconfig.json", "jsconfig.json", ".git"),
    single_file_support=true,
})

