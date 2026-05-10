vim9script

export def Report(err_msg: string)
  echohl ErrorMsg
  echom '[keymaps] ' .. err_msg
  echohl None
enddef

export def UndefinedKey(key: string)
  echohl ErrorMsg
  echom '[keymaps] ' .. key .. ' is undefined'
  echohl None
enddef

export def MissingMapping()
  echohl ErrorMsg
  echom '[keymaps] Fail to execute, no such mapping'
  echohl None
enddef

defcompile
