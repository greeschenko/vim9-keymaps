vim9script

if exists('b:current_syntax')
  finish
endif
b:current_syntax = 'keymaps'

var sep = keymaps#GetSep()

execute 'syntax match KeymapsSeparator' '/' .. sep .. '/' 'contained'
execute 'syntax match Keymaps' '/\(^\s*\|\s\{2,}\)\S.\{-}' .. sep .. '/' 'contains=KeymapsSeparator'
syntax match KeymapsGroup / +[0-9A-Za-z_/-]*/
syntax region KeymapsDesc start="^" end="$" contains=Keymaps,KeymapsGroup,KeymapsSeparator

highlight default link Keymaps          Function
highlight default link KeymapsSeparator DiffAdded
highlight default link KeymapsGroup     Keyword
highlight default link KeymapsDesc      Identifier
