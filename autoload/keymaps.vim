vim9script

var desc = { n: {}, v: {} }
var cache = { n: {}, v: {} }
var TYPE = {
  list: type([]),
  dict: type({}),
  number: type(0),
  string: type(''),
  funcref: type(function('call'))
  }
var KEYCODES = {
  "\<BS>": '<BS>',
  "\<80>kb": '<BS>',
  "\<Tab>": '<Tab>',
  "\<CR>": '<CR>',
  "\<Esc>": '<Esc>',
  "\<Del>": '<Del>'
  }
var MERGE_INTO = {
  '<Space>': ' ',
  '<C-H>': '<BS>',
  '<C-I>': '<Tab>',
  '<C-M>': '<CR>',
  '<Return>': '<CR>',
  '<Enter>': '<CR>',
  '<C-[>': '<Esc>',
  '<lt>': '<',
  '<Bslash>': '\',
  '<Bar>': '|'
  }
var REQUIRES_REGEX_ESCAPE = ['$', '*', '~', '.']

g:keymaps#TYPE = TYPE

var should_note_winid = exists('*win_getid')

var vis = ''
var count = ''
var keymaps_trigger = ''
var runtime: dict<any> = {}
var last_runtime_stack: list<dict<any>> = []
var cur_char = ''
var reg = ''
var reg_inited = false

export def Register(prefix: string, dict_val: any, ...args: list<any>)
  var key = has_key(KEYCODES, prefix) ? KEYCODES[prefix] : prefix
  key = has_key(MERGE_INTO, key) ? MERGE_INTO[key] : key
  var val = dict_val
  if args->len() == 1
    extend(desc[args[0]], {[key]: val})
  else
    extend(desc['n'], {[key]: val})
    extend(desc['v'], {[key]: val})
  endif
enddef

