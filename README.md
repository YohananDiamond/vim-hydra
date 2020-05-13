## vim-hydra plugin (experimental)

This plugin allows you to create hydras similar to abo-abo's Emacs plugin.
This is still a demo project.

![example](./example.gif)

### Installation

Using vim-plug

```vim
    Plug 'brenopacheco/vim-hydra',
```

Or use your preferred plugin manager.

### Quick intro

Create a dict with your hydra's configuration and call hydra#hydras#register(...).

```vim
let s:example_hydra =
            \ {
            \   'name':        'example',
            \   'title':       'Example hydra',
            \   'show':        'popup',
            \   'exit_key':    "q",
            \   'feed_key':    v:true,
            \   'foreign_key': v:true,
            \   'keymap': [
            \     {
            \       'name': 'Window',
            \       'keys': [
            \         ['s', 'split',                    'split'],
            \         ['v', 'vsplit',                   'vsplit'],
            \         ['d', 'close',                    'close'],
            \         ['o', 'only',                     'only'],
            \       ]
            \     },
            \     {
            \       'name': 'Move to',
            \       'keys': [
            \         ['h', "norm \<C-w>h", '←'],
            \         ['j', "norm \<C-w>j", '↓'],
            \         ['k', "norm \<C-w>k", '↑'],
            \         ['l', "norm \<C-w>l", '→'],
            \       ]
            \     },
            \     {
            \       'name': 'Buffers',
            \       'keys': [
            \         ['b', 'Buffers', "Buffers", 'interactive'],
            \         ['n', "bn",       "next"],
            \         ['p', "bp",       "prev"],
            \         ['e', "enew!",    "empty"],
            \       ]
            \     },
            \   ]
            \ }

silent call hydra#hydras#register(s:example_hydra)

nnoremap <Leader>w :Hydra example<CR>
```

Call the |:Hydra| command, which takes the hydra name as argument.

```vim
:Hydra myhydra
```

The name and title fields are required.

### Hydra options

Please take a look at the [help file][./doc/hydra.txt]
