vim9script

var bufnr = -1
var winnr = -1
var popup_id = -1
var prompt_popup_id = -1
var origin_lnum_width = 0
var pos: list<any> = []
var name = ''

var use_popup = exists('*popup_create')

if !hlexists('KeymapsFloating')
  hi default link KeymapsFloating Pmenu
endif

def HideCursor()
  augroup keymaps_cursor
    autocmd!
    execute 'autocmd BufLeave <buffer> set t_ve=' .. escape(&t_ve, '|')
    execute 'autocmd VimLeave <buffer> set t_ve=' .. escape(&t_ve, '|')
  augroup END
  setlocal t_ve=
enddef

def SplitOrNew()
  var position = g:keymaps_position ==? 'topleft' ? 'topleft' : 'botright'

  if g:keymaps_use_floating_win
    var qfbuf = &buftype ==# 'quickfix'
    var splitcmd = g:keymaps_vertical ? '1vsplit' : '1split'
    noautocmd execute 'keepjumps ' .. position .. ' ' .. splitcmd .. ' +buffer' .. bufnr
    cmapclear <buffer>
    if qfbuf
      noautocmd execute bufnr('%') .. 'bwipeout!'
    endif
  else
    var splitcmd = g:keymaps_vertical ? '1vnew' : '1new'
    noautocmd execute 'keepjumps ' .. position .. ' ' .. splitcmd
    bufnr = bufnr('%')
    augroup keymaps_leave
      autocmd!
      autocmd WinLeave <buffer> keymaps#window#Close()
    augroup END
  endif
enddef

def AppendPrompt(rows: list<string>): list<string>
  var prompt = keymaps#Trigger() .. '- ' .. keymaps#window#Name()
  extend(rows, ['', prompt])
  return rows
enddef

