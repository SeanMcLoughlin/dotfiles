" Enable mouse
set mouse=a

" Numbers
set number

" Make words wrap at linebreaks
set wrap linebreak

" Tabs are 4 spaces
set tabstop=4
set shiftwidth=4
set softtabstop=0 noexpandtab

"""""""""""
" Plugins "
"""""""""""
" Requires vim-plug to be installed! 
" https://github.com/junegunn/vim-plug
call plug#begin('~/.vim/plugged')
" Language Specific Features
Plug 'vim-syntastic/syntastic'
Plug 'rust-lang/rust.vim'
Plug 'vhda/verilog_systemverilog.vim'
Plug 'cespare/vim-toml'
Plug 'rhysd/vim-llvm'

" Git
Plug 'airblade/vim-gitgutter'
Plug 'tpope/vim-fugitive'

" Other
Plug 'junegunn/fzf.vim'
Plug 'terryma/vim-multiple-cursors'
Plug 'preservim/nerdtree'
Plug 'itchyny/lightline.vim'
Plug 'kshenoy/vim-signature'
Plug 'junegunn/goyo.vim'
call plug#end()

"""""""""""""""""""
" Plugin Settings "
"""""""""""""""""""
" Get lightline to appear
set laststatus=2
