" File: autoload/hydra/hydras.vim
" Author: brenopacheco
" Description: hydra definitions, functions and registering
" Last Modified: 2020-04-12 

" TODO: add more position functions
" TODO: add documentation for interactive "
" TODO: make floating window always on top of other floats
" TODO: visual cmds and plug commands (-range) "
" TODO: TESTS "

if exists('s:hydras_loaded') 
    finish
endif
let s:hydras_loaded = 1

command! -nargs=1 Hydra call hydra#hydras#open(<q-args>)
command! -range -nargs=1 VHydra call hydra#hydras#open(<q-args>, visualmode())

"--------------------------------------------------------------
" API: public api for creating and getting hydras
"--------------------------------------------------------------

let s:hydras = { 'registered': {}, 'active': "", 'last': "" }

"-------------------------------
" Register hydra. 
"-------------------------------
function! hydra#hydras#register(hydra) abort
    try
        let l:name = a:hydra.name  
        if has_key(s:hydras.registered, name)
            throw "hydra with name " . name . " already defined."
        endif
        let s:hydras.registered[name] = s:new_hydra(a:hydra)  
        echo "Hydra " a:hydra.name " registered successfully."
    catch /.*/
        echo "Unable to register hydra: " . v:exception
    endtry
endfunction

"-------------------------------
" Get last active hydra
"-------------------------------
function! hydra#hydras#last() abort
   return s:hydras.last
endfunction

"-------------------------------
" Get current active hydra name
"-------------------------------
function! hydra#hydras#active() abort
   return s:hydras.active
endfunction

"-------------------------------
" Get hydra by name.
"-------------------------------
function! hydra#hydras#get(name) abort
    try
        return s:hydras.registered[a:name]
    catch /.*/
        return v:false 
    endtry
endfunction

"-------------------------------
" List registered hydras
"-------------------------------
function! hydra#hydras#list() abort
   return keys(s:hydras.registered) 
endfunction

"-------------------------------
" Open hydra by name
"-------------------------------
function! hydra#hydras#open(name, ...) abort
    if has_key(s:hydras.registered, a:name)
        try
            call s:hydras.registered[a:name].build()
        catch /.*/
            echo "Unable to open hydra: " . v:exception
        endtry
    else 
        echo "Undefined hydra."
        return v:false
    endif
endfunction
 
function! hydra#hydras#reset() abort
    let s:hydras.registered = {}
endfunction

"--------------------------------------------------------------
" Hydra: configuration global values
"--------------------------------------------------------------

let g:hydra_defaults = {
            \ 'show':           'popup',
            \ 'exception':      v:true,
            \ 'foreign_key':    v:true,
            \ 'feed_key':       v:false,
            \ 'single_command': v:false,
            \ 'exit_key':       "q",
            \ 'position':       's:lower_center',
            \ }

"---------------------------------------------------------------------------------------------
" Hydra object model and bound functions. 
"---------------------------------------------------------------------------------------------

let s:Hydra = {
            \ 'name':           '',
            \ 'title':          '',
            \ 'show':           g:hydra_defaults.show,
            \ 'exit_key':       g:hydra_defaults.exit_key,
            \ 'foreign_key':    g:hydra_defaults.foreign_key,
            \ 'feed_key':       g:hydra_defaults.feed_key,
            \ 'single_command': g:hydra_defaults.single_command,
            \ 'exception':      g:hydra_defaults.exception,
            \ 'position':       g:hydra_defaults.position,
            \ 'keymap':         [],
            \ 'buffer':         v:false,
            \ 'focus':          v:false,
            \ 'drawing':        [],
            \ }

let s:Keymap = {
            \ 'groups': [],
            \ 'group_keys': {},
            \ 'keys': {},
            \ }

"-------------------------------
" Opens the hydra
"-------------------------------
function! s:Hydra.build() dict
   call s:config_buffer(self)
   call s:make_drawing(self)
   call s:make_window(self)
   call s:draw_window(self)
   call s:loop(self)
endfunction

"-------------------------------
" Closes hydra window freeing buffer
"-------------------------------
function! s:Hydra.exit() dict
    let l:bufnr = bufnr(self.buffer)
    if bufexists(bufnr) | silent! exec 'bw! ' . bufnr | endif
    let s:hydras.active = ""
    let s:hydras.last = self.name
endfunction

"-------------------------------
" Height function
"-------------------------------
function! s:Hydra.height() dict
    return len(self.drawing)
endfunction

"-------------------------------
" Width function
"-------------------------------
function! s:Hydra.width() dict
    return strwidth(self.drawing[0])
endfunction

"---------------------------------------------------------------------------------------------
" Internal functions
"---------------------------------------------------------------------------------------------

