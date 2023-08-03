
-- From: https://github.com/williamboman/mason-lspconfig.nvim#setup
-- It's important that you set up the plugins in the following order:
--   mason.nvim
--   mason-lspconfig.nvim
--   Setup servers via lspconfig

require("petalas.lsp.mason")
require("petalas.lsp.handlers").setup()
