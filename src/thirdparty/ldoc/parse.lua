-- parsing code for doc comments

local utils = require 'pl.utils'
local List = require 'pl.List'
local Map = require 'pl.Map'
local stringio = require 'pl.stringio'
local lexer = require 'thirdparty.ldoc.lexer'
local tools = require 'thirdparty.ldoc.tools'
local doc = require 'thirdparty.ldoc.doc'
local Item,File = doc.Item,doc.File
local unpack = utils.unpack

------ Parsing the Source --------------
-- This uses the lexer from PL, but it should be possible to use Peter Odding's
-- excellent Lpeg based lexer instead.

local parse = {}

local tnext, append = lexer.skipws, table.insert


local function trim_whitespace(s)
   local from = s:match"^%s*()"
   return from > #s and "" or s:match(".*%S", from)
end

-- a pattern particular to LuaDoc tag lines: the line must begin with @TAG,
-- followed by the value, which may extend over several lines.
local luadoc_tag = '^%s*@(%w+)'
local luadoc_tag_value = luadoc_tag..'(.*)'
local luadoc_tag_mod_and_value = luadoc_tag..'%[([^%]]*)%](.*)'

-- assumes that the doc comment consists of distinct tag lines
local function parse_at_tags(text)
   local lines = stringio.lines(text)
   local preamble, line = tools.grab_while_not(lines,luadoc_tag)
   local tag_items = {}
   local follows
   while line do
      local tag, mod_string, rest = line :match(luadoc_tag_mod_and_value)
      if not tag then tag, rest = line :match (luadoc_tag_value) end
      local modifiers
      if mod_string then
         modifiers  = { }
         for x in mod_string :gmatch "[^,]+" do
            local k, v = x :match "^([^=]+)=(.*)$"
            if not k then k, v = x, true end -- wuz x, x
            modifiers[k] = v
         end
      end
      -- follows: end of current tag
      -- line: beginning of next tag (for next iteration)
      follows, line = tools.grab_while_not(lines,luadoc_tag)
      append(tag_items,{tag, rest .. '\n' .. follows, modifiers})
   end
   return preamble,tag_items
end

--local colon_tag = '%s*(%a+):%s'
local colon_tag = '%s*(%S-):%s'
local colon_tag_value = colon_tag..'(.*)'

local function parse_colon_tags (text)
   local lines = stringio.lines(text)
   local preamble, line = tools.grab_while_not(lines,colon_tag)
   local tag_items, follows = {}
   while line do
      local tag, rest = line:match(colon_tag_value)
      follows, line = tools.grab_while_not(lines,colon_tag)
      local value = rest .. '\n' .. follows
      if tag:match '^[%?!]' then
         tag = tag:gsub('^!','')
         value = tag .. ' ' .. value
         tag = 'tparam'
      end
      append(tag_items,{tag, value})
   end
   return preamble,tag_items
end

-- Tags are stored as an ordered multi map from strings to strings
-- If the same key is used, then the value becomes a list
local Tags = {}
Tags.__index = Tags

function Tags.new (t,name)
   local class
   if name then
      class = t
      t = {}
   end
   t._order = List()
   local tags = setmetatable(t,Tags)
   if name then
      tags:add('class',class)
      tags:add('name',name)
   end
   return tags
end

function Tags:add (tag,value,modifiers)
   if modifiers then -- how modifiers are encoded
      value = {value,modifiers=modifiers}
   end
   local ovalue = self:get(tag)
   if ovalue then
      ovalue:append(value)
      value = ovalue
   end
   rawset(self,tag,value)
   if not ovalue then
      self._order:append(tag)
   end
end

function Tags:get (tag)
   local ovalue = rawget(self,tag)
   if ovalue then -- previous value?
      if getmetatable(ovalue) ~= List then
         ovalue = List{ovalue}
      end
      return ovalue
   end
end

function Tags:iter ()
   return self._order:iter()
end

local function comment_contains_tags (comment,args)
   return (args.colon and comment:find ': ') or (not args.colon and comment:find '@')
end

-- This takes the collected comment block, and uses the docstyle to
-- extract tags and values.  Assume that the summary ends in a period or a question
-- mark, and everything else in the preamble is the description.
-- If a tag appears more than once, then its value becomes a list of strings.
-- Alias substitution and @TYPE NAME shortcutting is handled by Item.check_tag
local function extract_tags (s,args)
   local preamble,tag_items
   if s:match '^%s*$' then return {} end
   if args.colon then --and s:match ':%s' and not s:match '@%a' then
      preamble,tag_items = parse_colon_tags(s)
   else
      preamble,tag_items = parse_at_tags(s)
   end
   local strip = tools.strip
   local summary, description = preamble:match('^(.-[%.?])(%s.+)')
   if not summary then
      -- perhaps the first sentence did not have a . or ? terminating it.
      -- Then try split at linefeed
      summary, description = preamble:match('^(.-\n\n)(.+)')
      if not summary then
         summary = preamble
      end
   end  --  and strip(description) ?
   local tags = Tags.new{summary=summary and strip(summary) or '',description=description or ''}
   for _,item in ipairs(tag_items) do
      local tag, value, modifiers = Item.check_tag(tags,unpack(item))
      -- treat multiline values more gently..
      if not value:match '\n[^\n]+\n' then
         value = strip(value)
      end

      tags:add(tag,value,modifiers)
   end
   return tags --Map(tags)
