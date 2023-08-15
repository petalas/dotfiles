local cmd = ":COQnow --shut-up"
local ok, _ = pcall(vim.api.nvim_command, cmd)
if not ok then
	return
end

local ok2, coq = pcall(require, "coq")
if not ok2 then
	return
end

-- FIXME
vim.g.coq_settings = {
	["keymap.jump_to_mark"] = "",
}
