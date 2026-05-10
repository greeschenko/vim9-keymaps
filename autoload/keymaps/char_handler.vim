vim9script

var TYPE = g:keymaps#TYPE

var chars = range(32, 126)->mapnew((_, v) => nr2char(v))

var special_keys = {
  "\<Bar>": '<Bar>',
  "\<Bslash>": '<Bslash>',
  "\<Up>": '<Up>',
  "\<Down>": '<Down>',
  "\<Left>": '<Left>',
  "\<Right>": '<Right>',
  "\<LeftMouse>": '<LeftMouse>',
  "\<RightMouse>": '<RightMouse>',
  "\<MiddleMouse>": '<MiddleMouse>',
  "\<2-LeftMouse>": '<2-LeftMouse>',
  "\<C-LeftMouse>": '<C-LeftMouse>',
  "\<S-LeftMouse>": '<S-LeftMouse>',
  "\<ScrollWheelUp>": '<ScrollWheelUp>',
  "\<ScrollWheelDown>": '<ScrollWheelDown>',
  "\<C-Space>": '<C-Space>',
  "\<C-Left>": '<C-Left>',
  "\<C-Right>": '<C-Right>',
  "\<S-Left>": '<S-Left>',
  "\<S-Right>": '<S-Right>',
  }

def GenKeyMapping(mode: string, key: string): list<string>
  var repr = '<'
  if mode != ''
    repr = repr .. mode .. '-'
  endif
  if key ==# '"'
    repr = repr .. '\'
  endif
  repr = repr .. key .. '>'
  var code = eval('"' .. '\' .. repr .. '"')
  return [repr, code]
enddef

var pair = ['', '']
for c in chars
  pair = GenKeyMapping('M', c)
  special_keys[pair[1]] = pair[0]
endfor

for fk in range(1, 37)
  for p in ['', 'S', 'C', 'M']
    pair = GenKeyMapping(p, 'F' .. fk)
    special_keys[pair[1]] = pair[0]
  endfor
endfor

export def ParseRaw(raw_char: any): string
  if type(raw_char) == TYPE.number
    return nr2char(raw_char)
  elseif has_key(special_keys, raw_char)
    return special_keys[raw_char]
  else
    return raw_char
  endif
enddef

def GetInitialExitCode(): list<string>
  if exists('g:keymaps_exit')
    var ty = type(g:keymaps_exit)
    if ty == TYPE.number
      return [nr2char(g:keymaps_exit)]
    elseif ty == TYPE.string
      return [g:keymaps_exit]
    elseif ty == TYPE.list
      return map(g:keymaps_exit, (_, val) => type(val) == TYPE.number ? nr2char(val) : val)
    else
      echohl ErrorMsg
      echon '[which-key] ' .. g:keymaps_exit .. ' is invalid for option g:keymaps_exit'
      echohl None
    endif
  endif
  return ["\<Esc>"]
enddef

var exit_code = GetInitialExitCode()

export def IsExitCode(raw_char: any): bool
  return -1 != index(exit_code, type(raw_char) == TYPE.number ? nr2char(raw_char) : raw_char)
enddef

def WaitWithTimeoutImpl(timeout: number): bool
  var remaining = timeout
  while remaining > 0
    if getchar(1)
      return 0
    endif
    sleep 20m
    remaining -= 20
  endwhile
  return !getchar(1)
enddef

export def WaitWithTimeout(): bool
  return WaitWithTimeoutImpl(g:keymaps_timeout)
enddef

export def TimeoutForNextChar(): bool
  return WaitWithTimeoutImpl(g:keymaps_timeout)
enddef

defcompile
