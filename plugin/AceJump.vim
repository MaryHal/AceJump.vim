" ACEJUMP
" Based on emacs' AceJump feature (http://www.emacswiki.org/emacs/AceJump).
" AceJump based on these Vim plugins:
" EasyMotion (http://www.vim.org/scripts/script.php?script_id=3526)
" PreciseJump (http://www.vim.org/scripts/script.php?script_id=3437)
" All words on the screen starting with that letter will have
" their first letters replaced with a sequential character.
" Type this character to jump to that word.
"
" Adapted from https://gist.github.com/gfixler/3167301
" The author expressed that they do not want to maintain this script, so
" here this
" The author expressed that they do not want to maintain this script, so
" here this.

" if exists('g:AceJump_Loaded') || &cp || version < 702
"     finish
" endif
" 
" let g:AceJump_Loaded = 1

highlight AceJumpGrey ctermfg=darkgrey guifg=lightgrey
highlight AceJumpRed ctermfg=darkred guibg=NONE guifg=black gui=NONE

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

function! s:buildPositionList(method, letter)
    " row/col positions of words beginning with user's chosen letter
    let pos = []

    " monotone all text in visible part of window (dark grey by default)
    call matchadd('AceJumpGrey', '\%'.line('w0').'l\_.*\%'.line('w$').'l', 50)

    " loop over every line on the screen (just the visible lines)
    for row in range(line('w0'), line('w$'))
        " find all columns on this line where a word begins with our letter
        let col = 0
        let matchCol = match(' '.getline(row), '.\<'.a:letter, col)
        while matchCol != -1
            " store any matching row/col positions
            call add(pos, [row, matchCol])
            let col = matchCol + 1
            let matchCol = match(' '.getline(row), '.\<'.a:letter, col)
        endwhile
    endfor

    return pos
endfunction

function! s:getJumpLocation()
endfunction

function! s:jumpToPosition(initialPos, posList, origSearch)
    if len(a:posList) > 1
        " jump characters used to mark found words (user-editable)
        let chars = 'abcdefghijlkmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'

        if len(a:posList) > len(chars)
            " TODO add groupings here if more pos matches than jump characters
        endif

        " trim found positions list; cannot be longer than jump markers list
        let pos = a:posList[:len(chars)]

        " jumps list to pair jump characters with found word positions
        let jumps = {}
        " change each found word's first letter to a jump character
        for [r,c] in pos
            " stop marking words if there are no more jump characters
            if len(chars) == 0
                break
            endif

            " 'pop' the next jump character from the list
            let char = chars[0]
            let chars = chars[1:]

            " move cursor to the next found word
            call setpos('.', [0,r,c+1,0])

            " create jump character key to hold associated found word position
            let jumps[char] = [0,r,c+1,0]

            " replace first character in word with current jump character
            exe 'normal! r'.char

            " change syntax on the jump character to make it highly visible
            call matchadd('AceJumpRed', '\%'.r.'l\%'.(c+1).'c', 50)
        endfor
        call setpos('.', a:initialPos)

        " This redraw is critical to syntax highlighting
        redraw

        " prompt user again for the jump character to jump to
        call s:prompt("AceJump to location")
        let jumpChar = s:getInput()

        " get rid of our syntax search highlighting
        call clearmatches()

        " clear out the status line
        echo ""
        redraw

        " restore previous search register value
        let @/ = a:origSearch

        " undo all the jump character letter replacement
        normal! u

        " if the user input a proper jump character, jump to it
        if has_key(jumps, jumpChar)
            call setpos('.', jumps[jumpChar])
        else
            " if it didn't work out, restore original cursor position
            call setpos('.', a:initialPos)
        endif
    elseif len(a:posList) == 1
        " if we only found one match, just jump to it without prompting
        let [r,c] = a:posList[0]
        call setpos('.', [0,r,c+1,0])
    elseif len(a:posList) == 0
        " no matches; set position back to start
        call setpos('.', a:initialPos)
    endif

    " turn off all search highlighting
    call clearmatches()
endfunction

function! AceJump()
    " store some current values for restoring later
    let initial = getpos('.')
    let origSearch = @/

    " prompt for and capture user's search character
    call s:prompt("AceJump to words starting with letter")
    let letter = s:getInput()

    " redraws here and there to get past 'more' prompts
    " redraw

    let pos = s:buildPositionList(1, letter)
    call s:jumpToPosition(initial, pos, origSearch)

    " clean up the status line and return
    echo ""
    redraw
    return
endfunction

finish

