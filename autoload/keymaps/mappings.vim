vim9script

var TYPE = g:keymaps#TYPE

def StringToKeys(input: string): list<string>
  if match(input, '<.\+>') != -1
    var retlist: list<string> = []
    var si = 0
    var go = true
    while si < len(input)
      if go
        add(retlist, input[si])
      else
        retlist[-1] = retlist[-1] .. input[si]
      endif
      if input[si] ==? '<'
        go = false
      elseif input[si] ==? '>'
        go = true
      endif
      si += 1
    endwhile
    return retlist
  else
    return split(input, '\zs')
  endif
enddef

def ExecuteCmd(cmd: string): string
  if exists('*execute')
    return execute(cmd)
  else
    var output: string
    redir => output
    silent! execute cmd
    redir END
    return output
  endif
enddef

def GetRawMapInfo(key: string): list<string>
  return split(ExecuteCmd('map ' .. key), "\n")
enddef

export def Parse(key: string, dict: dict<any>, visual: string)
  var k = key ==? ' ' ? '<Space>' : (key ==? '<C-I>' ? '<Tab>' : key)
  var dk = key ==? '<Space>' ? ' ' : (key ==? '<C-I>' ? '<Tab>' : key)
  if !has_key(dict, dk)
    dict[dk] = {}
  endif
  var vis = visual ==# 'v'

  var lines = GetRawMapInfo(k)
  if k ==# '<Tab>'
    extend(lines, GetRawMapInfo('<C-I>'))
  endif
  if k[0 : 2] ==# '<M-' && !has('patch-8.2.0815')
    k = eval('"' .. '\' .. k .. '"')
  endif
  for line in lines
    var raw_sp = split(line[3 : ])
    var mapd = maparg(raw_sp[0], line[0], 0, 1)
    if empty(mapd) || mapd.lhs =~? '<Plug>.*' || mapd.lhs =~? '<SNR>.*'
      continue
    endif
    if has_key(mapd, 'desc')
      mapd.rhs = mapd.desc
      remove(mapd, 'desc')
    endif

    mapd['display'] = call(g:KeymapsFormatFunc, [mapd.rhs])

    mapd.lhs = substitute(mapd.lhs, k, '', '')
    if mapd.lhs ==? '<Space>' && mapcheck('<leader><space>', 'n') =~ 'easymotion'
      continue
    endif
    mapd.lhs = substitute(mapd.lhs, '<Space>', ' ', 'g')
    mapd.lhs = substitute(mapd.lhs, '<C-I>', '<Tab>', 'g')
    mapd.rhs = substitute(mapd.rhs, '<SID>', '<SNR>' .. mapd['sid'] .. '_', 'g')

    if mapd.expr
      try
        mapd.rhs = eval(mapd.rhs)
      catch /.*/
      endtry
    endif

    if mapd.lhs !=# '' && mapd['display'] !~# 'Keymaps.*'
      if match(mapd.mode, vis ? '[vx ]' : '[n ]') >= 0
        mapd.lhs = StringToKeys(mapd.lhs)
        AddMapToDict(mapd, 0, dict[dk])
      endif
    endif
  endfor
enddef

def Escape(mapping: dict<any>): string
  var feedkeyargs = mapping.noremap ? 'nt' : 'mt'
  var rhs = substitute(mapping.rhs, '\c<Leader>', get(g:, 'mapleader', '\'), 'g')
  rhs = substitute(rhs, '\c<LocalLeader>', get(g:, 'maplocalleader', '\'), 'g')
  rhs = substitute(rhs, '\', '\\\\', 'g')
  rhs = substitute(rhs, '<\([^<>]*\)>', '\\<\1>', 'g')
  rhs = substitute(rhs, '"', '\\"', 'g')
  rhs = 'call feedkeys("' .. rhs .. '", "' .. feedkeyargs .. '")'
  return rhs
enddef

def AddMapToDict(map: dict<any>, level: number, dict: dict<any>)

  var cmd = Escape(map)

  if len(map.lhs) > level + 1
    var curkey = map.lhs[level]
    var nlevel = level + 1

    if !has_key(dict, curkey)
      dict[curkey] = {name: g:keymaps_default_group_name}
    elseif type(dict[curkey]) == TYPE.list
      if g:keymaps_flatten
        curkey = join(map.lhs[level : ], '')
        nlevel = level
        if !has_key(dict, curkey)
          dict[curkey] = [cmd, map['display']]
        endif
      else
        curkey = curkey .. 'm'
        if !has_key(dict, curkey)
          dict[curkey] = {name: g:keymaps_default_group_name}
        endif
      endif
    endif
    if type(dict[curkey]) == TYPE.dict
      AddMapToDict(map, nlevel, dict[curkey])
    endif
  else
    var lhs_at_level = map.lhs[level]

    if !has_key(dict, lhs_at_level)
      dict[lhs_at_level] = [cmd, map['display']]
    elseif type(dict[lhs_at_level]) == TYPE.dict && g:keymaps_flatten
      var childmap = Flatten(dict[lhs_at_level], lhs_at_level)
      for it in keys(childmap)
        dict[it] = childmap[it]
      endfor
      dict[lhs_at_level] = [cmd, map['display']]
    endif
  endif
enddef

def Flatten(dict: dict<any>, str: string): dict<any>
  var flat: dict<any> = {}
  for kv in keys(dict)
    var ty = type(dict[kv])
    if ty == TYPE.list
      var toret: dict<any> = {}
      toret[str .. kv] = dict[kv]
      return toret
    elseif ty == TYPE.dict
      extend(flat, Flatten(dict[kv], str .. kv))
    endif
  endfor
  return flat
enddef

defcompile
