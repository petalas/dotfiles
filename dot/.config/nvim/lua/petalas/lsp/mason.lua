-- From: https://github.com/williamboman/mason-lspconfig.nvim#setup
-- It's important that you set up the plugins in the following order:
--   mason.nvim
--   mason-lspconfig.nvim
--   Setup servers via lspconfig

local ok, mason = pcall(require, 'mason')
if not ok then
    vim.notify('Failed to load mason')
    return
end

local ok2, mason_lspconfig = pcall(require, 'mason-lspconfig')
if not ok2 then
    vim.notify('Failed to load mason-lspconfig')
    return
end

local ok3, lspconfig = pcall(require, 'lspconfig')
if not ok3 then
    vim.notify('Failed to load lspconfig')
    return
end

local servers = {
	"lua_ls",
	-- "cssls",
	-- "html",
    "tsserver",
	-- "pyright",
	-- "bashls",
	"jsonls",
	-- "yamlls",
}

mason.setup()
mason_lspconfig.setup({
    ensure_installed = servers,
    automatic_installation = true,
})

-- After setting up mason-lspconfig you may set up servers via lspconfig

local opts = {}

for _, server in pairs(servers) do
	opts = {
		on_attach = require("petalas.lsp.handlers").on_attach,
		capabilities = require("petalas.lsp.handlers").capabilities,
	}

	server = vim.split(server, "@")[1]

	local require_ok, conf_opts = pcall(require, "petalas.lsp.settings." .. server)
	if require_ok then
		opts = vim.tbl_deep_extend("force", conf_opts, opts)
	end

	lspconfig[server].setup(opts)
end