def HandleCharOnStartIsOk(c: any): bool
  if keymaps#char_handler#IsExitCode(c)
    return true
  endif
  var char_val = keymaps#char_handler#ParseRaw(c)
  if has_key(KEYCODES, char_val)
    char_val = KEYCODES[char_val]
  else
    char_val = keymaps#char_handler#ParseRaw(char_val)
  endif
  if has_key(MERGE_INTO, char_val)
    char_val = MERGE_INTO[char_val]
  endif
  var displaynames = keymaps#renderer#GetDisplaynames()
  keymaps_trigger = keymaps_trigger .. ' ' .. get(displaynames, toupper(char_val), char_val)
  var next_level = get(runtime, char_val)
  var ty = type(next_level)
  if ty == TYPE.dict
    runtime = next_level
    return false
  elseif ty == TYPE.list && (!g:keymaps_fallback_to_native_key ||
      g:keymaps_fallback_to_native_key &&
      next_level[0] !=# 'keymaps#error#MissingMapping()')
    ExecuteFunc(next_level[0])
    return true
  elseif g:keymaps_fallback_to_native_key
    ExecuteNativeFallback(0)
    return true
  else
    keymaps#error#UndefinedKey(keymaps_trigger)
    return true
  endif
enddef

export def Start(vis_param: bool, bang: bool, prefix: any)
  vis = vis_param ? 'gv' : ''
  var mode = vis_param ? 'v' : 'n'
  count = v:count != 0 ? string(v:count) : ''
  keymaps_trigger = ''

  if should_note_winid
    g:keymaps_origin_winid = win_getid()
  endif

  if bang
    for kv in keys(prefix)
      CacheKey(mode, kv)
    endfor
    runtime = deepcopy(prefix)
    Merge(runtime, cache[mode])
  else
    var key = prefix
    if has_key(KEYCODES, key)
      key = KEYCODES[key]
    else
      key = keymaps#char_handler#ParseRaw(key)
    endif
    if has_key(MERGE_INTO, key)
      key = MERGE_INTO[key]
    endif
    var displaynames = keymaps#renderer#GetDisplaynames()
    keymaps_trigger = get(displaynames, toupper(key), key)
    CacheKey(mode, key)

    runtime = CreateRuntime(mode, key)

    if getchar(1)
      while true
        var c: any
        try
          c = getchar()
        catch /^Vim:Interrupt$/
          return
        endtry
        if HandleCharOnStartIsOk(c)
          return
        endif
        if keymaps#char_handler#WaitWithTimeout()
          break
        endif
      endwhile
    endif
  endif

  last_runtime_stack = [copy(runtime)]
  keymaps#window#Show(runtime)
enddef

def CacheKey(mode: string, key: string)
  if !has_key(cache[mode], key) || g:keymaps_run_map_on_popup
    cache[mode][key] = {}
    keymaps#mappings#Parse(key, cache[mode], mode)
  endif
enddef

def CreateRuntime(mode: string, key: string): dict<any>
  if has_key(desc[mode], key)
    var runtime_val = {}
    if type(desc[mode][key]) == TYPE.dict
      runtime_val = deepcopy(desc[mode][key])
    else
      runtime_val = deepcopy(eval(desc[mode][key]))
    endif
    var native = cache[mode][key]
    Merge(runtime_val, native)
    return runtime_val
  endif
  return cache[mode][key]
enddef

def Merge(target: dict<any>, native: dict<any>)
  var mergekeys = filter(copy(target), (k, _) => has_key(MERGE_INTO, k))
  for [k, _] in items(mergekeys)
    if has_key(target, MERGE_INTO[k])
      extend(target[MERGE_INTO[k]], target[k], 'keep')
    else
      extend(target, {[MERGE_INTO[k]]: target[k]})
    endif
  endfor
  filter(target, (k, _) => !has_key(MERGE_INTO, k))

  for [k, V] in items(target)
    var val = V
    while type(target[k]) == TYPE.funcref
      target[k] = target[k]()
      val = target[k]
    endwhile

    if type(val) == TYPE.dict
      if has_key(native, k)
        if type(native[k]) == TYPE.dict
          if has_key(val, 'name')
            native[k]['name'] = val['name']
          endif
          Merge(target[k], native[k])
        elseif type(native[k]) == TYPE.list
          target[k] = native[k]
        endif
      else
        Merge(target[k], {})
      endif
    elseif type(val) == TYPE.string && k !=# 'name'
      if has_key(native, k)
        target[k] = [native[k][0], val]
      else
        target[k] = ['keymaps#error#MissingMapping()', val]
      endif
    endif
  endfor

  if !g:keymaps_ignore_outside_mappings
    extend(target, native, 'keep')
  endif
enddef

def EchoPrompt()
  echohl Keyword
  echo keymaps_trigger .. '- '
  echohl None

  echohl String
  echon keymaps#window#Name()
  echohl None
enddef

def HasChildren(input: string): bool
  if index(REQUIRES_REGEX_ESCAPE, input) != -1
    return len(filter(keys(runtime), (_, v) => v =~# '^\' .. input)) > 1
  endif
  return len(filter(keys(runtime), (_, v) => v =~# '^' .. input)) > 1
enddef

def ShowUpperLevelMappings()
  if empty(last_runtime_stack)
    keymaps#window#Show(runtime)
    return
  endif

  var last_runtime = last_runtime_stack[-1]
  runtime = last_runtime

  if len(last_runtime_stack) > 1
    keymaps_trigger = join(split(keymaps_trigger)[ : -2], ' ')
  endif

  remove(last_runtime_stack, -1)

  keymaps#window#Show(last_runtime)
enddef

def GetcharFunc(): any
  var c: any = 0
  try
    c = getchar()
  catch /^Vim:Interrupt$/
    keymaps#window#Close()
    redraw!
    return ''
  endtry

  if keymaps#char_handler#IsExitCode(c)
    keymaps#window#Close()
    redraw!
    return ''
  endif

  var input = keymaps#char_handler#ParseRaw(c)

  if has_key(KEYCODES, input)
    input = KEYCODES[input]
  elseif has_key(MERGE_INTO, input)
    input = MERGE_INTO[input]
  endif

  if input ==# '<BS>'
    ShowUpperLevelMappings()
    return ''
  endif

  if HasChildren(input)
    while true
      if !keymaps#char_handler#TimeoutForNextChar()
        input = input .. keymaps#char_handler#ParseRaw(getchar())
      else
        break
      endif
    endwhile
  endif

  return input
enddef

export def WaitForInput()
  redraw

  if !g:keymaps_use_floating_win
    EchoPrompt()
  endif

  var char_val = GetcharFunc()
  if char_val ==# ''
    return
  endif

  cur_char = char_val

  HandleInput(get(runtime, char_val))
enddef

def ShowNextLevelMappings(next_runtime: dict<any>)
  var displaynames = keymaps#renderer#GetDisplaynames()
  keymaps_trigger = keymaps_trigger .. ' ' .. get(displaynames, toupper(cur_char), cur_char)
  add(last_runtime_stack, copy(runtime))
  runtime = next_runtime
  keymaps#window#Show(runtime)
enddef

def HandleInput(input_val: any)
  var ty = type(input_val)

  if ty == TYPE.dict
    ShowNextLevelMappings(input_val)
    return
  endif

  if ty == TYPE.list && (!g:keymaps_fallback_to_native_key ||
      g:keymaps_fallback_to_native_key &&
      input_val[0] !=# 'keymaps#error#MissingMapping()')
    keymaps#window#Close()
    ExecuteFunc(input_val[0])
  elseif g:keymaps_fallback_to_native_key
    keymaps#window#Close()
    ExecuteNativeFallback(1)
  else
    if g:keymaps_ignore_invalid_key
      keymaps#WaitForInput()
    else
      keymaps#window#Close()
      redraw!
      keymaps#error#UndefinedKey(keymaps_trigger)
    endif
  endif
enddef

def ExecuteNativeFallback(append: bool)
  var lreg = GetRegister()
  var fallback_cmd = vis .. lreg .. count .. substitute(substitute(keymaps_trigger, ' ', '', 'g'), '<Space>', ' ', 'g')
  if append
    fallback_cmd = fallback_cmd .. cur_char
  endif
  try
    feedkeys(fallback_cmd, 'n')
  catch
    keymaps#error#Report('Exception: ' .. v:exception .. ' occurs for the fallback mapping: ' .. fallback_cmd)
  endtry
enddef

def JoinFunc(...args: list<string>): string
  return join(args, ' ')
enddef

def ExecuteFunc(cmd: any)
  var reg_val = GetRegister()
  if vis .. reg_val .. count !=# ''
    execute 'normal!' .. vis .. reg_val .. count
  endif
  redraw
  var Cmd = cmd
  try
    if type(Cmd) == TYPE.funcref
      call(Cmd, [])
      return
    endif
    if Cmd =~? '^<Plug>.\+' || Cmd =~? '^<C-W>.\+' || Cmd =~? '^<.\+>$'
      Cmd = JoinFunc('call', 'feedkeys("\' .. Cmd .. '")')
    elseif Cmd =~? '.(*)$' && match(Cmd, '\<call\>') == -1
      Cmd = JoinFunc('call', Cmd)
    elseif exists(':' .. Cmd) || Cmd =~# '^:' || Cmd =~? '^call feedkeys(.*)$'
      if !empty(vis)
        Cmd = line('v') .. ',' .. line('.') .. Cmd
      endif
    else
      Cmd = JoinFunc('call', 'feedkeys("' .. Cmd .. '")')
    endif
    execute Cmd
  catch
    echom v:exception
  endtry
enddef

def GetDefaultRegister(): string
  var clipboard = &clipboard
  if clipboard ==# 'unnamedplus'
    return '+'
  elseif clipboard ==# 'unnamed'
    return '*'
  endif
  return '"'
enddef

def GetRegister(): string
  if has('nvim') && !reg_inited
    reg = ''
    reg_inited = true
  else
    reg = v:register != GetDefaultRegister() ? '"' .. v:register : ''
    reg_inited = true
  endif
  return reg
enddef

export def ParseMappings()
  for [mode, d] in items(cache)
    for k in keys(d)
      keymaps#mappings#Parse(k, d, mode)
    endfor
  endfor
enddef

export def Format(mapping: string): string
  var ret = mapping
  ret = substitute(ret, '\c<cr>$', '', '')
  ret = substitute(ret, '^:', '', '')
  ret = substitute(ret, '^\c<c-u>', '', '')
  return ret
enddef

export def Statusline(): string
  var key = '%#KeymapsTrigger# %{keymaps#Trigger()} %*'
  var name = '%#KeymapsName# %{keymaps#window#Name()} %*'
  return key .. name
enddef

export def Trigger(): string
  return keymaps_trigger
enddef

export def GetSep(): string
  return get(g:, 'keymaps_sep', '→')
enddef

defcompile
