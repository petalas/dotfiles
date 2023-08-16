
local opts = { noremap = true, silent = true }

-- Shorten function name
local keymap = vim.keymap.set

-- keep cursor in the center when going up and down half page
keymap("n", "<C-d>", "<C-d>zz")
keymap("n", "<C-u>", "<C-u>zz")

-- allow search terms to stay in the middle when going to next or previous
keymap("n", "n", "nzzzv")
keymap("n", "N", "Nzzzv")

-- paste into void register to not overwrite clipboard with selection that got pasted over
keymap("x", "<leader>p", '"_dP')

-- delete into void register to maintain clipboard
keymap("n", "<leader>d", '"_d')
keymap("v", "<leader>d", '"_d')

-- Resize with arrows
keymap("n", "<C-Up>", ":resize -2<CR>", opts)
keymap("n", "<C-Down>", ":resize +2<CR>", opts)
keymap("n", "<C-Left>", ":vertical resize +2<CR>", opts)
keymap("n", "<C-Right>", ":vertical resize -2<CR>", opts)

-- Move text up and down
keymap("n", "<A-j>", ":m .+1<CR>==", opts)
keymap("n", "<A-k>", ":m .-2<CR>==", opts)

-- never go into ex mode
keymap("n", "Q", "<nop>")

-- Insert Mode --
-- <C-o> switches to normal mode only for the next command
-- Press jk fast to exit insert mode
keymap("i", "jk", "<ESC>", opts)
keymap("i", "kj", "<ESC>", opts)

-- Visual Mode --
-- Stay in indent mode
keymap("v", "<", "<gv^", opts)
keymap("v", ">", ">gv^", opts)

-- Move text up and down
keymap("v", "<A-j>", ":m '>+1<CR>gv=gv", opts)
keymap("v", "<A-k>", ":m '<-2<CR>gv=gv", opts)
keymap("v", "p", '"_dP', opts)

-- Visual Block Mode --
-- Move text up and down
keymap("x", "J", ":m '>+1<CR>gv=gv", opts)
keymap("x", "K", ":m '<-2<CR>gv=gv", opts)
keymap("x", "<A-j>", ":m '>+1<CR>gv=gv", opts)
keymap("x", "<A-k>", ":m '<-2<CR>gv=gv", opts)

