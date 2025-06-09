-- Fetch the machine name

---@diagnostic disable-next-line: undefined-field
local machine = vim.loop.os_gethostname()

local colorscheme = "desert"

if machine == "ganymede" then
	--colorscheme = "catppuccin-frappe"
	colorscheme = "rose-pine-moon"
elseif machine == "ramjet" then
	colorscheme = "gruvbox"
elseif machine == "scramjet" then
	colorscheme = "gruvbox-material"
end

return {
	--  { url = "git@gitlab.com:gitlab-org/editor-extensions/gitlab.vim.git", lazy = false },

	{ "ellisonleao/gruvbox.nvim" },
	{ "sainnhe/gruvbox-material" },
	{ "catppuccin/nvim" },
	{ "rose-pine/neovim" },

	{
		"LazyVim/LazyVim",
		opts = {
			colorscheme = colorscheme,
		},
	},

	-- Confiugre neotest, add Python, Rust and Deno
	--  {
	--    "nvim-neotest/neotest",
	--    dependencies = {
	--      "nvim-lua/plenary.nvim",
	--      "antoinemadec/FixCursorHold.nvim",
	--      "nvim-treesitter/nvim-treesitter",
	--      "nvim-neotest/neotest-python",
	--      "nvim-neotest/neotest-plenary",
	--      "rouge8/neotest-rust",
	--      --"MarkEmmons/neotest-deno",
	--    },
	--    opts = {
	--      adapters = {
	--        "neotest-plenary",
	--        "neotest-python",
	--        --"neotest-deno",
	--        "neotest-rust",
	--      },
	--    },
	--  },

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

	-- Config nvim-lint
	{
		"mfussenegger/nvim-lint",
		opts = {
			linters_by_ft = {
				python = { "mypy" },
				sh = { "shellcheck" },
			},
		},
	},

	-- Config telescope
	{
		"nvim-telescope/telescope.nvim",
		opts = {
			pickers = {
				live_grep = {
					additional_args = { "--hidden", "--glob=!.git" },
				},
			},
		},
	},

	-- lsp-config
	{
		"neovim/nvim-lspconfig",
		init_options = {
			userLanguages = {
				eelixir = "html-eex",
				eruby = "erb",
				rust = "html",
			},
		},
		--		opts = function()
		--			---@class PluginLspOpts
		--			local ret = {
		--				servers = {
		--					denols = {
		--						autostart = false,
		--					},
		--				},
		--			}
		--			return ret
		--		end,
	},

	-- uuid-nvim
	{
		"TrevorS/uuid-nvim",
		lazy = true,
		config = function()
			-- optional configuration
			require("uuid-nvim").setup({
				case = "upper",
				insert = "after",
			})
		end,
	},

	-- avante
	-- {
	--   "yetone/avante.nvim",
	--   event = "VeryLazy",
	--   lazy = false,
	--   version = false, -- Set this to "*" to always pull the latest release version, or set it to false to update to the latest code changes.
	--   opts = {
	--     provider = "copilot",
	--     --provider = "ollama",
	--     auto_suggestions_provider = "copilot",
	--     --auto_suggestions_provider = "ollama",
	--     behaviour = {
	--       auto_suggestions = true,
	--     },
	--     vendors = {
	--       ollama = {
	--         __inherited_from = "openai",
	--         api_key_name = "",
	--         endpoint = "http://127.0.0.1:11434/v1",
	--         model = "dsc",
	--       },
	--     },
	--     suggestion = {
	--       debounch = 2000,
	--       throttle = 2000,
	--     },
	--   },
	--   build = "make",
	--   dependencies = {
	--     "stevearc/dressing.nvim",
	--     "nvim-lua/plenary.nvim",
	--     "MunifTanjim/nui.nvim",
	--     --- The below dependencies are optional,
	--     --"echasnovski/mini.pick", -- for file_selector provider mini.pick
	--     --"nvim-telescope/telescope.nvim", -- for file_selector provider telescope
	--     --"hrsh7th/nvim-cmp", -- autocompletion for avante commands and mentions
	--     --"ibhagwan/fzf-lua", -- for file_selector provider fzf
	--     --"nvim-tree/nvim-web-devicons", -- or echasnovski/mini.icons
	--     --"zbirenbaum/copilot.lua", -- for providers='copilot'
	--     --      {
	--     --        -- support for image pasting
	--     --        "HakonHarnes/img-clip.nvim",
	--     --        event = "VeryLazy",
	--     --        opts = {
	--     --          -- recommended settings
	--     --          default = {
	--     --            embed_image_as_base64 = false,
	--     --            prompt_for_file_name = false,
	--     --            drag_and_drop = {
	--     --              insert_mode = true,
	--     --            },
	--     --            -- required for Windows users
	--     --            use_absolute_path = true,
	--     --          },
	--     --        },
	--     --      },
	--     --      {
	--     --        -- Make sure to set this up properly if you have lazy=true
	--     --        "MeanderingProgrammer/render-markdown.nvim",
	--     --        opts = {
	--     --          file_types = { "markdown", "Avante" },
	--     --        },
	--     --        ft = { "markdown", "Avante" },
	--     --      },
	--   },
	-- },
}