def FloatingWinColOffset(): number
  if g:keymaps_disable_default_offset
    return 0
  else
    return (&number ? len(string(line('$'))) : 0) + (exists('&signcolumn') && &signcolumn ==# 'yes' ? 2 : 0)
  endif
enddef

def ApplyCustomFloatingOpts(opts: dict<any>): dict<any>
  if exists('g:keymaps_floating_opts')
    for [key, val] in items(g:keymaps_floating_opts)
      if has_key(opts, key)
        opts[key] = opts[key] + eval('0' .. val)
      endif
    endfor
  endif
  if exists('g:keymaps_floating_opts_explicit')
    for [key, val] in items(g:keymaps_floating_opts_explicit)
      opts[key] = val
    endfor
  endif
  return opts
enddef

def ShowPopup(rows: list<string>)
  var offset = FloatingWinColOffset()
  var col = 0
  var line = 0
  var total_width = 0
  var total_height = 0
  var display_rows: list<string>

  if get(g:, 'keymaps_list_view', 1)
    display_rows = rows
    var text_width = 0
    for display_row in display_rows
      text_width = max([text_width, strdisplaywidth(display_row)])
    endfor
    var win_width = winwidth(g:keymaps_origin_winid)
    text_width = min([text_width, g:keymaps_list_width, win_width - 3])
    total_width = text_width + 2
    total_height = len(display_rows) + 2

    var win_row = win_screenpos(g:keymaps_origin_winid)[0]
    var win_col = win_screenpos(g:keymaps_origin_winid)[1]
    var win_height = winheight(g:keymaps_origin_winid)

    col = win_col + win_width - total_width
    if col < 1
      col = 1
    endif

    var max_line = &lines - &cmdheight
    line = win_row + win_height - total_height
    if line + total_height - 1 > max_line
      line = max_line - total_height + 1
    endif
    if line < 1
      line = 1
    endif
  else
    display_rows = AppendPrompt(rows)
    total_height = len(display_rows)
    if g:keymaps_floating_relative_win
      col = offset + win_screenpos(g:keymaps_origin_winid)[1] + 1
      total_width = winwidth(g:keymaps_origin_winid) - offset
      line = &lines - len(rows) - &cmdheight
    else
      col = offset + 1
      total_width = &columns - offset
      line = &lines - len(rows) - &cmdheight
    endif
  endif

  if popup_id < 0
    var opts: dict<any> = {
      line: line,
      col: col,
      highlight: 'KeymapsFloating',
    }
    if get(g:, 'keymaps_list_view', 1)
      opts['border'] = []
      opts['borderchars'] = ['─', '│', '─', '│', '╭', '╮', '╯', '╰']
    else
      opts['minwidth'] = total_width
      opts['maxwidth'] = total_width
      opts['minheight'] = total_height
      opts['maxheight'] = total_height
    endif
    opts = ApplyCustomFloatingOpts(opts)
    popup_id = popup_create(display_rows, opts)
    setbufvar(winbufnr(popup_id), '&filetype', 'keymaps')
    win_execute(popup_id, 'setlocal nonumber nowrap')
    if exists('g:keymaps_floating_vars')
      for [key, val] in items(g:keymaps_floating_vars)
        setwinvar(popup_id, key, val)
      endfor
    endif
  else
    if get(g:, 'keymaps_list_view', 1)
      popup_move(popup_id, {line: line, col: col})
    else
      popup_move(popup_id, {
        line: line,
        col: col,
        minwidth: total_width,
        maxwidth: total_width,
        minheight: total_height,
        maxheight: total_height,
        })
    endif
    popup_settext(popup_id, display_rows)
    popup_show(popup_id)
  endif

  if get(g:, 'keymaps_list_view', 1)
    var prompt_text = keymaps#Trigger() .. '- ' .. keymaps#window#Name()
    var prompt_rows = [prompt_text]
    var win_row = win_screenpos(g:keymaps_origin_winid)[0]
    var win_col = win_screenpos(g:keymaps_origin_winid)[1]
    var win_height = winheight(g:keymaps_origin_winid)
    var prompt_width = min([strdisplaywidth(prompt_text), g:keymaps_list_width])
    var prompt_col = win_col + 1
    var max_line = &lines - &cmdheight
    var prompt_line = win_row + win_height - 1
    if prompt_line > max_line
      prompt_line = max_line
    endif
    if prompt_line < 1
      prompt_line = 1
    endif

    if prompt_popup_id < 0
      var prompt_opts: dict<any> = {
        line: prompt_line,
        col: prompt_col,
        minwidth: prompt_width,
        minheight: 1,
        highlight: 'KeymapsFloating',
      }
      prompt_popup_id = popup_create(prompt_rows, prompt_opts)
      win_execute(prompt_popup_id, 'setlocal nonumber nowrap')
    else
      popup_move(prompt_popup_id, {line: prompt_line, col: prompt_col})
      popup_settext(prompt_popup_id, prompt_rows)
      popup_show(prompt_popup_id)
    endif
  elseif prompt_popup_id >= 0
    popup_close(prompt_popup_id)
    prompt_popup_id = -1
  endif
enddef



def ShowOldWin(rows: list<string>, layout: dict<any>)
  if winnr < 0
    OpenSplitWin()
  endif

  var resize = g:keymaps_vertical ? 'vertical resize' : 'resize'
  noautocmd execute resize .. ' ' .. layout.win_dim
  setlocal modifiable
  execute('%delete _')
  setline(1, rows)
  setlocal nomodifiable
enddef

export def Show(runtime: dict<any>)
  name = get(runtime, 'name', '')
  var [layout, rows] = keymaps#renderer#Prepare(runtime)

  if use_popup
    ShowPopup(rows)
  else
    ShowOldWin(rows, layout)
  endif

  keymaps#WaitForInput()
enddef

def OpenSplitWin()
  pos = [winsaveview(), winnr(), winrestcmd()]
  SplitOrNew()
  HideCursor()
  setlocal filetype=keymaps
  winnr = winnr()
enddef

def CloseSplitWin()
  noautocmd execute winnr .. 'wincmd w'
  if winnr() == winnr
    close!
    execute pos[-1]
    noautocmd execute pos[1] .. 'wincmd w'
    winrestview(pos[0])
    winnr = -1
  endif
enddef

export def Close()
  if popup_id >= 0
    popup_close(popup_id)
    popup_id = -1
  else
    CloseSplitWin()
  endif

  if prompt_popup_id >= 0
    popup_close(prompt_popup_id)
    prompt_popup_id = -1
  endif

  if exists('g:keymaps_on_close')
    g:keymaps_on_close()
  elseif exists('*lightline#update')
    lightline#update()
  elseif exists('*airline#update')
    airline#update()
  endif
enddef

export def Name(): string
  return name
enddef

defcompile
