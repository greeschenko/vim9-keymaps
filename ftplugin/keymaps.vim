vim9script

setlocal nonumber
setlocal norelativenumber
setlocal nolist
setlocal nowrap
setlocal nofoldenable
setlocal nopaste
setlocal nomodeline
setlocal noswapfile
setlocal nocursorline
setlocal nocursorcolumn
setlocal colorcolumn=
setlocal nobuflisted
setlocal buftype=nofile
setlocal bufhidden=unload
setlocal nospell

&l:statusline = keymaps#Statusline()

hi KeymapsTrigger ctermfg=232 ctermbg=178 guifg=#333300 guibg=#ffbb7d
hi KeymapsName cterm=bold ctermfg=171 ctermbg=239 gui=bold guifg=#d75fd7 guibg=#4e4e4e
