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
        -- format with nvimdev/guard.nvim --> fallback is still LSP format
        ["<leader>fm"] = { "<cmd>GuardFmt<CR>" }
    },

    i = {
        ["jk"] = { "<ESC>", "escape insert mode", opts = { nowait = true } },
        ["kj"] = { "<ESC>", "escape insert mode", opts = { nowait = true } },

        -- format with nvimdev/guard.nvim --> fallback is still LSP format
        -- C-o will get out of insert mode just for the next command and go back in
        ["<leader>fm"] = { "<ESC>", "<C-o><cmd>GuardFmt<CR>" },
    }
}

return M
