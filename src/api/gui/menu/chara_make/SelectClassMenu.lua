local Draw = require("api.Draw")
local Ui = require("api.Ui")

local ICharaMakeSection = require("api.gui.menu.chara_make.ICharaMakeSection")
local UiList = require("api.gui.UiList")
local UiRaceInfo = require("api.gui.menu.chara_make.UiRaceInfo")
local UiWindow = require("api.gui.UiWindow")
local InputHandler = require("api.gui.InputHandler")
local IInput = require("api.gui.IInput")

local SelectClassMenu = class("SelectClassMenu", ICharaMakeSection)

SelectClassMenu:delegate("input", IInput)

function SelectClassMenu:init(race)
   self.width = 680
   self.height = 500

   self.race = race or "race"

   local classes = table.of(function(i) return "class" .. i end, 100)

   self.win = UiWindow:new("select_class.title")
   self.pages = UiList:new_paged(classes, 16)
   self.bg = Ui.random_cm_bg()

   self.chip_male = Draw.load_image("graphic/temp/chara_male.bmp")
   self.chip_female = Draw.load_image("graphic/temp/chara_female.bmp")

   self.race_info = UiRaceInfo:new(classes[1])

   self.input = InputHandler:new()
   self.input:forward_to(self.pages)
   self.input:bind_keys {
      shift = function() self.canceled = true end
   }

   self.caption = "Choose a class."
end

function SelectClassMenu:on_charamake_finish()
end

function SelectClassMenu:relayout()
   self.x, self.y = Ui.params_centered(self.width, self.height)
   self.y = self.y + 20

   self.win:relayout(self.x, self.y, self.width, self.height)
   self.pages:relayout(self.x + 38, self.y + 66)
   self.race_info:relayout(self.x, self.y)
   self.win:set_pages(self.pages)
end

function SelectClassMenu:draw()
   self.win:draw()
   Draw.image(self.bg,
              self.x + self.width / 4,
              self.y + self.height / 2,
              self.width / 5 * 2,
              self.height - 80,
              {255, 255, 255, 80},
              true)

   Draw.set_color()
   Ui.draw_topic("race", self.x + 28, self.y + 30)
   Ui.draw_topic("detail", self.x + 188, self.y + 30)

   self.pages:draw()

   Draw.set_color()
   Draw.image(self.chip_male, self.x + 380, self.y - self.chip_male:getHeight() + 60)
   Draw.image(self.chip_female, self.x + 350, self.y - self.chip_female:getHeight() + 60)

   Draw.set_color(0, 0, 0)
   Draw.text("race" .. ": " .. self.race, self.x + 460, self.y + 38)

   self.race_info:draw()
end

function SelectClassMenu:update()
   if self.pages.chosen then
      return self.pages:selected_item()
   elseif self.pages.changed then -- TODO remove
      local class = self.pages:selected_item()
      self.race_info:set_data(class)

      self.win:set_pages(self.pages)
   end

   if self.canceled then
      return nil, "canceled"
   end

   self.win:update()
   self.pages:update()
   self.race_info:update()
end

return SelectClassMenu