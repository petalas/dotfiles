local status_ok, toggleterm = pcall(require, "toggleterm")
if not status_ok then
	return
end

toggleterm.setup({
	-- size can be a number or function which is passed the current terminal
	size = 20,
	open_mapping = [[<c-\>]],
	direction = "float",
	float_opts = {
		border = "curved",
		winblend = 3,
	},
})
