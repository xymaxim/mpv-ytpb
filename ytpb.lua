local mp = require("mp")
local msg = require("mp.msg")
local options = require("mp.options")
local input = require("mp.input")
local state = {["current-mpd-path"] = nil, ["current-start-time"] = nil, ["main-overlay"] = nil, ["mark-overlay"] = nil, ["marked-points"] = {}, ["current-mark"] = nil, ["clock-overlay"] = nil, ["clock-timer"] = nil, ["activated?"] = false, ["mark-mode-enabled?"] = false}
local settings = {seek_offset = "10m", ["utc-offset"] = nil}
if (nil == settings["utc-offset"]) then
  local local_offset = (os.time() - os.time(os.date("!*t")))
  settings["utc-offset"] = local_offset
else
end
local key_binds = {}
local Point = {}
Point.new = function(self, time_pos, start_time, mpd_path)
  _G.assert((nil ~= mpd_path), "Missing argument mpd-path on ytpb.fnl:26")
  _G.assert((nil ~= start_time), "Missing argument start-time on ytpb.fnl:26")
  _G.assert((nil ~= time_pos), "Missing argument time-pos on ytpb.fnl:26")
  _G.assert((nil ~= self), "Missing argument self on ytpb.fnl:26")
  local obj = {["time-pos"] = time_pos, ["start-time"] = start_time, ["mpd-path"] = mpd_path}
  obj.timestamp = (obj["start-time"] + obj["time-pos"])
  setmetatable(obj, self)
  self.__index = self
  return obj
end
Point.format = function(self, _3futc_offset)
  _G.assert((nil ~= self), "Missing argument self on ytpb.fnl:33")
  return os.date("!%Y-%m-%d %H:%M:%S", (self.timestamp + (_3futc_offset or 0)))
end
local function b(value)
  return string.format("{\\b1}%s{\\b0}", value)
end
local function fs(size, value)
  return string.format("{\\fs%s}%s", size, value)
end
local function timestamp__3eisodate(value)
  return os.date("!%Y%m%dT%H%M%S%z", value)
end
local function parse_mpd_start_time(content)
  local function isodate__3etimestamp(value)
    local offset = (os.time() - os.time(os.date("!*t")))
    local pattern = "(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)+00:00"
    local year, month, day, hour, min, sec = string.match(value, pattern)
    local sec0 = (sec + offset)
    return os.time({year = year, month = month, day = day, hour = hour, min = min, sec = sec0})
  end
  local _, _0, start_time_str = content:find("availabilityStartTime=\"(.+)\"")
  return isodate__3etimestamp(start_time_str)
end
local function update_current_mpd()
  state["current-mpd-path"] = mp.get_property("path")
  local _2_ = io.open(state["current-mpd-path"])
  if (nil ~= _2_) then
    local f = _2_
    state["current-start-time"] = parse_mpd_start_time(f:read("*all"))
    return f:close()
  else
    return nil
  end
end
local function format_clock_time_string(timestamp)
  local date_time_part = os.date("!%Y-%m-%d %H:%M:%S", (timestamp + settings["utc-offset"]))
  local hours = math.floor((settings["utc-offset"] / 3600))
  local minutes = math.floor(((settings["utc-offset"] % 3600) / 60))
  local hh_part = string.format("%+03d", hours)
  local function _4_()
    if (0 > minutes) then
      return string.format(":%02d", minutes)
    else
      return ""
    end
  end
  return (string.format("%s%s", date_time_part, hh_part) .. _4_())
end
local function draw_clock()
  local time_pos = mp.get_property_native("time-pos", 0)
  local time_string = format_clock_time_string((time_pos + state["current-start-time"]))
  local ass_text = string.format("{\\an9\\bord10\\3c&H908070&}%s", time_string)
  state["clock-overlay"].data = ass_text
  return (state["clock-overlay"]):update()
end
local function start_clock()
  state["clock-overlay"] = mp.create_osd_overlay("ass-events")
  draw_clock()
  state["clock-timer"] = mp.add_periodic_timer(1, draw_clock)
  return nil
