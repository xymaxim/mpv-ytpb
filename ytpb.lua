local mp = require("mp")
local options = require("mp.options")
local input = require("mp.input")
local state = {["current-mpd"] = nil, ["main-overlay"] = nil, ["mark-overlay"] = nil, ["marked-points"] = {}, ["current-mark"] = nil, ["activated?"] = false, ["mark-mode-enabled?"] = false}
local settings = {seek_offset = "10m"}
local key_binds = {}
local function b(value)
  return string.format("{\\b1}%s{\\b0}", value)
end
local function fs(size, value)
  return string.format("{\\fs%s}%s", size, value)
end
local function enable_mark_mode()
  if (nil == state["mark-overlay"]) then
    state["mark-overlay"] = mp.create_osd_overlay("ass-events")
  else
  end
  state["mark-mode-enabled?"] = true
  return nil
end
local function disable_mark_mode()
  state["mark-mode-enabled?"] = false
  state["marked-points"] = {}
  if (nil ~= state["mark-overlay"]) then
    return (state["mark-overlay"]):remove()
  else
    return nil
  end
end
local function render_mark_overlay()
  local point_labels = {"A", "B"}
  local content = "{\\an8}Mark mode\\N"
  for i, point in ipairs(state["marked-points"]) do
    local point_label
    local _3_
    if (i == state["current-mark"]) then
      _3_ = "(%s)"
    else
      _3_ = "\\h%s\\h"
    end
    point_label = string.format(_3_, point_labels[i])
    content = (content .. string.format("{\\an8}{\\fnmonospace}%s %s\\N", fs(28, point_label), fs(28, point.value)))
  end
  return content
end
local function display_mark_overlay()
  state["mark-overlay"].data = render_mark_overlay()
  return (state["mark-overlay"]):update()
end
local function mark_new_point()
  if not state["mark-mode-enabled?"] then
    enable_mark_mode()
  else
  end
  do
    local time_pos = tonumber(mp.get_property("time-pos"))
    local new_point = {value = time_pos, mpd = state["current-mpd"]}
    local _6_ = state["marked-points"]
    if (((_G.type(_6_) == "table") and (_6_[1] == nil)) or ((_G.type(_6_) == "table") and (nil ~= _6_[1]) and (nil ~= _6_[2]))) then
      state["marked-points"][1] = new_point
      state["current-mark"] = 1
      if b then
        state["marked-points"][2] = nil
      else
      end
    elseif ((_G.type(_6_) == "table") and (nil ~= _6_[1]) and (_6_[2] == nil)) then
      local a = _6_[1]
      if (time_pos >= a.value) then
        state["marked-points"][2] = new_point
        state["current-mark"] = 2
      else
        state["marked-points"] = {new_point, a}
        state["current-mark"] = 1
        mp.commandv("show-text", "Points swapped")
      end
    else
    end
  end
  return display_mark_overlay()
end
local function edit_point()
  do
    local time_pos = tonumber(mp.get_property("time-pos"))
    local new_point = {value = time_pos, mpd = state["current-mpd"]}
    state["marked-points"][state["current-mark"]] = new_point
    local _let_10_ = state["marked-points"]
    local a = _let_10_[1]
    local b0 = _let_10_[2]
    if (b0 and (a.value > b0.value)) then
      state["marked-points"] = {b0, a}
      if (time_pos == b0.value) then
        state["current-mark"] = 1
      else
        state["current-mark"] = 2
      end
      mp.commandv("show-text", "Points swapped")
    else
    end
  end
  return display_mark_overlay()
end
local function go_to_point(index)
  local _14_
  do
    local t_13_ = state["marked-points"]
    if (nil ~= t_13_) then
      t_13_ = t_13_[index]
    else
    end
    _14_ = t_13_
  end
  if _14_ then
    mp.set_property_native("pause", true)
    mp.commandv("seek", tostring(state["marked-points"][index].value), "absolute")
    state["current-mark"] = index
    return display_mark_overlay()
  else
    return mp.commandv("show-text", "Point not marked")
  end
