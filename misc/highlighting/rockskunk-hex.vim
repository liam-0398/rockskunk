" Optional: exact hex colors matching the rockskunk VS Code theme,
" instead of linking to your colorscheme's standard groups.
"
" Not loaded automatically. To use it every time you open a .rsk file,
" add this to your vimrc (adjust the path):
"
"   autocmd FileType rockskunk source ~/.vim/rockskunk-hex.vim
"
" Or just :source it by hand whenever you want it for the current buffer.
" Requires termguicolors (or a GUI Vim) to actually show the guifg values
" in a terminal -- add `set termguicolors` to your vimrc if you don't
" have it already.

hi rockskunkComment          guifg=#6A9955 ctermfg=65

hi rockskunkString           guifg=#CE9178 ctermfg=173
hi rockskunkEscape           guifg=#D7BA7D ctermfg=179
hi rockskunkInvalidEscape    guifg=#F44747 ctermfg=203

hi rockskunkInteger          guifg=#B5CEA8 ctermfg=150
hi rockskunkFloat            guifg=#B5CEA8 ctermfg=150
hi rockskunkInvalidFloat     guifg=#F44747 ctermfg=203

hi rockskunkFuncKeyword      guifg=#C586C0 ctermfg=176
hi rockskunkBlockKeyword     guifg=#C586C0 ctermfg=176
hi rockskunkRecordKeyword    guifg=#C586C0 ctermfg=176
hi rockskunkTypeTag          guifg=#C586C0 ctermfg=176
hi rockskunkRecordName       guifg=#4EC9B0 ctermfg=79
hi rockskunkRepeat           guifg=#569CD6 ctermfg=75
hi rockskunkConditional      guifg=#569CD6 ctermfg=75
hi rockskunkStatement        guifg=#569CD6 ctermfg=75
hi rockskunkReserved         guifg=#569CD6 ctermfg=75
hi rockskunkInclude          guifg=#DCDCAA ctermfg=187

hi rockskunkLogical          guifg=#569CD6 ctermfg=75
hi rockskunkBitwiseWord      guifg=#569CD6 ctermfg=75

hi rockskunkReturnVar        guifg=#569CD6 ctermfg=75 gui=italic cterm=italic

hi rockskunkFuncName         guifg=#DCDCAA ctermfg=187
hi rockskunkFuncCall         guifg=#DCDCAA ctermfg=187
hi rockskunkBuiltin          guifg=#DCDCAA ctermfg=187
hi rockskunkVectorBuiltin    guifg=#4EC9B0 ctermfg=79

hi rockskunkVariable         guifg=#9CDCFE ctermfg=117
hi rockskunkMember           guifg=#9CDCFE ctermfg=117
hi rockskunkAccessorDot      guifg=#D4D4D4 ctermfg=253

hi rockskunkTypeSep          guifg=#D4D4D4 ctermfg=253

hi rockskunkAssign           guifg=#D4D4D4 ctermfg=253
hi rockskunkAssignStatic     guifg=#D4D4D4 ctermfg=253
hi rockskunkAssignCompound   guifg=#D4D4D4 ctermfg=253
hi rockskunkAssignVector     guifg=#569CD6 ctermfg=75

hi rockskunkVectorOp         guifg=#569CD6 ctermfg=75
hi rockskunkVectorFma        guifg=#569CD6 ctermfg=75
hi rockskunkIncrement        guifg=#569CD6 ctermfg=75

hi rockskunkAddressOf        guifg=#569CD6 ctermfg=75
hi rockskunkIndexByte        guifg=#569CD6 ctermfg=75
hi rockskunkBitwise          guifg=#569CD6 ctermfg=75
hi rockskunkCompare          guifg=#D4D4D4 ctermfg=253
hi rockskunkArith            guifg=#D4D4D4 ctermfg=253

hi rockskunkBlockBegin       guifg=#808080 ctermfg=244
hi rockskunkBlockEnd         guifg=#808080 ctermfg=244
hi rockskunkRecordBegin      guifg=#808080 ctermfg=244
hi rockskunkIndexDelim       guifg=#569CD6 ctermfg=75
hi rockskunkBlockPunct       guifg=#D4D4D4 ctermfg=253
hi rockskunkBracketPunct     guifg=#D4D4D4 ctermfg=253
hi rockskunkParenPunct       guifg=#D4D4D4 ctermfg=253
hi rockskunkSeparator        guifg=#D4D4D4 ctermfg=253
