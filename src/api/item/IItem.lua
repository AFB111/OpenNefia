local EquipSlots = require("api.EquipSlots")
local Event = require("api.Event")
local IItemEnchantments = require("api.item.IItemEnchantments")
local IMapObject = require("api.IMapObject")
local IObject = require("api.IObject")
local IModdable = require("api.IModdable")
local IEventEmitter = require("api.IEventEmitter")
local IStackableObject = require("api.IStackableObject")
local Log = require("api.Log")
local data = require("internal.data")

-- TODO: move out of api
local IItem = class.interface("IItem",
                         {},
                         {IStackableObject, IModdable, IItemEnchantments, IEventEmitter})

-- TODO: schema
local defaults = {
   amount = 1,
   dice_x = 0,
   dice_y = 0,
   ownership = "none",
   curse_state = "none",
   identify_state = "completely",
   weight = 0,
   dv = 0,
   pv = 0,
   hit_bonus = 0,
   damage_bonus = 0,
   bonus = 0,
   flags = {},
   name = "item",
   pierce_rate = 0,
   effective_range = {100, 20, 20, 20, 20, 20, 20, 20, 20, 20},
   ammo_type = "",
   value = 1,
   params = {},
   types = {}
}
table.merge(IItem, defaults)

function IItem:pre_build()
   -- TODO remove and place in schema as defaults
   IModdable.init(self)
   IMapObject.init(self)
   IEventEmitter.init(self)

   self.location = nil
   self.ownership = self.ownership or "none"

   local Rand = require("api.Rand")
   self.curse_state = self.curse_state or Rand.choice({"cursed", "blessed", "none", "doomed"})
   self.identify_state = self.identify_state or "completely"

   self.name = self._id

   self.weight = 10
   self.dv = 4
   self.pv = 4
   self.hit_bonus = 3
   self.damage_bonus = 2
   self.bonus = 1

   self:set_image()

   IItemEnchantments.init(self)
end

function IItem:normal_build()
end

function IItem:build()
   self:emit("base.on_build_item")
end

function IItem:instantiate()
   IObject.instantiate(self)
   Event.trigger("base.on_item_instantiated", {item=self})
end

function IItem:set_image(image)
   if image then
      self.image = image
      local chip = data["base.chip"][self.image]
      self.y_offset = chip.y_offset
   else
      self.image = self.proto.image
      local chip = data["base.chip"][self.proto.image]
      if chip then
         self.y_offset = chip.y_offset
      end
   end
end

function IItem:build_name(amount)
   amount = amount or self.amount

   local s = self.name
   if amount ~= 1 then
      s = string.format("%d %s", amount, self.name)
   end

   local b = self:calc("bonus")
   if b > 0 then
      s = s .. " +" .. b
   elseif b < 0 then
      s = s .. " " .. b
   end

   return s
end

local function is_weapon(item)
   return not item:is_equipped_at("elona.ranged")
      and not item:is_equipped_at("elona.ammo")
      and item:calc("dice_x") > 0
end

function IItem:refresh()
   IModdable.on_refresh(self)
   IMapObject.on_refresh(self)
   IItemEnchantments.on_refresh(self)

   self:mod("is_weapon", is_weapon(self))
   self:mod("is_armor", self:calc("dice_x") == 0)
end

function IItem:on_refresh()
end

function IItem:get_owning_chara()
   local IChara = require("api.chara.IChara")

   if class.is_an(IChara, self.location) then
      if self.location:has_item(self) then
         return self.location
      end
   end

   return nil
end

function IItem:produce_memory()
   return { image = self.image, color = {0, 0, 0} }
end

function IItem:is_blessed()
   return self:calc("curse_state") == "blessed"
end

function IItem:is_cursed()
   local curse_state = self:calc("curse_state")
   return curse_state == "cursed" or curse_state == "doomed"
end

function IItem:current_map()
   -- BUG: Needs to be generalized to allow nesting.
   local Chara = require("api.Chara")
   local chara = self:get_owning_chara()
   if Chara.is_alive(chara) then
      return chara:current_map()
   end

   return IMapObject.current_map(self)
end

function IItem:can_equip_at(body_part_type)
   local equip_slots = self:calc("equip_slots") or {}
   if #equip_slots == 0 then
      return nil
   end

   local can_equip = table.set(equip_slots)

   return can_equip[body_part_type] == true
end

function IItem:is_equipped()
   return class.is_an(EquipSlots, self.location)
end

function IItem:is_equipped_at(body_part_type)
   if not self:is_equipped() then
      return false
   end

   local slot = self.location:equip_slot_of(self)

   return slot and slot.type == body_part_type
end

function IItem:remove_activity()
   if not self.chara_using then
      return
   end

   self.chara_using:remove_activity()
   self.chara_using = nil
end

function IItem:copy_image()
   local item_atlas = require("internal.global.atlases").get().item
   return item_atlas:copy_tile_image(self:calc("image") .. "#1")
end

function IItem:can_stack_with(other)
   -- TODO: this gets super complicated when adding new fields. There
   -- should be a way to specify a field will not have any effect on
   -- the stacking behavior between two objects.
   if not IStackableObject.can_stack_with(self, other) then
      return false
   end

   local ignored_fields = table.set {
      "uid",
      "amount",
      "temp"
   }

   for field, my_val in pairs(self) do
      if not ignored_fields[field] then
         local their_val = other[field]

         -- TODO: is_class, is_object
         local do_deepcompare = type(my_val) == "table"
            and type(their_val) == "table"
            and my_val.__class == nil
            and my_val.uid == nil

         if do_deepcompare then
            if not #my_val == #their_val then
               return false, field
            end
            Log.trace("Stack: deepcomparing %s", field)
            if not table.deepcompare(my_val, their_val) then
               return false, field
            end
         else
            if my_val ~= their_val then
               return false, field
            end
         end
      end
   end

   return true
end

function IItem:has_type(_type)
   for _, v in ipairs(self:calc("types")) do
      if v == _type then
         return true
      end
   end
   return false
end

function IItem:calc_effective_range(dist)
   dist = math.max(math.floor(dist), 0)
   local result
   local effective_range = self:calc("effective_range")
   if type(effective_range) == "function" then
      result = effective_range(self, dist)
      assert(type(result) == "number", "effective_range must return a number")
   elseif type(effective_range) == "table" then
      result = effective_range[dist]
      if not result then
         -- vanilla compat
         result = effective_range[math.min(dist, 9)]
      end
   elseif type(effective_range) == "number" then
      result = effective_range
   end
   return result or 100
end

function IItem:calc_ui_color()
   local color = self:calc("ui_color")
   if color then return color end

   if self:calc("flags").is_no_drop then
        return {120, 80, 0}
   end

   if self:calc("identify_state") == "completely" then
      local curse_state = self:calc("curse_state")
      if     curse_state == "doomed"  then return {100, 10, 100}
      elseif curse_state == "cursed"  then return {150, 10, 10}
      elseif curse_state == "none"    then return {10, 40, 120}
      elseif curse_state == "blessed" then return {10, 110, 30}
      end
   end

    return {0, 0, 0}
end

return IItem
