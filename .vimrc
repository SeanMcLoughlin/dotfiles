"""""""""""""""""""
" Global Settings "
"""""""""""""""""""

" Enable mouse
set mouse=a
if !has('nvim')
	set ttymouse=xterm2  " Required to get mouse to work with tmux
endif

" Make words wrap at linebreaks
set wrap linebreak

" Tabs are 4 spaces
set tabstop=4
set shiftwidth=4
set softtabstop=0 noexpandtab

" smartcase: case sensitive only when specifying caps
set ignorecase
set smartcase

let mapleader=","

"""""""""""
" Plugins "
"""""""""""
" Requires vim-plug to be installed! 
" https://github.com/junegunn/vim-plug
call plug#begin('$HOME/.vim/plugged')
if !empty(glob("$HOME/.dotfiles/.vimrc_plugins"))
	source $HOME/.dotfiles/.vimrc_plugins
endif

" NVIM-specific plugins
if !empty(glob("$HOME/.dotfiles/.nvimrc_plugins")) && has('nvim')
	source $HOME/.dotfiles/.nvimrc_plugins
endif

" Work-specific plugins
if !empty(glob("$HOME/.vimrc_plugins_work"))
	source $HOME/.vimrc_plugins_work
endif

call plug#end()

"""""""""""""""""""
" Plugin Settings "
"""""""""""""""""""
" Colorscheme
colorscheme onedark

" Get lightline to appear
set laststatus=2

" Tagbar
nnoremap <F8> :TagbarToggle<CR>

" NerdTree
nnoremap <F7> :NERDTreeToggle<CR>

" FZF
source $HOME/.vimrc_fzf

" nvim
if has('nvim')
	source $HOME/.dotfiles/.nvimrc
endif

" Work specific settings
if !empty(glob("$HOME/.vimrc_work"))
	source $HOME/.vimrc_work
endif

"""""""""""""""""""""
" Language Specific "
"""""""""""""""""""""
au BufEnter *.py source $HOME/.dotfiles/.vim/python.vim
au BufEnter *.rs source $HOME/.dotfiles/.vim/rust.vim
au BufEnter *.sv,*.vs,*.svh source $HOME/.dotfiles/.vim/systemverilog.vim