"-------------------------------
" Create new Hydra. 
" Merges hydra passed as argument.
" Register title if none,
" adds exit key to keymap
"-------------------------------
function! s:new_hydra(hydra_definition) abort
    let l:new_hydra = deepcopy(s:Hydra)
    call extend(new_hydra, a:hydra_definition, "force")
    if strwidth(new_hydra.title) == 0
        let new_hydra.title = new_hydra.name 
    endif
    let new_hydra.keymap = s:new_keymap(new_hydra.keymap)
    let new_hydra.keymap.keys[new_hydra.exit_key] = 
                \ { 'cmd': '', 'exit': v:true, 'hide': v:true }
    return new_hydra
endfunction

"--------------------------------------------------
" builds new keymap based on keymap list definition 
"--------------------------------------------------
function! s:new_keymap(keymap_definition) abort
    let l:new_keymap = deepcopy(s:Keymap) 
    for l:group in a:keymap_definition  
        let l:group_keys = []
        call add(new_keymap.groups, group.name)
        for l:keydef in group.keys
            try
                let l:new_key = {}
                let l:key = keydef[0]
                let new_key.cmd = keydef[1]
                let new_key.desc = keydef[2]
                let new_key.exit = index(keydef, 'exit') < 0 ? v:false : v:true
                let new_key.hide = index(keydef, 'hide') < 0 ? v:false : v:true
                let new_key.interactive = index(keydef, 'interactive') < 0 ? v:false : v:true
                call add(group_keys, key)
                let new_keymap.keys[key] = new_key
            catch /.*/
                continue
            endtry
        endfor
        let new_keymap.group_keys[group.name] = group_keys
    endfor
    return new_keymap
endfunction

"-------------------------------
" Get a new buffer for the hydra
"-------------------------------
function! s:config_buffer(hydra) abort
   let s:hydras.active = a:hydra.name
   let l:bufname =  "___" . a:hydra.name . "-hydra___"
   if bufexists(bufname) 
        silent exec 'bw! ' . bufnr(bufname)
   endif 
   let a:hydra.buffer = bufadd(bufname) 
   let a:hydra.focus = win_getid()
endfunction

"-------------------------------
" Create the hydra's drawing
"-------------------------------
function! s:make_drawing(hydra) abort
    let l:MaxStrlen = { list -> max(map(copy(list), 'strwidth(v:val)')) }
    let l:group_boxes = []
    let l:groups = a:hydra.keymap.groups
    for l:group in groups
        let l:group_keys = filter(copy(a:hydra.keymap.group_keys[group]), 
                    \ { _, key -> a:hydra.keymap.keys[key].hide == v:false })
        let l:group_box = []
        call add(group_box, " " . group . " ")
        call add(group_box, "")
        for l:key in group_keys
            call add(group_box, " [" . key . "] " . a:hydra.keymap.keys[key].desc . " ")
        endfor
        let l:width = MaxStrlen(group_box)
        let group_box[1] = " " . repeat("-", width -2) . " "
        let l:idx = 0
        for l:line in group_box
            let group_box[idx] = line . repeat(" ", width - strwidth(line))
            let idx = idx + 1
        endfor
        call add(group_boxes, group_box)
    endfor
    let l:group_box = s:Reduce(group_boxes, s:Merge)
    let l:width = strwidth(group_box[0])
    let l:height = len(group_box)
    let l:laterals = map(range(height), '"┃"')
    let l:body = s:Merge(s:Merge(laterals, group_box), laterals)
    let l:header = "┏" . a:hydra.title . repeat("━", width - strwidth(a:hydra.title)) . "┓" 
    let l:footer = "┗" . repeat("━", width) . "┛"
    let l:drawing = []
    call add(drawing, header)
    let drawing = drawing + body
    call add(drawing, footer)
    let a:hydra.drawing = drawing
endfunction

"-------------------------------
" Create the hydra's window
"-------------------------------
function s:make_window(hydra) abort
    let l:height = a:hydra.height()
    let l:width = a:hydra.width()
    if a:hydra.show == "popup"
        let l:Position = function(a:hydra.position)
        let l:pos = l:Position(height, width)
        let l:opts = {
              \ 'relative': 'editor',
              \ 'row': pos.row,
              \ 'col': pos.col,
              \ 'width': width,
              \ 'height': height 
          \ }
        call nvim_open_win(a:hydra.buffer, v:true, opts)
    elseif a:hydra.show == "split"
        exec 'noautocmd botright '. height . 'split ' . bufname(a:hydra.buffer)
    elseif a:hydra.show == "none"

    else
        throw "Invalid show method."
    endif
    setlocal buftype=nofile bufhidden=wipe nobuflisted noswapfile 
    setlocal nospell nonu nornu nocul nowrap nolist scrolloff=999
