local Draw = require("api.Draw")
local I18N = require("api.I18N")
local IUiList = require("api.gui.IUiList")
local ListModel = require("api.gui.ListModel")
local IInput = require("api.gui.IInput")
local InputHandler = require("api.gui.InputHandler")
local IList = require("api.gui.IList")
local IPaged = require("api.gui.IPaged")
local PagedListModel = require("api.gui.PagedListModel")

local UiList = class("UiList", IUiList)
UiList:delegate("model", {
                   "changed",
                   "selected",
                   "chosen",
                   "items",
                   "selected_item",
                   "select",
                   "select_next",
                   "select_previous",
                   "can_select",
                   "can_choose",
                   "get_item_text",
                   "set_data",
                   "choose",
                   "on_choose",

                   "select_page",
                   "next_page",
                   "previous_page",
                   "page",
                   "page_max",
                   "page_size",
})
UiList:delegate("input", IInput)

local keys = "abcdefghijklmnopqr"

function UiList:init(items, item_height, item_offset_x, item_offset_y)
   if is_an(IList, items) then
      self.model = items
   else
      self.model = ListModel:new(items)
   end
   self.item_height = item_height or 19
   self.item_offset_x = item_offset_x or 0
   self.item_offset_y = item_offset_y or -2
   self.select_key = { image = Draw.load_image("graphic/temp/select_key.bmp") }
   self.list_bullet = { image = Draw.load_image("graphic/temp/list_bullet.bmp") }

   self:set_data()

   local thing = {}
   for i=1,#keys do
      local key = keys:sub(i, i)
      thing[key] = function()
         print("Alright. " .. key)
         self:choose(i)
      end
   end
   thing.up = function() self:select_previous() end
   thing.down = function() self:select_next() end
   thing["return"] = function() self:choose() end

   if is_an(IPaged, self.model) then
      thing.left = function()  self:previous_page();print("Page Prev." .. self.page); end
      thing.right = function()  self:next_page();print("Page Next." .. self.page); end
   end

   self.input = InputHandler:new()
   self.input:bind_keys(thing)
end

function UiList:new_paged(items, page_max, item_height, item_offset_x, item_offset_y)
   return UiList:new(PagedListModel:new(items, page_max), item_height, item_offset_x, item_offset_y)
end

function UiList:relayout(x, y)
   self.x = x
   self.y = y
   self.changed = false
   self.chosen = false
end

function UiList:draw_select_key(item, i, key_name, x, y)
   Draw.image(self.select_key.image, x, y, nil, nil, {255, 255, 255})
   Draw.set_font(13)
   Draw.text_shadowed(key_name,
                      x + (self.select_key.image:getWidth() - Draw.text_width(key_name)) / 2 - 2,
                      y + (self.select_key.image:getHeight() - Draw.text_height()) / 2,
                      {250, 240, 230},
                      {50, 60, 80})
end

function UiList:draw_item_text(text, item, i, x, y, x_offset)
   local selected = i == self.selected

   x_offset = x_offset or 0
   if selected then
      local width = math.clamp(Draw.text_width(text) + 32 + x_offset, 10, 400)
      Draw.filled_rect(x, y - 2, width, 19, {127, 191, 255, 63})
      Draw.image(self.list_bullet.image, x + width - 20, y + 2, nil, nil, {255, 255, 255})
   end
   Draw.text(text, x + 4 + x_offset, y + 1, {0, 0, 0})
end

function UiList:draw_item(item, i, x, y)
   local key_name = keys:sub(i, i)

   self:draw_select_key(item, i, key_name, x, y)

   Draw.set_font(14) -- 14 - en * 2

   local text = self:get_item_text(item, i)
   self:draw_item_text(text, item, i, x + 26, y + 1)
end

function UiList:draw()
   for i, item in ipairs(self.items) do
      local x = self.x + self.item_offset_x
      local y = (i - 1) * self.item_height + self.y + self.item_offset_y
      self:draw_item(item, i, x, y)
   end
end

function UiList:update()
   self.changed = false
   self.chosen = false
end

return UiList