end
local function render_column(column, keys_order)
  local right_margin = 10
  local main_font_size = 18
  local key_font_size = (1.2 * main_font_size)
  local rendered_lines = {}
  local max_key_length = 0
  local max_desc_length = 0
  for key, desc in pairs(column.keys) do
    do
      local key_length = #key
      if (key_length > max_key_length) then
        max_key_length = key_length
      else
      end
    end
    local desc_length = #desc
    if (desc_length > max_desc_length) then
      max_desc_length = desc_length
    else
    end
  end
  table.insert(rendered_lines, string.format("%s %s%s%s", fs(main_font_size, b(column.header)), fs(key_font_size, b(string.rep(" ", max_key_length))), fs(main_font_size, ""), string.rep(" ", (right_margin + (max_desc_length - #column.header)))))
  local aligned_key = nil
  for _, key in ipairs(keys_order) do
    local aligned_key0 = (string.rep("\\h", (max_key_length - #key)) .. key)
    local function _19_()
      local desc = column.keys[key]
      return string.format("%s%s%s", fs(key_font_size, b(aligned_key0)), fs(main_font_size, (" " .. desc)), string.rep(" ", (right_margin + (max_desc_length - #desc))))
    end
    table.insert(rendered_lines, _19_())
  end
  return rendered_lines
end
local function stack_columns(...)
  local lines = {}
  do
    local max_column_size
    local function _20_(...)
      local tbl_18_auto = {}
      local i_19_auto = 0
      for _, column in ipairs({...}) do
        local val_20_auto = #column
        if (nil ~= val_20_auto) then
          i_19_auto = (i_19_auto + 1)
          do end (tbl_18_auto)[i_19_auto] = val_20_auto
        else
        end
      end
      return tbl_18_auto
    end
    max_column_size = math.max(table.unpack(_20_(...)))
    for i = 1, max_column_size do
      local line = ""
      for _, column in pairs({...}) do
        local function _22_(...)
          local t_23_ = column
          if (nil ~= t_23_) then
            t_23_ = t_23_[i]
          else
          end
          return t_23_
        end
        line = (line .. (_22_() or string.format("{\\alpha&HFF&}%s{\\alpha&H00&}", column[1])))
      end
      table.insert(lines, line)
    end
  end
  return lines
end
local function display_main_overlay()
  local line_tags = "{\\an4}{\\fnmonospace}"
  local rewind_column = {header = "Rewind and seek", keys = {r = "rewind", ["</>"] = "seek backward/forward", O = "change seek offset"}}
  local mark_mode_column = {header = "Mark mode", keys = {m = "mark new point", e = "edit point", ["a/b"] = "go to point A/B"}}
  local other_column = {header = "Other", keys = {s = "take a screenshot", q = "quit"}}
  local rewind_column_lines = render_column(rewind_column, {"r", "</>", "O"})
  local mark_mode_column_lines = render_column(mark_mode_column, {"m", "e", "a/b"})
  local other_column_lines = render_column(other_column, {"s", "q"})
  do
    local stacked_columns = stack_columns(rewind_column_lines, mark_mode_column_lines, other_column_lines)
    local _25_
    do
      local tbl_18_auto = {}
      local i_19_auto = 0
      for _, line in ipairs(stacked_columns) do
        local val_20_auto = string.format("{\\an4}{\\fnmonospace}%s", line)
        if (nil ~= val_20_auto) then
          i_19_auto = (i_19_auto + 1)
          do end (tbl_18_auto)[i_19_auto] = val_20_auto
        else
        end
      end
      _25_ = tbl_18_auto
    end
    state["main-overlay"].data = table.concat(_25_, "\\N")
  end
  return (state["main-overlay"]):update()
end
local function rewind_key_handler()
  local now = os.date("%Y%m%dT%H%z")
  local function _27_(value)
    mp.commandv("script-message", "yp:rewind", value)
    return input.terminate()
  end
  return input.get({prompt = "Rewind date:", default_text = now, cursor_position = 12, submit = _27_})
end
local function seek_forward_key_handler()
  return mp.commandv("script-message", "yp:seek", settings.seek_offset)
end
local function seek_backward_key_handler()
  return mp.commandv("script-message", "yp:seek", ("-" .. settings.seek_offset))
end
local function change_seek_offset_key_handler()
  local function submit_function(value)
    if string.find(value, "[dhms]") then
      settings.seek_offset = value
      return input.terminate()
    else
      return input.log_error("Invalid value, should be [%dd][%Hh][%Mm][%Ss]")
    end
  end
  return input.get({prompt = "New seek offset:", default_text = settings.seek_offset, submit = submit_function})
end
local function take_screenshot_key_handler()
  return mp.commandv("script-message", "yp:take-screenshot")
end
local function update_current_mpd()
  state["current-mpd"] = {path = mp.get_property("path")}
  return nil
end
local function deactivate()
  state["activated?"] = false
  disable_mark_mode()
  do end (state["main-overlay"]):remove()
  for _, _29_ in pairs(key_binds) do
    local _each_30_ = _29_
    local name = _each_30_[1]
    local _0 = _each_30_[2]
    mp.remove_key_binding(name)
  end
  return nil
end
local function activate()
  state["activated?"] = true
  key_binds["r"] = {"rewind", rewind_key_handler}
  key_binds["<"] = {"seek-backward", seek_backward_key_handler}
  key_binds[">"] = {"seek-forward", seek_forward_key_handler}
  key_binds["O"] = {"change-seek-offset", change_seek_offset_key_handler}
  key_binds["m"] = {"mark-new-point", mark_new_point}
  local function _31_()
    if state["mark-mode-enabled?"] then
      return edit_point()
    else
      return mp.commandv("show-text", "No marked points")
    end
  end
  key_binds["e"] = {"edit-point", _31_}
  local function _33_()
    return go_to_point(1)
  end
  key_binds["a"] = {"go-to-point-A", _33_}
  local function _34_()
    return go_to_point(2)
  end
  key_binds["b"] = {"go-to-point-B", _34_}
  key_binds["s"] = {"take-screenshot", take_screenshot_key_handler}
  key_binds["q"] = {"quit", deactivate}
  for key, _35_ in pairs(key_binds) do
    local _each_36_ = _35_
    local name = _each_36_[1]
    local func = _each_36_[2]
    mp.add_forced_key_binding(key, name, func)
  end
  state["main-overlay"] = mp.create_osd_overlay("ass-events")
  return display_main_overlay()
end
local function _37_()
  if not state["activated?"] then
    return activate()
  else
    return nil
  end
end
mp.add_forced_key_binding("Ctrl+p", "activate", _37_)
return mp.add_hook("on_load", 50, update_current_mpd)
