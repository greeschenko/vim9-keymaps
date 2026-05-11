vim9script

var TYPE = g:keymaps#TYPE
var target_winwidth = 0

var default_displaynames = {
  ' ': 'SPC',
  '<C-H>': 'BS',
  '<TAB>': 'TAB',
  }

export def Prepare(runtime: dict<any>): list<any>
  var layout = CalcLayout(runtime)
  var rows = CreateRows(layout, runtime)
  return [layout, rows]
enddef

export def GetDisplaynames(): dict<any>
  if exists('g:keymaps_display_names')
    return g:keymaps_display_names
  endif
  return default_displaynames
enddef

def CalcLayout(mappings: dict<any>): dict<any>
  var layout: dict<any> = {}
  var smap = filter(copy(mappings), (k, v) => k !=# 'name' && !(type(v) == TYPE.list && v[1] ==# 'keymaps_ignore'))
  layout['n_items'] = len(smap)
  var displaynames = GetDisplaynames()

  var prefix_length = values(map(copy(smap), (k, v) => strdisplaywidth(get(displaynames, toupper(k), k))))
  var suffix_length = values(map(smap, (k, v) => strdisplaywidth(type(v) == TYPE.dict ? get(v, 'name', '') : v[1])))

  var maxlength = max(prefix_length) + max(suffix_length) + strdisplaywidth(g:keymaps_sep) + 2

  if g:keymaps_vertical
    if g:keymaps_floating_relative_win
      layout['n_rows'] = winheight(g:keymaps_origin_winid) - 2
    else
      layout['n_rows'] = winheight(0) - 2
    endif

    layout['n_cols'] = layout['n_items'] / layout['n_rows'] + (layout['n_items'] != layout['n_rows'])
    layout['col_width'] = maxlength
    layout['win_dim'] = layout['n_cols'] * layout['col_width']
    target_winwidth = layout['col_width']

  else
    maxlength += g:keymaps_hspace

    var winwidth_val: number
    if g:keymaps_floating_relative_win
      winwidth_val = winwidth(g:keymaps_origin_winid)
    else
      winwidth_val = &columns
    endif

    if maxlength > winwidth_val
      layout['n_cols'] = 1
    else
      layout['n_cols'] = winwidth_val / maxlength
    endif

    layout['n_rows'] = layout['n_items'] / layout['n_cols'] + (layout['n_items'] % layout['n_cols'] > 0 ? 1 : 0)
    layout['col_width'] = winwidth_val / layout['n_cols']
    layout['win_dim'] = layout['n_rows']
    target_winwidth = winwidth_val
  endif

  if g:keymaps_max_size
    layout['win_dim'] = min([g:keymaps_max_size, layout['win_dim']])
  endif

  if get(g:, 'keymaps_list_view', 1)
    layout['n_cols'] = 1
    layout['n_rows'] = layout['n_items']
    layout['col_width'] = maxlength + g:keymaps_hspace
    layout['win_dim'] = layout['n_rows']
    target_winwidth = g:keymaps_list_width
  endif

  return layout
enddef

def CreateRows(layout: dict<any>, mappings: dict<any>): list<string>
  var capacity = layout['n_items']

  var rows: list<list<string>> = []
  var row_max_size = 0
  var row = 0
  var col = 0

  var smap: list<string> = []
  if exists('g:keymaps_group_dicts') && g:keymaps_group_dicts != ''
    var leaf_keys: list<string> = []
    var dict_keys: list<string> = []

    for key in sort(keys(mappings)->filter((_, v) => v !=# 'name'), 'i')
      if type(mappings[key]) == TYPE.dict
        add(dict_keys, key)
      else
        add(leaf_keys, key)
      endif
    endfor

    if g:keymaps_group_dicts ==? 'end'
      smap = leaf_keys + dict_keys
    else
      smap = dict_keys + leaf_keys
    endif
  else
    smap = sort(keys(mappings)->filter((_, v) => v !=# 'name'), 'i')
  endif

  var displaynames = GetDisplaynames()
  var key_max_len = 0
  if get(g:, 'keymaps_align_by_separator', 1)
    for k in smap
      var key = get(displaynames, toupper(k), k)
      var width = strdisplaywidth(key)
      if width > key_max_len
        key_max_len = width
      endif
    endfor
  endif

  for k in smap
    var key = get(displaynames, toupper(k), k)
    var desc = type(mappings[k]) == TYPE.dict ? get(mappings[k], 'name', '') : mappings[k][1]
    if desc ==# 'keymaps_ignore'
      continue
    endif

    if get(g:, 'keymaps_align_by_separator', 1)
      var width = strdisplaywidth(key)
      if key_max_len > width
        key = repeat(' ', key_max_len - width) .. key
      endif
    endif

    var item = Combine(key, desc)

    var crow = get(rows, row, [])
    if empty(crow)
      add(crow, '')
      add(rows, crow)
    endif
    if col == layout['n_cols'] - 1
      crow->add(item)
    else
      crow->add(item .. repeat(' ', layout['col_width'] - strdisplaywidth(item)))
    endif
    row_max_size = max([row_max_size, strdisplaywidth(join(crow, ''))])

    if !g:keymaps_sort_horizontal
      if row >= layout['n_rows'] - 1
        if capacity > 0 && row < layout['n_rows']
          row += 1
        else
          row = 0
          col += 1
        endif
      else
        row += 1
      endif
    else
      if col == layout['n_cols'] - 1
        row += 1
        col = 0
      else
        col += 1
      endif
    endif
  endfor

  if g:keymaps_centered && !get(g:, 'keymaps_list_view', 0)
    var sign_column_size = exists('&signcolumn') && &signcolumn ==# 'yes' ? 2 : 0
    var line_number_size = &number ? len(string(line('$'))) : 0
    var centered_offset = sign_column_size + line_number_size

    var display_cap = g:keymaps_floating_relative_win ? winwidth(g:keymaps_origin_winid) : &columns
    var max_display_size = display_cap - centered_offset

    var left_padding_size = float2nr(floor((max_display_size - row_max_size) / 2))

    for r in range(len(rows))
      rows[r][0] = repeat(' ', left_padding_size)
    endfor
  endif

  return rows->mapnew((_, v) => join(v, ''))
enddef

def Combine(key: string, desc: string): string
  var item = join([key, g:keymaps_sep, desc], ' ')
  if strdisplaywidth(item) > target_winwidth
    return item[ : target_winwidth - 4] .. '..'
  endif
  return item
enddef

def EscapeKeys(inp: string): string
  var ret = inp
  ret = substitute(ret, '<', '<lt>', '')
  ret = substitute(ret, '|', '<Bar>', '')
  return ret
enddef

defcompile
