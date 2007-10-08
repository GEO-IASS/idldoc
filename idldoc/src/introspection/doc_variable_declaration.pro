; docformat = 'rst'

;+
; Returns a string that declares the type of the given variable.
; 
; :Returns: string
; :Params:
;    `var` : in, required, type=any
;       variable to find declaration statement for
;-
function doc_variable_declaration, var
  compile_opt strictarr

  ; get size/type information
  sz = size(var, /structure)
    
  ; structures
  if (sz.type eq 8) then begin
    if (sz.n_elements gt 1) then begin
      dims = strjoin(strtrim(sz.dimensions[0:sz.n_dimensions - 1L], 2), ', ')
      return, 'replicate(' + doc_variable_declaration(var[0]) + ', ' + dims + ')'
    endif else begin
      result = ''
      tNames = tag_names(var)
      structureName = tag_names(var, /structure_name)
      decls = strarr(n_elements(tNames))
      for t = 0L, n_elements(tNames) - 1L do begin
        decls[t] = doc_variable_declaration(var.(t))
      endfor
      return, '{ ' + structureName + ', ' + strjoin(tNames + ': ' + decls, ', ') + ' }'
    endelse
  endif
  
  ; scalars
  if (sz.n_dimensions eq 0) then begin
    case sz.type of
      0 : return, '<undefined>'
      1 : return, strtrim(fix(var), 2) + 'B'   ; use FIX to not use ASCII value
      2 : return, strtrim(var, 2) + 'S'
      3 : return, strtrim(var, 2) + 'L'
      4 : return, strtrim(var, 2)
      5 : return, strtrim(var, 2) + 'D'
      6 : return, 'complex(' + strtrim(real_part(var), 2) + ', ' + strtrim(imaginary(var), 2) + ')'
      7 : return, '''' + var + ''''
      8 : ; handled structure case already
      9 : return, 'dcomplex(' + strtrim(real_part(var), 2) + 'D , ' + strtrim(imaginary(var), 2) + 'D)'
      10 : return, 'ptr_new(' + (ptr_valid(var) ? doc_variable_declaration(*var): '') + ')'
      11 : begin
          classname = obj_class(var)
          classname = classname eq '' ? '' : '''' + classname + ''''
          return, 'obj_new(' + classname + ')'
        end
      12 : return, strtrim(var, 2) + 'U'
      13 : return, strtrim(var, 2) + 'UL'
      14 : return, strtrim(var, 2) + 'LL'
      15 : return, strtrim(var, 2) + 'ULL'
      else : return, 'unknown type'
    endcase
  endif
    
  ; arrays
  declarations = ['---', 'bytarr', 'intarr', 'lonarr', 'fltarr', $
            'dblarr', 'complexarr', 'strarr', '---', 'dcomplexarr', $
            'ptrarr', 'objarr', 'uintarr', 'ulonarr', 'lon64arr', 'ulon64arr']
  
  ; print the values of the array out if only one dimension and a few elements
  if (sz.n_dimensions eq 1 && sz.dimensions[0] le 5) then begin
    results = strarr(sz.dimensions[0])
    for i = 0L, sz.dimensions[0] - 1L do results[i] = doc_variable_declaration(var[i])
    return, '[' + strjoin(results, ', ') + ']'    
  endif
  
  dims = strjoin(strtrim(sz.dimensions[0:sz.n_dimensions - 1L], 2), ', ')
  return, declarations[sz.type] + '(' + dims + ')'
end