end

local _xpcall = xpcall
if true then
   _xpcall = function(f) return true, f() end
end



-- parses a Lua or C file, looking for ldoc comments. These are like LuaDoc comments;
-- they start with multiple '-'. (Block commments are allowed)
-- If they don't define a name tag, then by default
-- it is assumed that a function definition follows. If it is the first comment
-- encountered, then ldoc looks for a call to module() to find the name of the
-- module if there isn't an explicit module name specified.

local function parse_file(fname, lang, package, args)
   local line,f = 1
   local F = File(fname)
   local module_found, first_comment = false,true
   local current_item, module_item

   F.args = args
   F.lang = lang
   F.base = package

   local tok,f = lang.lexer(fname)
   if not tok then return nil end

   local function lineno ()
      return tok:lineno()
   end

   local function filename () return fname end

   function F:warning (msg,kind,line)
      kind = kind or 'warning'
      line = line or lineno()
      local warning = ("%s:%s: %s"):format(fname,line,msg)
      Item.warnings[#Item.warnings+1] = warning
   end

   function F:error (msg)
      self:warning(msg,'error')
      error(msg)
   end

   local function add_module(tags,module_found,old_style)
      tags:add('name',module_found)
      tags:add('class','module')
      local item = F:new_item(tags,lineno())
      item.old_style = old_style
      module_item = item
   end

   local function add_item(tags, item_follows, parse_error, is_local, case, t)
      local line = lineno()
      if t ~= nil then
         if item_follows then -- parse the item definition
            local err = item_follows(tags,tok)
            if err then F:error(err) end
         elseif parse_error then
            F:warning('definition cannot be parsed - '..parse_error)
         else
            lang:parse_extra(tags,tok,case)
         end
      end
      if is_local or tags['local'] then
         tags:add('local',true)
      end
      -- support for standalone fields/properties of classes/modules
      if (tags.field or tags.param) and not tags.class then
         -- the hack is to take a subfield and pull out its name,
         -- (see Tag:add above) but let the subfield itself go through
         -- with any modifiers.
         local fp = tags.field or tags.param
         if type(fp) == 'table' then fp = fp[1] end
         fp = tools.extract_identifier(fp)
         tags:add('name',fp)
         tags:add('class','field')
      end
      if tags.name then
         current_item = F:new_item(tags,line)
         current_item.inferred = item_follows ~= nil
         if doc.project_level(tags.class) then
            if module_item then
               F:error("Module already declared!")
            end
            module_item = current_item
         end
      end
   end

   local mod
   local t,v = tnext(tok)
   -- with some coding styles first comment is standard boilerplate; option to ignore this.
   if args.boilerplate and t == 'comment' then
      -- hack to deal with boilerplate inside Lua block comments
      if v:match '%s*%-%-%[%[' then lang:grab_block_comment(v,tok) end
      t,v = tnext(tok)
   end
   if t == '#' then -- skip Lua shebang line, if present
      while t and t ~= 'comment' do t,v = tnext(tok) end
      if t == nil then
         F:warning('empty file')
         return nil
      end
   end
   local in_return = false
   local guessed_mod_name = nil
   if lang.parse_module_call and t ~= 'comment' then
      local prev_token
      while t do
         if prev_token ~= '.' and prev_token ~= ':' and t == 'iden' and v == 'module' then
            break
         end
         if in_return then
            if t == "iden" then
               guessed_mod_name = v
            end
         else
            in_return = t == "keyword" and v == "return"
         end
         prev_token = t
         t, v = tnext(tok)
         if t then
            guessed_mod_name = nil
         end
      end
      if not t then
         -- HACK: try to determine module name from file name and
         -- top level return value.

         -- Guess the module name from the file name. However, we will
         -- only return this module if there is a top-level return
         -- statement at the end of the file.
         local mod_name = fname:match("/([^./]+)%.[a-z]+$")

         -- ldoc appears to lowercase the filename, so a
         -- case-sensitive comparison will not always match.
         if mod_name and guessed_mod_name and string.lower(mod_name) == string.lower(guessed_mod_name) then
            F:warning("assuming module named " .. mod_name .. " exists for documentation")
            add_module(Tags.new{summary="",description="",is_undocumented=true},mod_name,true)
            first_comment = false
            module_found = true

            -- We have to reparse the file since the lexer reached the
            -- end of it once.
            tok,f = lang.lexer(fname)
            t,v = tnext(tok)
         else
            if not args.ignore then
               F:warning("no module() call found; no initial doc comment")
            end
            return nil
         end
      else
         mod,t,v = lang:parse_module_call(tok,t,v)
         if mod and mod ~= '...' then
            add_module(Tags.new{summary='(no description)'},mod,true)
            first_comment = false
            module_found = true
         end
      end
   end
   local ok, err = xpcall(function()
   local last_was_newline
   while t do
      if t == 'comment' then
         local comment = {}
         local ldoc_comment,block = lang:start_comment(v)

         if ldoc_comment and block then
            t,v = lang:grab_block_comment(v,tok)
         end

         if lang:empty_comment(v)  then -- ignore rest of empty start comments
            t,v = tok()
            if t == 'space' and not v:match '\n' then
               t,v = tok()
            end
         end

         while t and t == 'comment' do
            v = lang:trim_comment(v)
            append(comment,v)
            t,v = tok()
            if t == 'space' and not v:match '\n' then
               t,v = tok()
            end
         end

         if t == 'space' then t,v = tnext(tok) end

         local item_follows, tags, is_local, case, parse_error
         if ldoc_comment then
            comment = table.concat(comment)
            if comment:match '^%s*$' then
               ldoc_comment = nil
            end
         end
         if ldoc_comment then
            if first_comment then
               first_comment = false
            else
               item_follows, is_local, case = lang:item_follows(t,v,tok)
               if not item_follows then
                  parse_error = is_local
                  is_local = false
               end
            end

            if item_follows or comment_contains_tags(comment,args) then
               tags = extract_tags(comment,args)

               -- explicitly named @module (which is recommended)
               if doc.project_level(tags.class) then
                  module_found = tags.name
                  -- might be a module returning a single function!
                  if tags.param or tags['return'] then
                     local parms, ret, summ = tags.param, tags['return'],tags.summary
                     local name = tags.name
                     tags.param = nil
                     tags['return'] = nil
                     tags['class'] = nil
                     tags['name'] = nil
                     add_module(tags,name,false)
                     tags = {
                        summary = '',
                        name = 'returns...',
                        class = 'function',
                        ['return'] = ret,
                        param = parms
                     }
                  end
               end
               doc.expand_annotation_item(tags,current_item)
               -- if the item has an explicit name or defined meaning
               -- then don't continue to do any code analysis!
               -- Watch out for the case where there are field or param tags
               -- but no class, since these will be fixed up later as module/class
               -- entities
               if (tags.field or tags.param) and not tags.class then
                  parse_error = false
               end
               if tags.name then
                  if not tags.class then
                     F:warning("no type specified, assuming function: '"..tags.name.."'")
                     tags:add('class','function')
                  end
                  item_follows, is_local, parse_error = false, false, false
               elseif args.no_args_infer then
                  F:error("No name and type provided (no_args_infer)")
               elseif lang:is_module_modifier (tags) then
                  if not item_follows then
                     F:warning("@usage or @export followed by unknown code")
                     break
                  end
                  item_follows(tags,tok)
                  local res, value, tagname = lang:parse_module_modifier(tags,tok,F)
                  if not res then F:warning(value); break
                  else
                     if tagname then
                        module_item:set_tag(tagname,value)
                     end
                     -- don't continue to make an item!
                     ldoc_comment = false
                  end
               end
            end
            if parse_error then
               F:warning('definition cannot be parsed - '..parse_error)
            end
         end
         -- some hackery necessary to find the module() call
         if not module_found and ldoc_comment then
            local old_style
            module_found,t,v = lang:find_module(tok,t,v)
            -- right, we can add the module object ...
            old_style = module_found ~= nil
            if not module_found or module_found == '...' then
               -- we have to guess the module name
               module_found = tools.this_module_name(package,fname)
            end
            if not tags then tags = extract_tags(comment,args) end
            add_module(tags,module_found,old_style)
            tags = nil
            if not t then
               F:warning('contains no items','warning',1)
               break;
            end -- run out of file!
            -- if we did bump into a doc comment, then we can continue parsing it
         end

         -- end of a block of document comments
         if ldoc_comment and tags then
            add_item(tags, item_follows, parse_error, is_local, case, t)
            if not t then break end
         end
      elseif t == "keyword" and v == "function" then
         -- Pick up undocumented functions, so we at least know of
         -- their existence.
         if last_was_newline then
            local parse_error
            local item_follows, is_local, case = lang:item_follows(t,v,tok)
            if not item_follows then
               parse_error = is_local
               is_local = false
            end
            local tags = Tags.new{summary="",description="",params={},modifiers={},is_undocumented=true}
            add_item(tags, item_follows, parse_error, is_local, case, t)
         end
      end
      last_was_newline = t == "space" and v == "\n"
      if t ~= 'comment' then t,v = tok() end
   end
   end,debug.traceback)
   if not ok then return F, err end
   if f then f:close() end
   return F
end

function parse.file(name,lang, args)
   local F,err = parse_file(name,lang,args.package,args)
   if err or not F then return F,err end
   local ok,err = xpcall(function() F:finish() end,debug.traceback)
   if not ok then return F,err end
   return F
end

return parse