end
local function stop_clock()
  do end (state["clock-timer"]):stop()
  return (state["clock-overlay"]):remove()
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
  local lines = {"{\\an8}Mark mode"}
  for i, point in ipairs(state["marked-points"]) do
    local point_label_template
    if (i == state["current-mark"]) then
      point_label_template = "(%s)"
    else
      point_label_template = "\\h%s\\h"
    end
    local point_label = string.format(point_label_template, point_labels[i])
    local point_string = point:format(settings["utc-offset"])
    table.insert(lines, string.format("{\\an8}{\\fnmonospace}%s %s", fs(28, point_label), fs(28, point_string)))
  end
  return table.concat(lines, "\\N")
end
local function display_mark_overlay()
  state["mark-overlay"].data = render_mark_overlay()
  return (state["mark-overlay"]):update()
end
local function mark_new_point()
  local cache_state = mp.get_property_native("demuxer-cache-state")
  if not state["mark-mode-enabled?"] then
    enable_mark_mode()
  else
  end
  do
    local time_pos = mp.get_property_native("time-pos")
    local new_point = Point:new(time_pos, state["current-start-time"], state["current-mpd-path"])
    local _9_ = state["marked-points"]
    if (((_G.type(_9_) == "table") and (_9_[1] == nil)) or ((_G.type(_9_) == "table") and (nil ~= _9_[1]) and (nil ~= _9_[2]))) then
      state["marked-points"][1] = new_point
      state["current-mark"] = 1
      if b then
        state["marked-points"][2] = nil
      else
      end
    elseif ((_G.type(_9_) == "table") and (nil ~= _9_[1]) and (_9_[2] == nil)) then
      local a = _9_[1]
      if (new_point.timestamp >= a.timestamp) then
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
    local time_pos = mp.get_property_native("time-pos")
    local new_point = Point:new(time_pos, state["current-start-time"], state["current-mpd-path"])
    local time_string = new_point:format(settings["utc-offset"])
    do end (state["marked-points"])[state["current-mark"]] = new_point
    local _let_13_ = state["marked-points"]
    local a = _let_13_[1]
    local b0 = _let_13_[2]
    if (b0 and (a.timestamp > b0.timestamp)) then
      state["marked-points"] = {b0, a}
      if (timestamp == b0.timestamp) then
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
local function request_rewind(timestamp)
  mp.osd_message("Rewinding...", 999)
  mp.set_property_native("pause", true)
  if (state["clock-timer"]):is_enabled() then
    stop_clock()
  else
  end
  return mp.commandv("script-message", "yp:rewind", timestamp)
