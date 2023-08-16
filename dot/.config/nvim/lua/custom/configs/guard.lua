local installed, guard = pcall(require, "guard")
if not installed then
    vim.notify("guard not installed")
	return
end

local installed2, ft = pcall(require, "guard.filetype")
if not installed2 then
    vim.notify("guard.filetype not installed")
	return
end

ft("lua"):fmt("lsp"):append("stylua")
ft("rust"):fmt("lsp"):append("rust-analyzer")
ft("javascript,javascriptreact,javascript.jsx,typescript,typescriptreact,typescript.tsx"):fmt("lsp"):append("prettier")

guard.setup({
	-- the only options for the setup function
	fmt_on_save = false,
	-- Use lsp if no formatter was defined for this filetype
	lsp_as_default_formatter = true,
})
