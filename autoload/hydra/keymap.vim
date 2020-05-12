" File: autoload/vim-hydra/keymap.vim
" Author: brenopacheco
" Description: keymap used by hydra
" Last Modified: 2020-04-12 

"---------------------------------------------------------------------------------------------
" API: new(keymap)
" Returns a new Keymap object based on 
" argument keymap with following syntax:
" keymap = [
"   { 'name': "groupA", 
"     'keys': [ 
"        [ "a", "desc", exit_bool, hide_bool, iteractive_bool  ],  
"        [ "b", "desc", exit_bool, hide_bool, iteractive_bool  ], 
"        ... 
"   }, 
"   { 'name': "groupB" 
"   ... 
"   }
"   ...
" ]
" exit and hide are optional and are set to defaults.
"---------------------------------------------------------------------------------------------

function! hydra#keymap#new(keymap) abort
   let l:newKeymap = deepcopy(s:Keymap) 
   call newKeymap.init(a:keymap)
   return newKeymap
endfunction

"---------------------------------------------------------------------------------------------
" Keymap: definition and functions
"---------------------------------------------------------------------------------------------

let s:Keymap = {
            \ 'groups': [],
            \ 'groupKeys': {},
            \ 'keys': {},
            \ }


function! s:Keymap.getGroups() dict
   return self.groups 
endfunction

"-------------------------------
" Returns visible keys from a group
"-------------------------------
function! s:Keymap.getGroupKeys(group) dict
   return filter(self.groupKeys[a:group], { key, val -> self.keyHide(val) == v:false } )
endfunction

function! s:Keymap.hasKey(key) dict
    return has_key(self.keys, a:key)
endfunction

function! s:Keymap.getKeyList() dict
   return keys(self.keys) 
endfunction

function! s:Keymap.keyCmd(key) dict
    return self.keys[a:key].cmd
endfunction

function! s:Keymap.keyDesc(key) dict
    return self.keys[a:key].desc
endfunction

function! s:Keymap.keyExit(key) dict
    return self.keys[a:key].exit
endfunction

function! s:Keymap.keyIteractive(key) dict
    return self.keys[a:key].iteractive
endfunction

function! s:Keymap.keyHide(key) dict
    return self.keys[a:key].hide    
endfunction

function! s:Keymap.addExitKey(key) abort
    let l:exit_key = {}
    let self.keys[a:key] = { 'cmd': '', 'exit': v:true }
endfunction

"---------------------------------------------------------------------------------------------
" Init: used to instantiate keymap from keymap list definition
"---------------------------------------------------------------------------------------------
function! s:Keymap.init(keymap) dict
    for l:group in a:keymap  
        let l:groupKeys = []
        call add(self.groups, group.name)
        for l:keydef in group.keys
            try
                let l:newKey = {}
                let l:key = keydef[0]
                let newKey.cmd = keydef[1]
                let newKey.desc = keydef[2]
                let newKey.exit = index(keydef, 'exit') < 0 ? v:false : v:true
                let newKey.hide = index(keydef, 'hide') < 0 ? v:false : v:true
                let newKey.iteractive = index(keydef, 'iteractive') < 0 ? v:false : v:true
                call add(groupKeys, key)
                let self.keys[key] = newKey
            catch /.*/
                continue
            endtry
        endfor
        let self.groupKeys[group.name] = groupKeys
    endfor
endfunction
