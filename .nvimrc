version 6.0
let s:cpo_save=&cpo
set cpo&vim
inoremap <silent> <expr> <C-K> (pumvisible() && complete_info(['mode']).mode ==# 'eval') ? Preview_preview() : ''
inoremap <silent> <C-H> <Cmd>lua COQ.Nav_mark()
inoremap <silent> <expr> <C-Space> pumvisible() ? '' : ''
inoremap <silent> <expr> <C-C> pumvisible() ? '' : ''
inoremap <silent> <expr> <BS> pumvisible() ? '<BS>' : '<BS>'
inoremap <silent> <expr> <S-Tab> pumvisible() ? '' : '<BS>'
cnoremap <silent> <Plug>(TelescopeFuzzyCommandSearch) e "lua require('telescope.builtin').command_history { default_text = [=[" . escape(getcmdline(), '"') . "]=] }"
inoremap <silent> <expr> <C-W> pumvisible() ? '' : ''
inoremap <silent> <expr> <C-U> pumvisible() ? '' : ''
vnoremap <silent>  <Cmd>lua COQ.Nav_mark()
nnoremap <silent>  <Cmd>lua COQ.Nav_mark()
nnoremap <silent> <NL> j
nnoremap <silent>  k
nnoremap <silent>  l
nnoremap  v <Cmd>CHADopen
noremap <silent>   <Nop>
omap <silent> % <Plug>(MatchitOperationForward)
xmap <silent> % <Plug>(MatchitVisualForward)
nmap <silent> % <Plug>(MatchitNormalForward)
nnoremap & :&&
vnoremap <silent> < <gv^
vnoremap <silent> > >gv^
nnoremap <silent> H :bprevious
xnoremap <silent> J :m '>+1gv=gv
xnoremap <silent> K :m '<-2gv=gv
nnoremap <silent> L :bnext
nnoremap Y y$
omap <silent> [% <Plug>(MatchitOperationMultiBackward)
xmap <silent> [% <Plug>(MatchitVisualMultiBackward)
nmap <silent> [% <Plug>(MatchitNormalMultiBackward)
omap <silent> ]% <Plug>(MatchitOperationMultiForward)
xmap <silent> ]% <Plug>(MatchitVisualMultiForward)
nmap <silent> ]% <Plug>(MatchitNormalMultiForward)
xmap a% <Plug>(MatchitVisualTextObject)
xnoremap gb <Plug>(comment_toggle_blockwise_visual)
xnoremap gc <Plug>(comment_toggle_linewise_visual)
nnoremap gb <Plug>(comment_toggle_blockwise)
nnoremap gc <Plug>(comment_toggle_linewise)
omap <silent> g% <Plug>(MatchitOperationBackward)
xmap <silent> g% <Plug>(MatchitVisualBackward)
nmap <silent> g% <Plug>(MatchitNormalBackward)
vnoremap <silent> p "_dP
vnoremap <silent> <C-H> <Cmd>lua COQ.Nav_mark()
nnoremap <silent> <C-Space> i
vnoremap <silent> <C-Space> i
nnoremap <Plug>PlenaryTestFile :lua require('plenary.test_harness').test_directory(vim.fn.expand("%:p"))
xnoremap <Plug>(comment_toggle_blockwise_visual) <Cmd>lua require("Comment.api").locked("toggle.blockwise")(vim.fn.visualmode())
xnoremap <Plug>(comment_toggle_linewise_visual) <Cmd>lua require("Comment.api").locked("toggle.linewise")(vim.fn.visualmode())
xmap <silent> <Plug>(MatchitVisualTextObject) <Plug>(MatchitVisualMultiBackward)o<Plug>(MatchitVisualMultiForward)
onoremap <silent> <Plug>(MatchitOperationMultiForward) :call matchit#MultiMatch("W",  "o")
onoremap <silent> <Plug>(MatchitOperationMultiBackward) :call matchit#MultiMatch("bW", "o")
xnoremap <silent> <Plug>(MatchitVisualMultiForward) :call matchit#MultiMatch("W",  "n")m'gv``
xnoremap <silent> <Plug>(MatchitVisualMultiBackward) :call matchit#MultiMatch("bW", "n")m'gv``
nnoremap <silent> <Plug>(MatchitNormalMultiForward) :call matchit#MultiMatch("W",  "n")
nnoremap <silent> <Plug>(MatchitNormalMultiBackward) :call matchit#MultiMatch("bW", "n")
onoremap <silent> <Plug>(MatchitOperationBackward) :call matchit#Match_wrapper('',0,'o')
onoremap <silent> <Plug>(MatchitOperationForward) :call matchit#Match_wrapper('',1,'o')
xnoremap <silent> <Plug>(MatchitVisualBackward) :call matchit#Match_wrapper('',0,'v')m'gv``
xnoremap <silent> <Plug>(MatchitVisualForward) :call matchit#Match_wrapper('',1,'v'):if col("''") != col("$") | exe ":normal! m'" | endifgv``
nnoremap <silent> <Plug>(MatchitNormalBackward) :call matchit#Match_wrapper('',0,'n')
nnoremap <silent> <Plug>(MatchitNormalForward) :call matchit#Match_wrapper('',1,'n')
xnoremap <silent> <M-k> :m '<-2gv=gv
xnoremap <silent> <M-j> :m '>+1gv=gv
snoremap <silent> <M-k> :m '<-2gv=gv
snoremap <silent> <M-j> :m '>+1gv=gv
nnoremap <silent> <M-k> :m .-2==
nnoremap <silent> <M-j> :m .+1==
nnoremap <silent> <C-Right> :vertical resize -2
nnoremap <silent> <C-Left> :vertical resize +2
nnoremap <silent> <C-Down> :resize +2
nnoremap <silent> <C-Up> :resize -2
nnoremap <silent> <C-K> k
nnoremap <silent> <C-J> j
nnoremap <silent> <C-H> <Cmd>lua COQ.Nav_mark()
nnoremap <silent> <C-L> l
inoremap <silent> <expr>  pumvisible() ? '' : ''
inoremap <silent>  <Cmd>lua COQ.Nav_mark()
inoremap <silent> <expr> 	 pumvisible() ? '' : '	'
inoremap <silent> <expr>  (pumvisible() && complete_info(['mode']).mode ==# 'eval') ? Preview_preview() : ''
inoremap <silent> <expr>  pumvisible() ? (complete_info(['selected']).selected == -1 ? '' : '') : ''
inoremap <silent> <expr>  pumvisible() ? '' : ''
inoremap <silent> <expr>  pumvisible() ? '' : ''
inoremap <silent> <expr>  pumvisible() ? '' : ''
inoremap <silent> jk 
inoremap <silent> kj 
let &cpo=s:cpo_save
unlet s:cpo_save
set clipboard=unnamedplus
set cmdheight=2
set completefunc=v:lua.COQ.Omnifunc
set completeopt=menuone,noselect,noinsert,menuone,noselect
set expandtab
set guicursor=
set guifont=monospace:h17
set ignorecase
set isfname=#,$,%,+,,,-,.,/,48-57,=,@,_,~,@-@
set mouse=a
set pumheight=16
set runtimepath=~/.config/nvim,/etc/xdg/nvim,~/.local/share/nvim/site,~/.local/share/nvim/site/pack/packer/start/packer.nvim,~/.local/share/nvim/site/pack/*/start/*,/usr/local/share/nvim/site,/usr/share/nvim/site,/usr/share/nvim/runtime,/usr/share/nvim/runtime/pack/dist/opt/matchit,/usr/lib/x86_64-linux-gnu/nvim,/usr/share/nvim/site/after,/usr/local/share/nvim/site/after,~/.local/share/nvim/site/after,/etc/xdg/nvim/after,~/.config/nvim/after
set scrolloff=8
set shiftwidth=4
set shortmess=filnxtToOCFc
set showtabline=2
set sidescrolloff=8
set smartcase
set smartindent
set softtabstop=4
set splitbelow
set splitright
set noswapfile
set tabstop=4
set termguicolors
set timeoutlen=300
set undodir=~/.vim/undodir
set undofile
set updatetime=50
set whichwrap=bs<>[]hl
set window=59
set nowritebackup
" vim: set ft=vim :
