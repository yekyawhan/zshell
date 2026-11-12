return {
  -- Catppuccin Mocha everywhere (matches the terminal/desktop)
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    opts = {
      flavour = "mocha",
      transparent_background = true,
      integrations = {
        cmp = true, gitsigns = true, nvimtree = true, telescope = true,
        notify = false, mini = true, which_key = true, treesitter = true,
        native_lsp = { enabled = true },
      },
    },
  },
  { "LazyVim/LazyVim", opts = { colorscheme = "catppuccin" } },
}
