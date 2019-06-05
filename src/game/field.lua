local internal = require("internal")
local startup = require("game.startup")

local Chara = require("api.Chara")
local Command = require("api.Command")
local Draw = require("api.Draw")
local Map = require("api.Map")
local Input = require("api.Input")
local InputHandler = require("api.gui.InputHandler")
local GameKeyHandler = require("api.gui.GameKeyHandler")

local field = {}
field.active = false
field.draw_x = 0
field.draw_y = 0

local batches = {}

local me

local tile_size = 48

function field.query()
   local dt = 0
   local going = true

   field.active = true

   local hud = require("api.gui.hud.MainHud"):new()
   internal.draw.set_hud(hud)

   local coords = require("internal.draw.coords.tiled_coords"):new()

   local uid = require("internal.uid_tracker"):new()
   local pool = require("internal.pool"):new("base.chara", uid)

   me = pool:generate {
      batch_ind = 0,
      tile = 3,
      x = 0,
      y = 0
   }

   batches = startup.load_batches(coords)
   local keys = InputHandler:new()
   keys:focus()
   keys:bind_keys {
      a = function()
         print("do")
      end,
      up = function()
         Command.move(me, "North")
         batches["map"].updated = true
         batches["chara"].updated = true
      end,
      down = function()
         Command.move(me, "South")
         batches["map"].updated = true
         batches["chara"].updated = true
      end,
      left = function()
         Command.move(me, "East")
         batches["map"].updated = true
         batches["chara"].updated = true
      end,
      right = function()
         Command.move(me, "West")
         batches["map"].updated = true
         batches["chara"].updated = true
      end,
      escape = function()
         if Input.yes_no() then
            going = false
         end
      end,
      ["return"] = function()
         print(require("api.gui.TextPrompt"):new(16):query())
      end,
   }

   internal.draw.set_root_input_handler(keys)

   while going do
      keys:run_actions()

      field.draw_x, field.draw_y = coords:get_draw_pos(me.x, me.y, Map.width(), Map.height())

      dt = coroutine.yield()
   end

   field.active = false

   return "title"
end

local px = -1
local py = -1

local function update_chara_batch(chara)
   if chara.x ~= px or chara.y ~= py then
      if chara.batch_ind > 0 then
         batches["chara"]:remove_tile(chara.batch_ind)
      end
      chara.batch_ind = batches["chara"]:add_tile {
         tile = chara.tile,
         x = chara.x,
         y = chara.y
                                                  }

      px = chara.x
      py = chara.y
   end
end

function field.draw()
   update_chara_batch(me)

   local draw_x = field.draw_x
   local draw_y = field.draw_y

   batches["map"]:draw(draw_x, draw_y)
   -- blood, fragments
   -- efmap
   -- nefia icons
   -- mefs
   -- items
   batches["chara"]:draw(draw_x, draw_y)
   -- light
   -- cloud
   -- shadow

   internal.draw.draw_hud()
end

return field
