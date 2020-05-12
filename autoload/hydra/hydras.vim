" File: autoload/hydra/hydras.vim
" Author: brenopacheco
" Description: hydra definitions, functions and registering
" Last Modified: 2020-04-12 

" TODO: fix whats supposed to be util functions and public functions for hydra "
" TODO: the API doesn't need this, or does it? "
" TODO: make floating window on top of other floats
" TODO: visual cmds and plug commands (-range) "

" if exists('s:hydras_loaded') 
"     finish
" endif
" let s:hydras_loaded = 1

"--------------------------------------------------------------
" API: registering, getting and opening hydras
"--------------------------------------------------------------

let s:this = { 'registered': {}, 'active': "", 'last': "" }

command! -nargs=1 Hydra call hydra#hydras#open(<q-args>)
command! -range -nargs=1 VHydra call hydra#hydras#open(<q-args>, visualmode())

"-------------------------------
" Register hydra. 
" Verifies if name is supplied.
" Verifies if hydra is already defined.
"-------------------------------
function! hydra#hydras#register(hydra) abort
    try
        let l:name = a:hydra.name  
        if type(s:this.get(name)) == 4
            throw "hydra with name " . a:hydra.name . " already defined."
        endif
        call s:this.register(a:hydra)
        echo "Hydra " a:hydra.name " registered successfully."
    catch /.*/
        echo "Unable to register hydra: " . v:exception
    endtry
endfunction

"-------------------------------
" Get last active hydra
"-------------------------------
function! hydra#hydras#last() abort
   return s:this.last
endfunction

"-------------------------------
" Get current active hydra name
"-------------------------------
function! hydra#hydras#active() abort
   return s:this.active
endfunction

"-------------------------------
" Get hydra by name.
"-------------------------------
function! hydra#hydras#get(name) abort
    return s:this.get(a:name) 
endfunction

"-------------------------------
" Open hydra by name
"-------------------------------
function! hydra#hydras#open(name, ...) abort
    " TODO: accept a range and save it. "
    " allow users to run commands on ranges
   call s:this.open(a:name) 
endfunction

"-------------------------------
" List registered hydras
"-------------------------------
function! hydra#hydras#list() abort
   return s:this.list() 
endfunction

"-------------------------------
" return a registered hydra by name. 
" v:false if not found
"-------------------------------
function! s:this.get(name) dict
    try
        return s:this.registered[a:name]
    catch /.*/
        return v:false 
    endtry
endfunction

function! s:this.list() dict
   return keys(s:this.registered) 
endfunction

function! s:this.register(hydra) dict
    let l:newHydra = s:Hydra.new(a:hydra) 
    let s:this.registered[a:hydra.name] = newHydra 
endfunction

function! s:this.open(name) dict
   let l:hydra = self.get(a:name) 
   if type(l:hydra) == type({})
       try
           call hydra.open()
       catch /.*/
           echo "Unable to open hydra: " . v:exception
       endtry
    else 
        echo "Undefined hydra."
        return v:false
    endif
endfunction


"--------------------------------------------------------------
" Hydra: configuration global values
"--------------------------------------------------------------

let g:hydra_defaults = {
            \ "show":        'popup',
            \ "foreign_key": v:true,
            \ 'feed_key':    v:false,
            \ "exit_key":    "q",
            \ }

let s:Hydra = {
            \ 'name':        '',
            \ 'title':       '',
            \ 'show':        g:hydra_defaults.show,
            \ 'exit_key':    g:hydra_defaults.exit_key,
            \ 'foreign_key': g:hydra_defaults.foreign_key,
            \ 'feed_key':    g:hydra_defaults.feed_key,
            \ 'keymap':      [],
            \ 'buffer':      v:false,
            \ 'focused':     v:false,
            \ 'drawing':     [],
            \ }

"-------------------------------
" Create new Hydra. 
" Merges hydra passed as argument.
" Register title if none,
" adds exit key to keymap
"-------------------------------
function! s:Hydra.new(hydra) dict
    let l:newHydra = deepcopy(self)
    call extend(newHydra, a:hydra, "force")
    if strwidth(newHydra.title) == 0
        let newHydra.title = newHydra.name 
    endif
    let newHydra.keymap = hydra#keymap#new(newHydra.keymap)
    call newHydra.keymap.addExitKey(newHydra.exit_key)
    return newHydra
endfunction

"-------------------------------
" Closes hydra window freeing buffer
"-------------------------------
function! s:Hydra.exit() dict
    let l:bufnr = bufnr(self.buffer)
    if bufexists(bufnr) | silent! exec 'bw! ' . bufnr | endif
    let s:this.active = ""
    let s:this.last = self.name
endfunction

function! s:Hydra.draw() abort
   call deletebufline(self.buffer, 0, "$")
   for l:line in self.drawing
       call appendbufline(self.buffer, line('$') - 1, line)
   endfor
   call deletebufline(self.buffer, "$")
endfunction
 
