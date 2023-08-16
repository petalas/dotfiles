local M = {}

-- In order to disable a default keymap, use
-- M.disabled = {
--   n = {
--       ["<leader>h"] = "",
--       ["<C-a>"] = ""
--   }
-- }

-- Your custom mappings
M.custom = {
    n = {
        ["<C-d>"] = { "<C-d>zz", "down half a page" },
        ["<C-u>"] = { "<C-u>zz", "up half a page" },

        -- format with nvimdev/guard.nvim --> fallback is still LSP format
        ["<leader>fm"] = { "<cmd>GuardFmt<CR>", "Format with GuardFmt" }
    },

    i = {
        ["jk"] = { "<ESC>", "escape insert mode", opts = { nowait = true } },
        ["kj"] = { "<ESC>", "escape insert mode", opts = { nowait = true } },

        -- format with nvimdev/guard.nvim --> fallback is still LSP format
        -- C-o will get out of insert mode just for the next command and go back in
        ["<leader>fm"] = { "<C-o><cmd>GuardFmt<CR>", "Format with GuardFmt" },
    }
}

return M
