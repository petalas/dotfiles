
local installed, mason = pcall(require, "mason")
if not installed then
    vim.notify("mason not installed")
	return
end

mason.setup({
    ensure_installed = {"stylua"}
})
