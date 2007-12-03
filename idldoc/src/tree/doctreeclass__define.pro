; docformat = 'rst'

;+
; Get variables for use with templates.
;
; :Returns: variable
; :Params:
;    name : in, required, type=string
;       name of variable
;
; :Keywords:
;    found : out, optional, type=boolean
;       set to a named variable, returns if variable name was found
;-
function doctreeclass::getVariable, name, found=found
  compile_opt strictarr
  
  found = 1B
  case strlowcase(name) of
    'classname': return, self.classname
    'url': begin
        if (~obj_valid(self.proFile)) then return, ''
        
        self.proFile->getProperty, directory=directory
        dirUrl = directory->getVariable('url')
        proUrl = self.proFile->getVariable('local_url')
        return, dirUrl + proUrl
      end
      
    'n_parents': return, self.parents->count()
    'parents': return, self.parents->get(/all)
          
    'n_ancestors': return, self.ancestors->count()
    'ancestors': return, self.ancestors->get(/all)

    'n_children': return, self.children->count()
    'children': return, self.children->get(/all)
    
    'n_fields': return, self.fields->count()
    'fields': return, self.fields->values()
    'field_names': return, self->getFieldNames()
    
    'n_properties': return, self.properties->count()
    'properties': return, self.properties->values()
            
    'index_name': return, self.classname
    'index_type': return, 'class'
    'index_url': return, self->getVariable('url')
    
    else: begin
        ; search in the system object if the variable is not found here
        var = self.proFile->getVariable(name, found=found)
        if (found) then return, var
        
        found = 0B
        return, -1L
      end    
  endcase
end


;+
; Easy to use accessor for classname.
;
; :Returns: string
;-
function doctreeclass::getClassname
  compile_opt strictarr
  
  return, self.classname
end


;+
; Easy to use accessor for whether the class has an URL.
; 
; :Returns: boolean
;-
function doctreeclass::hasUrl
  compile_opt strictarr
  
  return, obj_valid(self.proFile)
end


;+
; Easy to use accessor for URL.
;
; :Returns: string
;-
function doctreeclass::getUrl
  compile_opt strictarr
  
  if (~obj_valid(self.proFile)) then return, ''
  
  self.proFile->getProperty, directory=directory
  dirUrl = directory->getVariable('url')
  proUrl = self.proFile->getVariable('local_url')
  return, dirUrl + proUrl  
end


;+
; Easy to use accessor for number of fields.
;
; :Returns: strarr or string
;-
function doctreeclass::getFieldCount
  compile_opt strictarr
  
  return, self.fields->count()
end


;+
; Easy to use accessor for field names.
;
; :Returns: strarr or string
;-
function doctreeclass::getFieldNames
  compile_opt strictarr
  
  nFields = self.fields->count()
  if (nFields eq 0) then return, ''
  
  fieldNames = strarr(nFields)
  fields = self.fields->values()
  for f = 0L, nFields - 1L do begin
    fields[f]->getProperty, name=name
    fieldNames[f] = name
  endfor
  
  return, fieldNames
end


;+
; Easy to use accessor for field types.
;
; :Returns: strarr or string
;-
function doctreeclass::getFieldTypes
  compile_opt strictarr
  
  nFields = self.fields->count()
  if (nFields eq 0) then return, ''
  
  fieldTypes = strarr(nFields)
  fields = self.fields->values()
  for f = 0L, nFields - 1L do begin
    fields[f]->getProperty, type=type
    fieldTypes[f] = type
  endfor
  
  return, fieldTypes
end

        
pro doctreeclass::setProperty, pro_file=proFile, classname=classname
  compile_opt strictarr
  
  if (n_elements(proFile) gt 0) then self.proFile = proFile
  if (n_elements(classname) gt 0) then self.classname = classname
end


pro doctreeclass::getProperty, ancestors=ancestors, classname=classname, $
                               properties=properties
  compile_opt strictarr

  if (arg_present(ancestors)) then ancestors = self.ancestors
  if (arg_present(classname)) then classname = self.classname
  if (arg_present(properties)) then properties = self.properties
end


pro doctreeclass::addChild, child
  compile_opt strictarr
  
  self.children->add, child
end


;+
; Classes are visible if their files are visible.
;-
function doctreeclass::isVisible
  compile_opt strictarr
  
  return, obj_valid(self.proFile) ? self.proFile->isVisible() : 1B
end


;+
; Create a structure containing the fields of the class.
;
; :Params:
;    classname : in, required, type=string
;       name of the named structure i.e. the classname
;
; :Keywords:
;    error : out, optional, type=long
;       set to a named variable to contain any error code; 0 indicates no error
;-
function doctreeclass::_createClassStructure, classname, error=error
  compile_opt strictarr
  
  error = 0L
  catch, error
  if (error ne 0L) then begin
    catch, /cancel
    error = 1L
    return, -1L
  endif
  
  s = create_struct(name=classname)
  return, s
end


