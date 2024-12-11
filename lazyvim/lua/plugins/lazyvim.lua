-- Fetch the machine name

---@diagnostic disable-next-line: undefined-field
local machine = vim.loop.os_gethostname()

local colorscheme = "desert"

if machine == "ganymede" then
  --colorscheme = "catppuccin-frappe"
  colorscheme = "rose-pine-moon"
elseif machine == "ramjet" then
  colorscheme = "gruvbox"
end

return {
  --  { url = "git@gitlab.com:gitlab-org/editor-extensions/gitlab.vim.git", lazy = false },

  { "ellisonleao/gruvbox.nvim" },
  { "catppuccin/nvim" },
  { "rose-pine/neovim" },

  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = colorscheme,
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
      --"MarkEmmons/neotest-deno",
    },
    opts = {
      adapters = {
        "neotest-plenary",
        "neotest-python",
        --"neotest-deno",
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
    opts = {
      servers = {
        denols = {
          autostart = false,
        },
      },
    },
  },

  -- uuid-nvim
  {
    "TrevorS/uuid-nvim",
    lazy = true,
    config = function()
      -- optional configuration
      require("uuid-nvim").setup({
        case = "upper",
      })
    end,
  },
}