end
local function go_to_point(index)
  local point
  do
    local t_17_ = state["marked-points"]
    if (nil ~= t_17_) then
      t_17_ = t_17_[index]
    else
    end
    point = t_17_
  end
  if point then
    mp.set_property_native("pause", true)
    do
      local mpd_start_time = point["start-time"]
      if (state["current-mpd-path"] == point["mpd-path"]) then
        mp.commandv("seek", tostring(point["time-pos"]), "absolute")
      else
        request_rewind(timestamp__3eisodate(point.timestamp))
      end
    end
    state["current-mark"] = index
    display_mark_overlay()
    if (state["clock-timer"]):is_enabled() then
      return draw_clock()
    else
      return nil
    end
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
    local function _24_()
      local desc = column.keys[key]
      return string.format("%s%s%s", fs(key_font_size, b(aligned_key0)), fs(main_font_size, (" " .. desc)), string.rep(" ", (right_margin + (max_desc_length - #desc))))
    end
    table.insert(rendered_lines, _24_())
  end
  return rendered_lines
end
local function stack_columns(...)
  local lines = {}
  do
    local max_column_size
    local function _25_(...)
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
    max_column_size = math.max(table.unpack(_25_(...)))
    for i = 1, max_column_size do
      local line = ""
      for _, column in pairs({...}) do
        local function _27_(...)
          local t_28_ = column
          if (nil ~= t_28_) then
            t_28_ = t_28_[i]
          else
          end
          return t_28_
        end
        line = (line .. (_27_() or string.format("{\\alpha&HFF&}%s{\\alpha&H00&}", column[1])))
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
  local other_column = {header = "Other", keys = {s = "take a screenshot", C = "toggle clock", T = "change timezone", q = "quit"}}
  local rewind_column_lines = render_column(rewind_column, {"r", "</>", "O"})
  local mark_mode_column_lines = render_column(mark_mode_column, {"m", "e", "a/b"})
  local other_column_lines = render_column(other_column, {"s", "C", "T", "q"})
  do
    local stacked_columns = stack_columns(rewind_column_lines, mark_mode_column_lines, other_column_lines)
    local _30_
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
      _30_ = tbl_18_auto
    end
    state["main-overlay"].data = table.concat(_30_, "\\N")
  end
  return (state["main-overlay"]):update()
end
local function rewind_key_handler()
  local now = os.date("!%Y%m%dT%H%z")
  local function _32_(value)
    request_rewind(value)
    return input.terminate()
  end
  return input.get({prompt = "Rewind date:", default_text = now, cursor_position = 12, submit = _32_})
end
local function rewind_finished_handler(mpd_path, time_pos)
  mp.set_property_native("pause", true)
  local function seek_after_restart()
    mp.unregister_event(seek_after_restart)
    local time_pos0 = tonumber(time_pos)
    local seek_timer = nil
    local function try_to_seek()
      local cache_state = mp.get_property_native("demuxer-cache-state")
      if (0 ~= #cache_state["seekable-ranges"]) then
        seek_timer:kill()
        local function _33_()
          if state["clock-timer"] then
            draw_clock()
            do end (state["clock-timer"]):resume()
          else
          end
          return mp.osd_message("")
        end
        return mp.command_native_async({"seek", time_pos0, "absolute"}, _33_)
      else
        return nil
      end
    end
    seek_timer = mp.add_periodic_timer(0.25, try_to_seek)
    return nil
  end
  return mp.register_event("playback-restart", seek_after_restart)
end
mp.register_script_message("yp:rewind-finished", rewind_finished_handler)
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
local function toggle_clock_key_handler()
  if (state["clock-timer"]):is_enabled() then
    do end (state["clock-timer"]):kill()
    return (state["clock-overlay"]):remove()
  else
    draw_clock()
    return (state["clock-timer"]):resume()
  end
end
local function change_timezone_key_handler()
  local function _38_(value)
    settings["utc-offset"] = (3600 * (tonumber(value) or 0))
    draw_clock()
    if state["mark-mode-enabled?"] then
      display_mark_overlay()
    else
    end
    return input.terminate()
  end
  return input.get({prompt = "New timezone offset: UTC", default_text = "+00", cursor_position = 4, submit = _38_})
end
local function deactivate()
  state["activated?"] = false
  if state["mark-mode-enabled?"] then
    do end (state["mark-overlay"]):remove()
  else
  end
  do end (state["main-overlay"]):remove()
  for _, _41_ in pairs(key_binds) do
    local _each_42_ = _41_
    local name = _each_42_[1]
    local _0 = _each_42_[2]
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
  local function _43_()
    if state["mark-mode-enabled?"] then
      return edit_point()
    else
      return mp.commandv("show-text", "No marked points")
    end
  end
  key_binds["e"] = {"edit-point", _43_}
  local function _45_()
    return go_to_point(1)
  end
  key_binds["a"] = {"go-to-point-A", _45_}
  local function _46_()
    return go_to_point(2)
  end
  key_binds["b"] = {"go-to-point-B", _46_}
  key_binds["s"] = {"take-screenshot", take_screenshot_key_handler}
  key_binds["C"] = {"toggle-clock", toggle_clock_key_handler}
  key_binds["T"] = {"change-timezone", change_timezone_key_handler}
  key_binds["q"] = {"quit", deactivate}
  for key, _47_ in pairs(key_binds) do
    local _each_48_ = _47_
    local name = _each_48_[1]
    local func = _each_48_[2]
    mp.add_forced_key_binding(key, name, func)
  end
  state["main-overlay"] = mp.create_osd_overlay("ass-events")
  display_main_overlay()
  if state["mark-mode-enabled?"] then
    return display_mark_overlay()
  else
    return nil
  end
end
local function _50_()
  if not state["activated?"] then
    return activate()
  else
    return nil
  end
end
mp.add_forced_key_binding("Ctrl+p", "activate", _50_)
local function on_file_loaded()
  update_current_mpd()
  if (nil == state["clock-timer"]) then
    return start_clock()
  else
    return nil
  end
end
return mp.register_event("file-loaded", on_file_loaded)
