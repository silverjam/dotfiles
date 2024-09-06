--local function debugrun()
-- vim.lsp.codelens.refresh()
-- vim.lsp.codelens.run()
--end
--
--vim.keymap.set("n", "<space>dr", debugrun, { desc = "debug run" })

---- Unbind the really annoying move line bindings
vim.keymap.del({ "n", "i", "v" }, "<A-j>")
vim.keymap.del({ "n", "i", "v" }, "<A-k>")

---- Bind  <Space><Space> to search files in git
---    (Default is to search "root dir" which can change in a mixed language project)
vim.keymap.del("n", "<Space><Space>")
vim.keymap.set(
  "n",
  "<Space><Space>",
  ":Telescope git_files<CR>",
  { remap = false, silent = true, desc = "Find in git (*s)" }
)
