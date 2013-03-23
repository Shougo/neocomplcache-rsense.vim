"=============================================================================
" FILE: rsense.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 23 Mar 2013.
" License: MIT license  {{{
"     Permission is hereby granted, free of charge, to any person obtaining
"     a copy of this software and associated documentation files (the
"     "Software"), to deal in the Software without restriction, including
"     without limitation the rights to use, copy, modify, merge, publish,
"     distribute, sublicense, and/or sell copies of the Software, and to
"     permit persons to whom the Software is furnished to do so, subject to
"     the following conditions:
"
"     The above copyright notice and this permission notice shall be included
"     in all copies or substantial portions of the Software.
"
"     THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
"     OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
"     MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
"     IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
"     CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
"     TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
"     SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
" }}}
"=============================================================================

let s:save_cpo = &cpo
set cpo&vim

call neocomplcache#util#set_default(
      \ 'g:neocomplcache#sources#rsense#home_directory', $RSENSE_HOME)

function! neocomplcache#sources#rsense#define() "{{{
  return neocomplcache#util#has_vimproc() &&
        \ executable(s:get_rsense_command()) ? s:source : {}
endfunction"}}}

let s:source = {
      \ 'name' : 'rsense',
      \ 'kind' : 'ftplugin',
      \ 'mark' : '[R]',
      \ 'filetypes' : { 'ruby' : 1 },
      \}

function! s:source.initialize() "{{{
  " Initialize.
endfunction"}}}

function! s:source.get_keyword_pos(cur_text) "{{{
  if neocomplcache#is_auto_complete() &&
        \ a:cur_text !~ '\%([^. *\t]\.\w*\|\h\w*::\w*\)$'
    return -1
  endif

  return match(a:cur_text, '[^.:]*$')
endfunction"}}}

function! s:source.get_complete_words(cur_keyword_pos, cur_keyword_str) "{{{
  let temp = s:get_temp_name(a:cur_keyword_str)
  try
    let args = [
          \ 'ruby', s:get_rsense_command(),
          \ 'code-completion', '--detect-project=' . bufname('%')] +
          \ s:get_rsense_current_buffer_option(temp, a:cur_keyword_str)
    call add(args, '--prefix=' . a:cur_keyword_str)
    call map(args, "neocomplcache#util#iconv(v:val, &encoding, 'char')")

    " Async completion.
    let process = vimproc#popen2(args)
    let result = []
    while !process.stdout.eof
      let result += process.stdout.read_lines(-1, 100)

      if neocomplcache#complete_check()
        call process.waitpid()
        return []
      endif
    endwhile

    call process.waitpid()

    call map(result, "neocomplcache#util#iconv(v:val, 'char', &encoding)")
  finally
    if filereadable(temp)
      call delete(temp)
    endif
  endtry

  let candidates = []
  let kind_dict = { 'CLASS' : 'C', 'MODULE' : 'M', 'CONSTANT' : 'c', 'METHOD' : 'm' }

  for items in filter(map(filter(result,
        \ "v:val =~# '^completion:'"), "split(v:val)[1:]"), "v:val[0] =~ '^\\h'")
    let candidate = { 'word': items[0] }
    if len(items) > 3
      let candidate.menu = '[R] ' . items[2]
      let candidate.kind = kind_dict[items[3]]
    endif

    call add(candidates, candidate)
  endfor

  return candidates
endfunction"}}}

function! s:get_rsense_command() "{{{
  return g:neocomplcache#sources#rsense#home_directory
        \ . '/bin/rsense'
endfunction"}}}

function! s:get_rsense_current_buffer_option(filename, cur_keyword_str) "{{{
  let current_line = line('.')
  let range = neocomplcache#get_context_filetype_range()
  if range[0][0] != 1
    let current_line -= range[0][0] - 1
  endif
  return ['--file=' . a:filename,
        \ printf('--location=%s:%s', current_line,
        \     col('.') - (mode() ==# 'n' ? 0 : 1) - len(a:cur_keyword_str))]
endfunction"}}}

function! s:get_temp_name(cur_keyword_str) "{{{
  let filename =
        \ neocomplcache#util#substitute_path_separator(tempname())
  let range = neocomplcache#get_context_filetype_range()
  let [start, end] = [range[0][0], range[1][0]]

  let lines = getline(range[0][0], range[1][0])
  let lines[line('.')-start] =
        \ getline('.')[: -1-len(a:cur_keyword_str)]

  call writefile(lines, filename)
  return filename
endfunction"}}}

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: foldmethod=marker
