local installed, plugin = pcall(require, 'rose-pine')
if not installed then
    goto exit
end

plugin.setup({
    disable_background = true
})

function ColorMyPencils(color) 
	color = color or "rose-pine"
	vim.cmd.colorscheme(color)

	vim.api.nvim_set_hl(0, "Normal", { bg = "none" })
	vim.api.nvim_set_hl(0, "NormalFloat", { bg = "none" })

end

ColorMyPencils()

::exit::