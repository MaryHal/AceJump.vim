" ACEJUMP
" Based on emacs' AceJump feature (http://www.emacswiki.org/emacs/AceJump).
" AceJump is based on these Vim plugins:
" EasyMotion (http://www.vim.org/scripts/script.php?script_id=3526)
" PreciseJump (http://www.vim.org/scripts/script.php?script_id=3437)
" All words on the screen starting with that letter will have
" their first letters replaced with a sequential character.
" Type this character to jump to that word.
"
" Adapted from https://gist.github.com/gfixler/3167301
" The author expressed that they do not want to maintain this script, so
" here this is.
"
" if exists('g:AceJump_Loaded') || &cp || version < 702
"     finish
" endif
" 
" let g:AceJump_Loaded = 1

let g:AceJump_chars = 'abcdefghijlkmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'
let g:AceJump_shade = 1

highlight AceJumpGrey ctermfg=darkgrey guifg=dimgrey
highlight AceJumpRed  ctermfg=darkred  guibg=NONE guifg=red gui=NONE

function! s:VarReset(var, ...)
    if ! exists('s:var_reset')
        let s:var_reset = {}
    endif

    let buf = bufname("")

    if a:0 == 0 && has_key(s:var_reset, a:var)
        " Reset var to original value
        call setbufvar(buf, a:var, s:var_reset[a:var])
    elseif a:0 == 1
        let new_value = a:0 == 1 ? a:1 : ''

        " Store original value
        let s:var_reset[a:var] = getbufvar(buf, a:var)

        " Set new var value
        call setbufvar(buf, a:var, new_value)
    endif
endfunction

function! s:message(message)
    echo 'AceJump: ' . a:message
endfunction

function! s:prompt(message)
    echohl Question
    echo a:message . ': '
    echohl None
endfunction

function! s:getInput()
    let char = getchar()

    " Escape Pressed?
    if char == 27
        redraw
        call s:message("Quit")
        return ''
    endif
    return nr2char(char)
endfunction

function! s:setCursor(position)
    call cursor(a:position[0], a:position[1])
endfunction

function! s:writeLines(lines, hlPos)
    undojoin

    for row in keys(a:lines)
        call setline(row, a:lines[row][0])
    endfor
endfunction

function! s:resetLines(lines)
    undojoin

    for row in keys(a:lines)
        call setline(row, a:lines[row][1])
    endfor
endfunction

function! s:buildPositionList(initial, pattern)
    " Row/col positions of words beginning with user's chosen letter
    let posList = []

    call s:setCursor([line('w0'), 1])
    while 1
        let position = searchpos(a:pattern, 'eW', line('w$'))
        if position == [0, 0]
            break
        endif

        " Skip folded lines
        if foldclosed(position[0]) != -1
            continue
        endif

        call add(posList, position)
    endwhile
    call s:setCursor(a:initial)

    return posList
endfunction

function! s:jumpToPosition(initialPos, posList)
    " Jump characters used to mark found words (user-editable)
    let chars = g:AceJump_chars

    if len(a:posList) > len(chars)
        " TODO add groupings here if more pos matches than jump characters
    endif

    " Trim found positions list; cannot be longer than jump markers list
    let pos = a:posList[:len(chars)]

    " Jumps list to pair jump characters with found word positions
    let jumps = {}
    let lines = {}
    let hlPos = []

    " Change each found position to a jump character
    for [r,c] in pos
        " Stop marking words if there are no more jump characters
        if len(chars) == 0
            break
        endif

        " 'Pop' the next jump character from the list
        let char = chars[0]
        let chars = chars[1:]

        if ! has_key(lines, r)
            let currentLine = getline(r)
            let lines[r] = [currentLine, currentLine]
        endif

        " Modify string
        if strlen(lines[r][0]) > 0
            let lines[r][0] = substitute(lines[r][0], '\%' . c . 'c.', char, '')
        else
            let lines[r][0] = char
        endif

        " Create jump character key to hold associated found word position
        let jumps[char] = [r, c]

        call add(hlPos, '\%' . r . 'l\%' . c . 'c')
    endfor
    call s:writeLines(lines, hlPos)

    " monotone all text in visible part of window (dark grey by default)
    if g:AceJump_shade
        let shadeHighlight = matchadd('AceJumpGrey', '\%'.line('w0').'l\_.*\%'.line('w$').'l', 1)
    endif

    " Change syntax on the jump characters to make it highly visible
    let jumpHighlight = matchadd('AceJumpRed', join(hlPos, '\|'), 1)

    " This redraw is critical to syntax highlighting
    redraw

    " Prompt user again for the jump character to jump to
    call s:prompt("AceJump to location")
    let jumpChar = s:getInput()

    " Clear lines
    call s:resetLines(lines)

    " Remove highlighting
    if g:AceJump_shade
        call matchdelete(shadeHighlight)
    endif
    call matchdelete(jumpHighlight)

    " Clear out the status line
    echo ""
    redraw

    " If the user input a proper jump character, jump to it
    if has_key(jumps, jumpChar)
        call s:setCursor(a:initialPos)
        mark `

        let position = jumps[jumpChar]
        call s:setCursor(position)
        " call s:message("Move to [" . position[0] . ", " . position[1] . "]")
    else
        " if it didn't work out, restore original cursor position
        call s:setCursor(a:initialPos)
    endif
endfunction

function! AceJumpWord()
    call s:prompt("AceJump to word starting with letter")
    let char = s:getInput()
    if empty(char)
        return
    endif
    let pattern = '\<' . char 
    call s:AceJump(pattern)
endfunction

function! AceJumpChar()
    call s:prompt("AceJump to character starting with letter")
    let char = s:getInput()
    if empty(char)
        return
    endif
    let pattern = '\C' . escape(char, '.$^~')
    call s:AceJump(pattern)
endfunction

function! AceJumpLine()
    let pattern = '^\(\w\|\s*\zs\|$\)'
    call s:AceJump(pattern)
endfunction

function! s:AceJump(pattern)
    " Reset properties
    call s:VarReset('&scrolloff', 0)
    call s:VarReset('&modified', 0)
    call s:VarReset('&modifiable', 1)
    call s:VarReset('&readonly', 0)
    call s:VarReset('&spell', 0)
    call s:VarReset('&virtualedit', '')

    " store some current values for restoring later
    let initial = [line('.'), col('.')]
    let origSearch = @/

    let pos = s:buildPositionList(initial, a:pattern)

    if len(pos) == 0
        " If there aren't any matches, just jump back and peace out.
        call s:setCursor(initial)
        call s:message("No Matches")
    elseif len(pos) == 1
        call s:setCursor(pos[0])
    else
        " Jump. ACE Jump.
        call s:jumpToPosition(initial, pos)
    endif

    " clean up the status line and return
    echo ""
    redraw

    " Restore Properties
    call s:VarReset('&scrolloff')
    call s:VarReset('&modified')
    call s:VarReset('&modifiable')
    call s:VarReset('&readonly')
    call s:VarReset('&spell')
    call s:VarReset('&virtualedit')

    return
endfunction

finish

