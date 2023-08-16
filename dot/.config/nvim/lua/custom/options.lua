
local options = {
	backup = false, -- creates a backup file
	writebackup = false, -- if a file is being edited by another program (or was written to file while editing with another program), it is not allowed to be edited
	swapfile = false, -- creates a swapfile
	undofile = true, -- enable persistent undo

	expandtab = true, -- convert tabs to spaces
	showtabline = 2, -- always show tabs
	tabstop = 4, -- insert 4 spaces for a tab
	shiftwidth = 4, -- the number of spaces inserted for each indentation
	smartindent = true, -- smart autoindenting when starting a new line

	cursorline = true, -- highlight the current line
	cursorcolumn = true, -- highlight the screen column of the cursor

	hlsearch = false, -- highlight all matches on previous search pattern
	incsearch = true, -- incremental search
	ignorecase = true, -- ignore case in search patterns

	number = true, -- set numbered lines
	numberwidth = 4, -- set number column width to 2 {default 4}
	relativenumber = true, -- set relative numbered lines

	termguicolors = true, -- set term gui colors (most terminals support this)

	clipboard = "unnamedplus", -- allows neovim to access the system clipboard
	cmdheight = 2, -- more space in the neovim command line for displaying messages
	colorcolumn = "80", -- vertical line 80 chars
	conceallevel = 0, -- so that `` is visible in markdown files
	fileencoding = "utf-8", -- the encoding written to a file

	wrap = false, -- display lines as one long line

	mouse = "a", -- allow the mouse to be used in neovim
	pumheight = 10, -- pop up menu height
	scrolloff = 8, -- minimal number of screen lines to keep above and below the cursor
	showmode = true, -- show which mode we are in
	sidescrolloff = 8, -- minimal number of screen columns either side of cursor if wrap is `false`
	signcolumn = "yes", -- always show the sign column, otherwise it would shift the text each time
	timeoutlen = 300, -- time to wait for a mapped sequence to complete (in milliseconds)
	updatetime = 50, -- faster completion (4000ms default)
}

for k, v in pairs(options) do
	vim.opt[k] = v
end

-- TODO: revisit
vim.opt.undodir = os.getenv("HOME") .. "/.vim/undodir"
vim.opt.isfname:append("@-@")

-- vim.opt.list = true
-- vim.opt.listchars:append("space:⋅")
-- vim.opt.listchars:append("eol:↴")
