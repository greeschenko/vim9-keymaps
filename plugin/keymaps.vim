vim9script

if exists('g:loaded_keymaps')
  finish
endif
g:loaded_keymaps = true

var save_cpo = &cpo
set cpo&vim

g:keymaps_sep = get(g:, 'keymaps_sep', '→')
g:keymaps_hspace = get(g:, 'keymaps_hspace', 5)
g:keymaps_flatten = get(g:, 'keymaps_flatten', 1)
g:keymaps_timeout = get(g:, 'keymaps_timeout', &timeoutlen)
g:keymaps_max_size = get(g:, 'keymaps_max_size', 0)
g:keymaps_vertical = get(g:, 'keymaps_vertical', 0)
g:keymaps_position = get(g:, 'keymaps_position', 'botright')
g:keymaps_centered = get(g:, 'keymaps_centered', 1)
g:keymaps_group_dicts = get(g:, 'keymaps_group_dicts', 'end')
g:keymaps_sort_horizontal = get(g:, 'keymaps_sort_horizontal', 0)
g:keymaps_run_map_on_popup = get(g:, 'keymaps_run_map_on_popup', 1)
g:keymaps_align_by_separator = get(g:, 'keymaps_align_by_separator', 1)
g:keymaps_ignore_invalid_key = get(g:, 'keymaps_ignore_invalid_key', 1)
g:keymaps_ignore_outside_mappings = get(g:, 'keymaps_ignore_outside_mappings', 0)
g:keymaps_fallback_to_native_key = get(g:, 'keymaps_fallback_to_native_key', 0)
g:keymaps_default_group_name = get(g:, 'keymaps_default_group_name', '+prefix')
g:keymaps_use_floating_win = (exists('*nvim_open_win') || exists('*popup_create')) && get(g:, 'keymaps_use_floating_win', 1)
g:keymaps_floating_relative_win = get(g:, 'keymaps_floating_relative_win', 0)
g:keymaps_disable_default_offset = get(g:, 'keymaps_disable_default_offset', 0)
g:keymaps_list_view = get(g:, 'keymaps_list_view', 1)
g:keymaps_list_width = get(g:, 'keymaps_list_width', 25)
g:KeymapsFormatFunc = get(g:, 'KeymapsFormatFunc', function('keymaps#Format'))

command! -bang -nargs=1 Keymaps keymaps#Start(0, <bang>0, <args>)
command! -bang -nargs=1 -range KeymapsVisual keymaps#Start(1, <bang>0, <args>)

&cpo = save_cpo
