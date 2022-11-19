-- https://github.com/wbthomason/packer.nvim

vim.cmd([[
  augroup packer_user_config
    autocmd!
    autocmd BufWritePost my_plugins.lua source <afile> | PackerCompile
  augroup end
]])

local ensure_packer = function()
  local fn = vim.fn
  local install_path = fn.stdpath("data") .. "/site/pack/packer/start/packer.nvim"
  if fn.empty(fn.glob(install_path)) > 0 then
    fn.system({ "git", "clone", "--depth", "1", "https://github.com/wbthomason/packer.nvim", install_path })
    vim.cmd([[packadd packer.nvim]])
    return true
  end
  return false
end

local packer_bootstrap = ensure_packer()

require("packer").init({
  autoremove = true,
})
require("packer").startup(function(use)
  use("wbthomason/packer.nvim") -- Packer can manage itself

  -- LSP --
  use("neovim/nvim-lspconfig")
  -- Visualize lsp progress
  use({
    "j-hui/fidget.nvim",
    config = function()
      require("fidget").setup()
    end
  })
  -- Autocompletion framework
  use("hrsh7th/nvim-cmp")
  use({
    -- cmp LSP completion
    "hrsh7th/cmp-nvim-lsp",
    -- cmp Snippet completion
    "hrsh7th/cmp-vsnip",
    -- cmp Path completion
    "hrsh7th/cmp-path",
    "hrsh7th/cmp-buffer",
    after = { "hrsh7th/nvim-cmp" },
    requires = { "hrsh7th/nvim-cmp" },
  })
  use('hrsh7th/vim-vsnip')

  -- Language-specific --
  
  -- Rust
  -- Adds extra functionality over rust analyzer
  use("simrat39/rust-tools.nvim")

  -- Other --
  use("nvim-lua/popup.nvim")
  use("nvim-lua/plenary.nvim")
  use("nvim-telescope/telescope.nvim")

  -- Appearance --
  use("navarasu/onedark.nvim")
  use {
    'nvim-lualine/lualine.nvim',
    requires = { 'kyazdani42/nvim-web-devicons', opt = true }
  }
  use {
    'nvim-tree/nvim-tree.lua',
    requires = {
      'nvim-tree/nvim-web-devicons', -- optional, for file icons
    },
    tag = 'nightly' -- optional, updated every week. (see issue #1193)
  }
end)

-- the first run will install packer and our plugins
if packer_bootstrap then
  require("packer").sync()
  return
end

