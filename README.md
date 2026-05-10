# vim9-keymaps

> **Fork of [liuchengxu/vim-which-key](https://github.com/liuchengxu/vim-which-key) converted to pure vim9script.**

Minimal configuration:

```vim
g:mapleader = "\<Space>"
g:maplocalleader = ','

nnoremap <silent> <leader>      :<c-u>Keymaps '<Space>'<CR>
nnoremap <silent> <localleader> :<c-u>Keymaps  ','<CR>

g:keymaps_map = {}
keymaps#Register('<Space>', "g:keymaps_map")

" Add your mappings to g:keymaps_map:
"   group: g:keymaps_map.f = { 'name': '+file' }
"   item:  g:keymaps_map.f.s = 'save-file'
```
