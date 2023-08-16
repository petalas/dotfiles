local installed, guard = pcall(require, "guard")
if not installed then
	return
end

local installed2, ft = pcall(require, "guard.filetype")
if not installed2 then
	return
end

ft("lua"):fmt("stylua")
ft("rust"):fmt("rust-analyzer")
ft("javascript,typescript,javascriptreact,typescriptreact"):fmt("lsp"):append("prettier")

guard.setup({
	-- the only options for the setup function
	fmt_on_save = false,
	-- Use lsp if no formatter was defined for this filetype
	lsp_as_default_formatter = true,
})