;+
; Find parent classes for class and figure out where each field was defined.
;-
pro doctreeclass::findParents
  compile_opt strictarr
  
  ; get all fields defined in class
  s = self->_createClassStructure(self.classname, error=error)
  if (error ne 0L) then begin
    self.system->warning, 'cannot find definition for class ' + self.classname $
                            + ' in path'
    return
  endif
    
  ; get direct parent classes
  parents = obj_class(self.classname, /superclass)
  nParents = parents[0] eq '' ? 0 : n_elements(parents)  
  
  ; this list will contain the names of fields of ancestor classes, any fields
  ; in s that are not in ancestorFieldNameList then are defined in this class
  ancestorFieldNameList = obj_new('MGcoArrayList', type=7)
  
  for i = 0L, nParents - 1L do begin
    ; lookup parent class in system class hash table
    p = self.classes->get(strlowcase(parents[i]), found=found)
    if (~found) then begin
      p = obj_new('DOCtreeClass', parents[i], system=self.system)
      self.classes->put, strlowcase(parents[i]), p
    endif

    ; connect classes
    p->addChild, self
    self.parents->add, p
    self.ancestors->add, p
    
    ; ancestors of parents of this class are ancestors of this class 
    p->getProperty, ancestors=ancestors
    if (ancestors->count() gt 0) then begin
      self.ancestors->add, ancestors->get(/all)
    endif
  endfor

  for a = 0L, self.ancestors->count() - 1L do begin
    anc = self.ancestors->get(position=a)
    
    ; add all the fields of the ancestor class to the ancestorFieldNameList
    ancestorFieldNameList->add, anc.fields->keys()
  endfor
  
  ancestorFieldNames = ancestorFieldNameList->get(/all, count=nAncestorFieldNames)
  fieldNames = tag_names(s)

  for f = 0L, n_tags(s) - 1L do begin  
    if (nAncestorFieldNames ne 0) then begin
      ind = where(strlowcase(fieldNames[f]) eq ancestorFieldNames, nMatches)
    endif
    if (nAncestorFieldNames eq 0 || nMatches eq 0) then begin
      field = self->addField(fieldNames[f])
      field->setProperty, type=doc_variable_declaration(s.(f))
    endif
  endfor  
  
  ; don't need the array list object any more
  obj_destroy, ancestorFieldNameList
end


function doctreeclass::addField, fieldName, get_only=getOnly
  compile_opt strictarr
  
  field = self.fields->get(strlowcase(fieldName), found=found)
  if (~found && ~keyword_set(getOnly)) then begin
    field = obj_new('DOCtreeField', fieldName, $
                    class=self, system=self.system)
    self.fields->put, strlowcase(fieldName), field
  endif
  return, field
end


;+
; Adds the given property to this class.
;
; :Params:
;    property : in, required, type=object
;       property tree object to add
;-
pro doctreeclass::addProperty, property, property_name=propertyName
  compile_opt strictarr
  
  if (n_elements(propertyName) ne 0) then begin
    property = self.properties->get(strlowcase(propertyName), found=found)
    if (~found) then begin
      property = obj_new('DOCtreeProperty', propertyName, system=self.system)
      self.properties->put, strlowcase(propertyName), property
    endif
    property->setProperty, class=self
  endif
  
  property->setProperty, class=self
  property->getProperty, name=propertyName
  self.properties->put, strlowcase(propertyName), property
end


;+
; Free resources.
;-
pro doctreeclass::cleanup
  compile_opt strictarr
  
  if (self.fields->count() gt 0) then obj_destroy, self.fields->values()
  obj_destroy, self.fields
  if (self.properties->count() gt 0) then obj_destroy, self.properties->values()
  obj_destroy, self.properties
end


;+
; Create a class tree object.
;
; :Returns: 1 for success, 0 otherwise
;-
function doctreeclass::init, classname, pro_file=proFile, system=system
  compile_opt strictarr
  
  self.classname = classname
  if (n_elements(proFile) gt 0) then self.proFile = proFile
  self.system = system
  
  self.system->createIndexEntry, self.classname, self
  
  self.system->getProperty, classes=classes
  self.classes = classes
  self.classes->put, strlowcase(self.classname), self

  self.parents = obj_new('MGcoArrayList', type=11)
  self.ancestors = obj_new('MGcoArrayList', type=11)
  self.children = obj_new('MGcoArrayList', type=11)
  
  self.fields = obj_new('MGcoHashtable', key_type=7, value_type=11)
  self.properties = obj_new('MGcoHashtable', key_type=7, value_type=11)
  
  self->findParents
  
  return, 1
end


;+
; Define instance variables.
;
; :Fields:
;    system
;       system tree object
;    classes
;       classes hashtable (classname -> class object) from system tree object
;    proFile
;       pro file which contains the class
;    classname
;       string classname of the class
;    parents
;       array list of parent classes
;    ancestors
;       array list of ancestor classes
;    fields
;       hash table of field tree classes
;    properties
;       hash table of property tree classes
;-
pro doctreeclass__define
  compile_opt strictarr
  
  define = { DOCtreeClass, $
             system: obj_new(), $
             classes: obj_new(), $
             proFile: obj_new(), $
             
             classname: '', $
             
             parents: obj_new(), $             
             ancestors: obj_new(), $
             children: obj_new(), $
             
             fields: obj_new(), $
             properties: obj_new() $
           }
end
