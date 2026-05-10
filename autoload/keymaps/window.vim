vim9script

var bufnr = -1
var winnr = -1
var popup_id = -1
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
  if popup_id < 0
    var opts = {highlight: 'KeymapsFloating'}
    opts = ApplyCustomFloatingOpts(opts)
    popup_id = popup_create([], opts)
    popup_hide(popup_id)
    setbufvar(winbufnr(popup_id), '&filetype', 'keymaps')
    win_execute(popup_id, 'setlocal nonumber nowrap')
    if exists('g:keymaps_floating_vars')
      for [key, val] in items(g:keymaps_floating_vars)
        setwinvar(popup_id, key, val)
      endfor
    endif
  endif

  var display_rows = AppendPrompt(rows)
  var offset = FloatingWinColOffset()
  var col = 0
  var maxwidth = 0
  if g:keymaps_floating_relative_win
    col = offset + win_screenpos(g:keymaps_origin_winid)[1] + 1
    maxwidth = winwidth(g:keymaps_origin_winid) - offset
  else
    col = offset + 1
    maxwidth = &columns - offset
  endif
  popup_move(popup_id, {
    col: col,
    line: &lines - len(rows) - &cmdheight,
    maxwidth: maxwidth,
    minwidth: maxwidth,
    })
  popup_settext(popup_id, display_rows)
  popup_show(popup_id)
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
