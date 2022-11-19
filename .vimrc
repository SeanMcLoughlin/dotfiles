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
set expandtab

" Force backspace to work
set backspace=indent,eol,start

" smartcase: case sensitive only when specifying caps
set ignorecase
set smartcase

" Split files like a sane person
set splitright

" Exit more quickly
inoremap <C-q> <esc>:qa!<cr>
nnoremap <C-q> :qa!<cr>"

" Enable highlight searching, but...
set hlsearch
" Double escape clears search highlighting
nnoremap <silent> <Esc><Esc> <Esc>:nohlsearch<CR><Esc>

let mapleader=","

filetype plugin on
syn on

""""""""""
" Plugins "
"""""""""""
" Requires vim-plug to be installed! 
" https://github.com/junegunn/vim-plug
call plug#begin('$HOME/.vim/plugged')
if !empty(glob("$HOME/.dotfiles/.vimrc_plugins"))
	source $HOME/.dotfiles/.vimrc_plugins
endif

" NVIM-specific plugins
" EDIT: Now I'm using packer.nvim which installs nvim plugins with lua
" if !empty(glob("$HOME/.dotfiles/.nvimrc_plugins")) && has('nvim')
" 	source $HOME/.dotfiles/.nvimrc_plugins
" endif

" Work-specific plugins
if !empty(glob("$HOME/.vimrc_plugins_work"))
	source $HOME/.vimrc_plugins_work
endif

call plug#end()

"""""""""""""""""""
" Plugin Settings "
"""""""""""""""""""

" Tagbar
nnoremap <F8> :TagbarToggle<CR>

" NerdTree
nnoremap <F7> :NERDTreeToggle<CR>

" FZF
source $HOME/.vimrc_fzf

" Powerline
python3 from powerline.vim import setup as powerline_setup
python3 powerline_setup()
python3 del powerline_setup
set laststatus=2

" Yank to clipboard
set clipboard+=unnamedplus
let g:oscyank_term = 'default'
autocmd TextYankPost * if v:event.operator is 'y' && v:event.regname is '' | execute 'OSCYankReg "' | endif

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
au BufEnter *.aliases set syntax=conf
au BufNewFile,BufRead *.md set filetype=markdown
