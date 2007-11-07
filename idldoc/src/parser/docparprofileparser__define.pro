; docformat = 'rst'

;+ 
; Parser for .pro files: files containing routines, main-level programs, and 
; batch files. This parser is responsible for finding comments (but not parsing 
; them) and parsing IDL code.
;
; Only one file parser should be created for all .pro files.
;-


;+
; Return the contents of a .pro file.
;
; :Returns: strarr or -1L if empty file
;
; :Params:
;    filename : in, required, type=string
;       filename of .pro file to read
;
; :Keywords:
;    empty : out, optional, type=boolean
;       returns whether the file was empty
;    n_lines : out, optional, type=long
;       number of lines in the file
;    modification_time : out, optional, type=string
;       modification time of the file
;-
function docparprofileparser::_readFile, filename, empty=empty, $
                                         n_lines=nLines, modification_time=mTime
  compile_opt strictarr
  
  mTime = systime(0, (file_info(filename)).mtime)
  nLines = file_lines(filename)
  if (nLines eq 0) then begin
    empty = 1B
    return, -1L
  endif
  
  code = strarr(nLines)
  
  empty = 0B
  openr, lun, filename, /get_lun
  readf, lun, code
  free_lun, lun
  
  return, code
end


;+
; Strips the end-of-line comments from a line.
;
; :Returns: string
;
; :Params:
;    line : in, required, type=string
;       line of code
;-
function docparprofileparser::_stripComments, line, comments=comments
  compile_opt strictarr

  comments = ''
  if (strpos(line, ';') lt 0) then return, line
  
  bline = byte(line)
  bSingle = (byte(''''))[0]
  bDouble = (byte('"'))[0]
  bSemi = (byte(';'))[0]
  
  opener = 0B
  inside = 0B
  for i = 0L, n_elements(bline) - 1L do begin
    if (inside) then begin
      if (bline[i] eq opener) then inside = 0B        
      continue      
    endif
    
    case bline[i] of
      bSingle: begin
          opener = bSingle
          inside = 1B
        end
      bDouble: begin
          opener = bDouble
          inside = 1B
        end
      bSemi: begin
          comments = strmid(line, i)
          return, strmid(line, 0, i)
        end
      else:  ; ignore
    endcase
  endfor
  
  return, line
end


;+
; Finds docformat string.
;
; :Returns: 1B if docformat found, 0 if not
;
; :Params:
;    line : in, required, type=string
;       first line of a .pro file
;
; :Keywords:
;    format : out, optional, type=string
;       format string: either idldoc, idl, or rst
;    markup : out, optional, type=string 
;       markup string: either verbatim or rst; defaults to rst if format is
;       rst or verbatim if markup is specified but not rst 
;-
function docparprofileparser::_checkDocformatLine, line, $
                                                   format=format, $
                                                   markup=markup
  compile_opt strictarr

  ; if first non-whitespace character is not a semicolon, then not a comment 
  ; and no docformat
  trimLine = strtrim(line, 2)
  if (strmid(trimLine, 0, 1) ne ';') then return, 0B
  
  ; remove semicolon and any whitespace
  trimLine = strtrim(strmid(trimLine, 1), 2)
  
  ; return negative if no "docformat"
  if (strlowcase(strmid(trimLine, 0, 9)) ne 'docformat') then return, 0B
  
  ; remove "docformat" and any whitespace
  trimLine = strtrim(strmid(trimLine, 10), 2)
  
  ; return negative if no =
  if (strmid(trimLine, 0, 1) ne '=') then return, 0B
  
  ; remove "=" and any whitespace
  trimLine = strtrim(strmid(trimLine, 1), 2)
  
  ; must have matching quotes
  first = strmid(trimLine, 0, 1)
  last = strmid(trimLine, 0, 1, /reverse_offset)
  if (first ne last) then return, 0B
  if (first ne '''' and first ne '"') then return, 0B
  trimLine = strmid(trimLine, 1, strlen(trimLine) - 2L)
  
  ; set format and/or markup depending on the number of tokens
  tokens = strsplit(trimLine, /extract, count=nTokens)
  case nTokens of
    0: return, 0B
    1: begin
        format = strlowcase(tokens[0])
        markup = format eq 'rst' ? 'rst' : 'verbatim'
        return, 1B
      end
    else: begin
        format = strlowcase(tokens[0])
        markup = strlowcase(tokens[1])
        return, 1B
      end
  endcase
end


;+
; Parse comments for a routine and update the information for the routine.
; 
; :Params:
;    routine : in, required, type=object
;       routine tree object
;    comments : in, required, type=strarr
;       comments to parse
;
; :Keywords:
;    format : in, required, type=string
;       format type: idldoc, idl, rst
;    markup : in, required, type=string
;       markup type: verbatim, rst
;-
pro docparprofileparser::_parseRoutineComments, routine, comments, $
                                                format=format, markup=markup
  compile_opt strictarr
  
  formatParser = self.system->getParser(format + 'format')
  markupParser = self.system->getParser(markup + 'markup')
  
  ; call format parser's "parse" method
  formatParser->parseRoutineComments, comments, routine=routine, markup_parser=markupParser
end


;+
; Parse comments associated with a file.
;
; :Params:
;    file : in, required, type=object
;       file tree object
;    comments : in, required, type=strarr
;       comments to parse
;
; :Keywords:
;    format : in, required, type=string
;       format type: idldoc, idl, rst
;    markup : in, required, type=string
;       markup type: verbatim, rst
;-
pro docparprofileparser::_parseFileComments, file, comments, $
                                             format=format, markup=markup
  compile_opt strictarr
  
  formatParser = self.system->getParser(format + 'format')
  markupParser = self.system->getParser(markup + 'markup')
  
  ; call format parser's "parse" method
  formatParser->parseFileComments, comments, file=file, markup_parser=markupParser
end


;+
; Parse arguments/keywords of the routine header. 
; 
; :Params:
;    routine : in, required, type=object
;       routine tree object
;    cmd : in, required, type=string
;       header line (comments stripped already)
;
; :Keywords:
;    first_line : in, optional, type=boolean
;       set if this is the first line of the routine header
;-
pro docparprofileparser::_parseHeader, routine, cmd, first_line=firstLine
  compile_opt strictarr
  
  args = strsplit(cmd, ',', /extract, count=nargs)
  
  ; skip first "argument" if this is the first line (the "pro routine_name" 
  ; part)
  for a = keyword_set(firstLine), nargs - 1L do begin
    argument = strcompress(args[a], /remove_all)
    if (argument eq '$') then continue
    if (strpos(argument, '=') ne -1) then begin
      ; add text before "=" as keyword to routine
      name = (strsplit(argument, '=', /extract))[0]
      keyword = obj_new('DOCtreeArgument', routine, name=name, /is_keyword, $
                        system=self.system)
      routine->addKeyword, keyword
    endif else begin
      ; add param as a positional parameter to routine
      param = obj_new('DOCtreeArgument', routine, name=argument, $
                      system=self.system)
      routine->addParameter, param
    endelse
  endfor
end


;+
; Parse the lines of a .pro file, ripping out comments.
;
; :Params:
;    lines : in, required, type=strarr
;       text of .pro file
;    file : in, required, type=object
;       file tree object
;
; :Keywords:
;    format : in, required, type=string, default=system's format
;       format of comments 
;    markup : in, required, type=string, default=system's markup
;       markup format for comments
;-
pro docparprofileparser::_parseLines, lines, file, format=format, markup=markup
  compile_opt strictarr, logical_predicate
  
  insideComment = 0B
  justFinishedComment = 0L   ; 0, 1 (in header), 2 (just finished)
  justFinishedHeader = 0B
  headerContinued = 0B
  codeLevel = 0L
  currentComments = obj_new('MGcoArrayList', type=7)
  
  tokenizer = obj_new('DOCparProFileTokenizer', lines)
  
  endVariants = ['end', 'endif', 'endelse', 'endcase', 'endswitch', 'endfor', $
                 'endwhile', 'endrep']
                 
  while (tokenizer->hasNext()) do begin
    ; determine if line has: ;+, ;-, pro/function, begin, end*
    command = tokenizer->next()
    
    if (strmid(command, 0, 2) eq ';-' && insideComment) then begin
      insideComment = 0B
      justFinishedComment = 2L
      continue
    endif    
    
    if (strmid(command, 0, 1) eq ';' && insideComment) then begin
      currentComments->add, strmid(command, 2)
      continue
    endif
    
    if (strmid(command, 0, 2) eq ';+' $
          && ((codeLevel eq 0L) $
            || (codeLevel eq 1L && justFinishedHeader eq 1B))) then begin
      insideComment = 1B
      justFinishedHeader = 0B
      continue
    endif
    
    if (strmid(command, 0, 1) eq ';') then continue
    
    ; token delimiters are: space, tab, and comma
    delims = ' ' + string(9B) + ','
    tokens = strsplit(self->_stripComments(command), delims, /extract, count=nTokens)
    if (nTokens eq 0) then begin
      if (justFinishedComment eq 2 && ~headerContinued && currentComments->count() gt 0) then begin
        self->_parseFileComments, file, currentComments->get(/all), $
                                  format=format, markup=markup
        currentComments->remove, /all
      endif
      
      continue          
    endif
    
    firstToken = strlowcase(tokens[0])
    lastToken = strlowcase(tokens[nTokens - 1L])   
    
    ; if starting begin/end block (switch/case implicitly start a block) then 
    ; increase code level
    if (lastToken eq 'begin' && ~insideComment) then codeLevel++
    if (firstToken eq 'case' || firstToken eq 'switch') then codeLevel++
    
    ; if firstToken is one of the end variants then codeLevel--
    ind = where(firstToken eq endVariants, nEndsFound)
    if (nEndsFound gt 0) then codeLevel--
    
    ; process keywords/params in continued header
    if (headerContinued) then begin
      ; comment lines in the header automatically continue the header
      if (strmid(command, 0, 1) eq ';') then continue
      
      self->_parseHeader, routine, command
      
      ; might be continued more
      headerContinued = lastToken eq '$' ? 1B : 0B
      if (~headerContinued && currentComments->count() gt 0) then begin
        self->_parseRoutineComments, routine, currentComments->get(/all), $
                                     format=format, markup=markup
        
        currentComments->remove, /all
        justFinishedHeader = 1B
      endif      
    endif
    
    ; if starts with pro or function then codeLevel++
    if (firstToken eq 'pro' || firstToken eq 'function') then begin
      codeLevel++
      insideComment = 0B
      
      if (lastToken eq '$') then headerContinued = 1B
      
      routine = obj_new('DOCtreeRoutine', file, system=self.system)
      file->addRoutine, routine
      
      routine->setProperty, name=(strsplit(tokens[1], ',', /extract))[0]
      if (strpos(tokens[1], '::') ne -1) then routine->setProperty, is_method=1B
      if (firstToken eq 'function') then routine->setProperty, is_function=1B   
         
      self->_parseHeader, routine, command, /first_line
      
      if (~headerContinued) then justFinishedHeader = 1B
      if (~headerContinued && currentComments->count() gt 0) then begin
        self->_parseRoutineComments, routine, currentComments->get(/all), $
                                     format=format, markup=markup
        
        currentComments->remove, /all
      endif
    endif
    
    ; "interior" comment
    if (~headerContinued && justFinishedComment eq 2 && codeLevel eq 1 && currentComments->count() gt 0) then begin
      self->_parseRoutineComments, routine, currentComments->get(/all), $
                                   format=format, markup=markup  
      currentComments->remove, /all  
    endif
    
    justFinishedComment--
  endwhile
  
  ; if the codeLevel ends up negative then the file had a main-level program
  file->setProperty, has_main_level=codeLevel lt 0
  
  ; if there are not routines in the file and it doesn't have a main-level
  ; program, then it's batch file
  file->getProperty, n_routines=nRoutines, has_main_level=hasMainLevel
  if (~hasMainLevel && nRoutines eq 0) then begin
    file->setProperty, is_batch=1B
  endif
  
  obj_destroy, [tokenizer, currentComments]
end


;+
; Parse the given .pro file.
; 
; :Returns: file tree object
; :Params:
;    filename : in, required, type=string
;       absolute path to .pro file to be parsed
;
; :Keywords:
;    found : out, optional, type=boolean
;       returns 1 if filename found, 0 otherwise
;    directory : in, required, type=object
;       directory tree object
;-
function docparprofileparser::parse, filename, found=found, directory=directory
  compile_opt strictarr
  
  ; sanity check
  found = file_test(filename)
  if (~found) then return, obj_new()
  
  ; create file
  file = obj_new('DOCtreeProFile', $
                 basename=file_basename(filename), $
                 directory=directory, $
                 system=self.system)
  
  ; get the contents of the file
  lines = self->_readFile(filename, empty=empty, n_lines=nLines, $
                          modification_time=mTime)
  file->setProperty, n_lines=nLines, modification_time=mTime, code=lines
  
  ; if the file is empty, no parsing needs to be done
  if (empty) then begin
    file->setProperty, is_batch=1B
    return, file
  endif
  
  ; check for docformat change
  foundFormat = self->_checkDocformatLine(lines[0], $ 
                                          format=format, $ 
                                          markup=markup)
  if (~foundFormat) then begin
    self.system->getProperty, format=format
    self.system->getProperty, markup=markup
  endif else file->setProperty, format=format, markup=markup
  
  ; parse lines of file
  self->_parseLines, lines, file, format=format, markup=markup
  
  ; return independent file
  return, file
end


;+
; Create a file parser.
;
; :Keywords:
;    system : in, required, type=object
;       system object
;-
function docparprofileparser::init, system=system
  compile_opt strictarr
  
  self.system = system
  
  return, 1
end


;+
; Define instance variables.
;-
pro docparprofileparser__define
  compile_opt strictarr
  
  define = { DOCparProFileParser, $
             system: obj_new() $
           }
end