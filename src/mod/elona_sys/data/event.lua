local event = {
      { _id = "on_apply_effect" },
      { _id = "on_heal_effect" },
      { _id = "calc_effect_power" },
      { _id = "on_player_bumped_into_chara", },
      { _id = "before_player_map_leave" },
      { _id = "on_bump_into" },
      { _id = "on_quest_check" },
      { _id = "on_item_use" },
      { _id = "on_item_eat" },
      { _id = "on_item_drink" },
      { _id = "on_item_read" },
      { _id = "on_item_zap" },
      { _id = "on_item_open" },
      { _id = "on_item_dip_source" },
      { _id = "on_item_throw" },
      { _id = "on_bash" },
      { _id = "on_search" },
      { _id = "on_feat_activate" },
      { _id = "on_feat_search" },
      { _id = "on_feat_open" },
      { _id = "on_feat_close" },
      { _id = "on_feat_descend" },
      { _id = "on_feat_ascend" },
      { _id = "on_feat_bumped_into" },
      { _id = "on_feat_stepped_on" },
      { _id = "on_quest_completed" },
      { _id = "on_quest_failed" },
      { _id = "calc_map_music" },
      { _id = "on_step_dialog" },
      { _id = "on_mef_stepped_on" },
      { _id = "on_mef_stepped_off" },
      { _id = "on_item_memorize_generated" },
      { _id = "on_item_memorize_known" },
      { _id = "on_item_check_generated" },
      { _id = "on_item_check_known" },
      { _id = "on_gain_skill_exp" },
      { _id = "on_travel_to_outer_map" },
      { _id = "on_get" }
}

data:add_multi("base.event", event)
