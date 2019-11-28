local Chara = require("game.Chara")
local I18N = require("game.I18N")
local World = require("game.World")

return {
   id = "orphe",
   root = "core.talk.unique.orphe",

   nodes = {
      __start = function()
         if World.deferred_event_id() == 1 then
            return "dialog"
         end

         return "__IGNORED__"
      end,
      dialog = {
         text = {
            {"dialog._0", args = function()
                local sex
                if Chara.player().sex == "Female" then
                   sex = 1
                else
                   sex = 0
                end
                return {I18N.get_enum("core.ui.sex", sex)}
            end},
            {"dialog._1"},
            {"dialog._2"},
            {"dialog._3"},
            {"dialog._4"},
            {"dialog._5"},
         }
      }
   }
}
