-- https://github.com/wbthomason/packer.nvim

vim.cmd([[
  augroup packer_user_config
    autocmd!
    autocmd BufWritePost plugins.lua source <afile> | PackerCompile
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
	use("williamboman/mason.nvim")	
	use("williamboman/mason-lspconfig.nvim")
	-- LSP --
	use("neovim/nvim-lspconfig")
	-- Visualize lsp progress
	use({
	"j-hui/fidget.nvim",
	config = function()
	  require("fidget").setup()
	end
	})

	-- Completion framework:
	use 'hrsh7th/nvim-cmp' 
	use 'hrsh7th/cmp-nvim-lsp'
	use 'hrsh7th/cmp-nvim-lua'
	use 'hrsh7th/cmp-nvim-lsp-signature-help'
	use 'hrsh7th/cmp-vsnip'                             
	use 'hrsh7th/cmp-path'                              
	use 'hrsh7th/cmp-buffer'                            
	use 'hrsh7th/vim-vsnip'

    -- Language-specific --
	 
    -- Rust
    -- Adds extra functionality over rust analyzer
    use("simrat39/rust-tools.nvim")
    use("qnighy/lalrpop.vim")
   
    -- Other --
    use("nvim-lua/popup.nvim")
    use("nvim-lua/plenary.nvim")
    use {
        "nvim-telescope/telescope.nvim", 
        requires = { {'nvim-lua/plenary.nvim'} }
    }   
    use("preservim/tagbar")
	use {
	  "folke/trouble.nvim",
	  requires = "kyazdani42/nvim-web-devicons",
	  config = function()
		require("trouble").setup {
		  -- your configuration comes here
		  -- or leave it empty to use the default settings
		  -- refer to the configuration section below
		}
	  end
	}
	use {
	  "folke/todo-comments.nvim",
	  requires = "nvim-lua/plenary.nvim",
	  config = function()
		require("todo-comments").setup {
		  -- your configuration comes here
		  -- or leave it empty to use the default settings
		  -- refer to the configuration section below
		}
	  end
	}
    use {
      "windwp/nvim-autopairs",
      config = function() require("nvim-autopairs").setup {} end
    }

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
    }
    use { 'junegunn/fzf', run = ":call fzf#install()" }
    use { 'junegunn/fzf.vim' }
    use { 'ngemily/vim-vp4' }
end)

-- the first run will install packer and our plugins
if packer_bootstrap then
    require("packer").sync()
    return
end

