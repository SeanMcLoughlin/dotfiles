"""""""""""""""""""
" Global Settings "
"""""""""""""""""""

let mapleader="," " Set a leader command for other key bindings
set mouse=a " Enable mouse
set wrap linebreak " Make words wrap at linebreaks
set backspace=indent,eol,start " Force backspace to work
set ignorecase " Search case insensitively
set smartcase " Case sensitive only when specifying caps
set splitright " Split files like a sane person
filetype plugin on 
syn on " Enable syntax highlighting

" Tabs are 4 spaces
set tabstop=4
set shiftwidth=4
set expandtab

" Exit more quickly
inoremap <C-q> <esc>:qa!<cr>
nnoremap <C-q> :qa!<cr>"

" Enable highlight searching, but...
set hlsearch
" Double escape clears search highlighting
nnoremap <silent> <Esc><Esc> <Esc>:nohlsearch<CR><Esc>


""""""""""
" Plugins "
"""""""""""
" Requires vim-plug to be installed! See: https://github.com/junegunn/vim-plug
call plug#begin('$HOME/.vim/plugged')
if !empty(glob("$HOME/.dotfiles/.vimrc_plugins"))
	source $HOME/.dotfiles/.vimrc_plugins
endif

" Work-specific plugins (not synced with .dotfiles)
if !empty(glob("$HOME/.vimrc_plugins_work"))
	source $HOME/.vimrc_plugins_work
endif

call plug#end()

"""""""""""""""""""
" Plugin Settings "
"""""""""""""""""""

" Tagbar
nnoremap <F8> :TagbarToggle<CR>

" Yank to clipboard
set clipboard+=unnamedplus
let g:oscyank_term = 'default'
autocmd TextYankPost * if v:event.operator is 'y' && v:event.regname is '' | execute 'OSCYankReg "' | endif

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
