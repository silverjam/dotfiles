return {
	{ "ellisonleao/gruvbox.nvim" },
	-- { "nxstynate/rosePine.nvim" },

	{
		"LazyVim/LazyVim",
		opts = {
			colorscheme = "gruvbox",
			-- colorscheme = "rosePine",
		},
	},

	-- Confiugre neotest, add Python, Rust and Deno
	{
		"nvim-neotest/neotest",
		dependencies = {
			"nvim-lua/plenary.nvim",
			"antoinemadec/FixCursorHold.nvim",
			"nvim-treesitter/nvim-treesitter",
			"nvim-neotest/neotest-python",
			"nvim-neotest/neotest-plenary",
			"rouge8/neotest-rust",
			"MarkEmmons/neotest-deno",
		},
		opts = {
			adapters = {
				"neotest-plenary",
				"neotest-python",
				"neotest-deno",
				"neotest-rust",
			},
		},
	},

	-- Configure neo-tree, add line numbers
	{
		"nvim-neo-tree/neo-tree.nvim",
		opts = {
			event_handlers = {
				{
					event = "neo_tree_buffer_enter",
					handler = function(_)
						vim.opt.relativenumber = true
						vim.opt.number = true
					end,
				},
			},
		},
	},
}