endfunction

"-------------------------------
" Draws drawing in hydra's window
"-------------------------------
function! s:draw_window(hydra) abort
   call deletebufline(a:hydra.buffer, 0, "$")
   for l:line in a:hydra.drawing
       call appendbufline(a:hydra.buffer, line('$') - 1, line)
   endfor
   call deletebufline(a:hydra.buffer, "$")
endfunction
 
"-------------------------------
" Loop: wait for keypresses and parses it
" " TODO:  reconstruct method
"-------------------------------
function! s:loop(hydra) abort
    try
        while v:true
            let l:key = s:handle_keypress(a:hydra)
            if has_key(a:hydra.keymap.keys, key)
                let l:cmd = a:hydra.keymap.keys[key].cmd
                if a:hydra.keymap.keys[key].exit
                    call a:hydra.exit()
                    execute cmd
                    return
                elseif a:hydra.keymap.keys[key].interactive
                    " echo "interactive"
                    call a:hydra.exit()
                    execute cmd
                    call s:wrap_interactive()
                    return
                else
                    if a:hydra.exception
                       try
                         execute cmd
                       catch /.*/
                       endtry 
                    else
                        execute cmd
                    endif
                    call s:refresh_window(a:hydra)
                endif
            else
                if !a:hydra.foreign_key 
                    throw "Invalid key."
                endif
                if a:hydra.feed_key
                    exec "norm " . key
                endif
            endif

            if a:hydra.single_command
                call a:hydra.exit()
            endif
        endwhile
    catch /.*/
       call a:hydra.exit()
       echo "Error: " . v:exception 
    endtry
endfunction

"----------------------------------------------------------
" waits for key input and returns pressed key 
"----------------------------------------------------------
function! s:handle_keypress(hydra) abort
    while v:true
       call s:reposition_cursor(a:hydra)
       redraw!
       if getchar(1)
           return s:scan_char()
       endif
       sleep 50ms
    endw
endfunction

"-------------------------------
" Get char fix behavior
"-------------------------------
function s:scan_char() abort
   let l:ret = getchar()
   return (type(ret) == type(0) ? nr2char(ret) : ret)
endfunction

"-------------------------------
" Reposition cursor on focus window
"-------------------------------
function! s:reposition_cursor(hydra) abort
    call win_gotoid(a:hydra.focus)
endfunction

"-------------------------------
" Updates focus and reopens hydra
" if it is not visible
"-------------------------------
function! s:refresh_window(hydra)
    let a:hydra.focus = win_getid()
    if index(tabpagebuflist(), a:hydra.buffer) < 0 
       call s:config_buffer(a:hydra)
       call s:make_window(a:hydra)
       call s:draw_window(a:hydra)
    endif
    call s:reposition_cursor(a:hydra)
endfunction

"-------------------------------
" wraps command when interactive. 
" run after running the command itsel is run.
" reopens the hydra when cmd is finished (winclosed)
"-------------------------------
function! s:wrap_interactive() abort
    au WinClosed <buffer> call feedkeys("v:call hydra#hydras#open(hydra#hydras#last())\<cr>")
endfunction

"-------------------------------
" Default position functions
" " TODO: add other functions "
"-------------------------------
function s:lower_center(height, width) abort
    let l:pos = {}
    let l:pos.row = &lines - a:height - 6
    let l:pos.col = float2nr((&columns - a:width) / 2)
    return pos
endfunction
 
function s:bottom_right(height, width) abort
    let l:pos = {}
    let l:pos.row = &lines - a:height
    let l:pos.col = &columns - a:width
    return pos
endfunction


"-------------------------------
" Similar to js' reduce. Loop through list
" applying fun(acc, list[i])
"-------------------------------
let s:Reduce = 
            \ { list, fun -> 
            \    eval(
            \             substitute(
            \                 repeat('fun(', len(list[:-2])) . string(list[0])
            \                 . join(map(copy(list[1:]), '"," . string(v:val) . ")"'), '')
            \                 , '(,', '(', ''
            \             )
            \    )
            \ }

"-------------------------------
" Merges two string lists respecting str length. i.e:
" l1 = ["hello"]
" l2 = [" world", "wow"]
" [ "hello world", "     wow" ]
"-------------------------------
let s:Merge = { list1, list2 -> 
        \ map(
            \ range(
                \ max( [ len(list1), len(list2) ])),
            \ '(v:key >= len(list1) ? repeat(" ", strwidth(list1[0])) : list1[v:key]) 
            \ . (v:key >= len(list2) ? repeat(" ", strwidth(list2[0])) : list2[v:key]) ')
    \ }
