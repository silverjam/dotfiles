--local function debugrun()
-- vim.lsp.codelens.refresh()
-- vim.lsp.codelens.run()
--end
--
--vim.keymap.set("n", "<space>dr", debugrun, { desc = "debug run" })

---- unbind the really annoying move line bindings
vim.keymap.del({ "n", "i", "v" }, "<A-j>")
vim.keymap.del({ "n", "i", "v" }, "<A-k>")