function! s:Hydra.makeDrawing() dict

    let l:MaxStrlen = { list -> max(map(copy(list), 'strwidth(v:val)')) }

    let l:group_boxes = []
    let l:groups = self.keymap.getGroups()
    for l:group in groups
        let l:group_keys = self.keymap.getGroupKeys(group)
        let l:group_box = []
        call add(group_box, " " . group . " ")
        call add(group_box, "")
        for l:key in group_keys
            call add(group_box, " [" . key . "] " . self.keymap.keyDesc(key) . " ")
        endfor
        let l:width = MaxStrlen(group_box)
        let group_box[1] = " " . repeat("-", width -2) . " "
        let l:idx = 0
        for l:line in group_box
            let group_box[idx] = line . repeat(" ", width - strwidth(line))
            let idx = idx + 1
        endfor
        " echo "group box:\n"
        " echo group_box
        call add(group_boxes, group_box)
    endfor

    let l:group_box = g:Reduce(group_boxes, g:Merge)
    " echo "\njoined:"
    " echo join(group_box, "\n")
    let l:width = strwidth(group_box[0])
    let l:height = len(group_box)
    let l:laterals = map(range(height), '"┃"')
    let l:body = g:Merge(g:Merge(laterals, group_box), laterals)
    " echo join(body, "\n")
    let l:header = "┏" . self.title . repeat("━", width - strwidth(self.title)) . "┓" 
    let l:footer = "┗" . repeat("━", width) . "┛"

    let l:drawing = []
    call add(drawing, header)
    let drawing = drawing + body
    " call add(drawing, body)
    call add(drawing, footer)
    let self.drawing = drawing
endfunction

"-------------------------------
" Opens a window for the hydra,
" give it a buffer, draws and 
" handle keypresses
"-------------------------------
function! s:Hydra.open() dict
   call self.config()
   call self.makeDrawing()
   call self.window()
   call self.draw()
   call self.loop()
endfunction

function s:Hydra.window() abort
    let l:height = self.height()
    let l:width = self.width()
    if self.show == "popup"
        let l:opts = {
              \ 'relative': 'editor',
              \ 'row': &lines - height - 6,
              \ 'col': float2nr((&columns - width) / 2),
              \ 'width': width,
              \ 'height': height 
          \ }
        call nvim_open_win(self.buffer, v:true, opts)
    elseif self.show == "split"
        exec 'noautocmd botright '. height . 'split ' . bufname(self.buffer)
    else 
        throw "Invalid show method."
    endif
    setlocal buftype=nofile bufhidden=wipe nobuflisted noswapfile 
    setlocal nospell nonu nornu nocul nowrap nolist 
endfunction

"-------------------------------
" Position cursor on focused window
"-------------------------------
function! s:Hydra.focus() dict
    call win_gotoid(self.focused)
endfunction

"-------------------------------
" Get a new buffer for the hydra
"-------------------------------
function! s:Hydra.config() dict
   let s:this.active = self.name
   let l:bufname =  "___" . self.name . "-hydra___"
   try
       silent exec 'bw! ' . bufnr(bufname)
   catch /.*/
   endtry
   let self.buffer = bufadd(bufname) 
   let self.focused = win_getid()
endfunction

"-------------------------------
" Refresh window by reopening if
" it was closed somewhere
"-------------------------------
function! s:Hydra.refresh() dict
    if index(tabpagebuflist(), self.buffer) == -1
       call self.open() 
    endif
endfunction

"----------------------------------------------------------
" waits for key input and returns pressed key 
"----------------------------------------------------------
function! s:Hydra.handle() dict
    while v:true
       call self.focus()
       redraw!
       if getchar(1)
           return self.getchar()
       endif
       sleep 50ms
    endw
endfunction


"-------------------------------
" Loop. wair for keypresses.
" " TODO:  refactor this method
"-------------------------------
function! s:Hydra.loop() dict
    try
        while v:true
            let l:key = self.handle()
            if self.keymap.hasKey(key)
                let l:cmd = self.keymap.keyCmd(key)
                if self.keymap.keyExit(key)
                    call self.exit()
                    execute cmd
                    return
                elseif self.keymap.keyIteractive(key)
                    echo "iteractive"
                    call self.exit()
                    execute cmd
                    call s:wrap(cmd)
                    return
                else
                    execute cmd
                    call self.update()
                endif
            else
                if !self.foreign_key 
                    throw "Invalid key."
                endif
                if self.feed_key
                    exec "norm " . key
                endif
            endif
        endwhile
    catch /.*/
       call self.exit()
       echo "Error: " . v:exception 
    endtry
endfunction

"-------------------------------
" Get char fix behavior
"-------------------------------
function s:Hydra.getchar() dict
   let l:ret = getchar()
   return (type(ret) == type(0) ? nr2char(ret) : ret)
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


"-------------------------------
" Updates focus and reopens hydra
" if it is not visible
"-------------------------------
function! s:Hydra.update()
    let self.focused = win_getid()
    if index(tabpagebuflist(), self.buffer) < 0 
       call self.config()
       call self.window()
       call self.draw()
    endif
    call self.focus()
endfunction

function! s:wrap(cmd) abort
    au WinClosed <buffer> call feedkeys("v:call hydra#hydras#open(hydra#hydras#last())\<cr>")
endfunction


"---------------------------------------------------------------------------------------------
" Helper functions
"---------------------------------------------------------------------------------------------
let g:Reduce = 
            \ { list, fun -> 
            \    eval(
            \             substitute(
            \                 repeat('fun(', len(list[:-2])) . string(list[0])
            \                 . join(map(copy(list[1:]), '"," . string(v:val) . ")"'), '')
            \                 , '(,', '(', ''
            \             )
            \    )
            \ }

let g:Merge = { list1, list2 -> 
        \ map(
            \ range(
                \ max( [ len(list1), len(list2) ])),
            \ '(v:key >= len(list1) ? repeat(" ", strwidth(list1[0])) : list1[v:key]) 
            \ . (v:key >= len(list2) ? repeat(" ", strwidth(list2[0])) : list2[v:key]) ')
    \ }
