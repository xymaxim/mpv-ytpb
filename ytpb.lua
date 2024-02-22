local mp = require("mp")
local msg = require("mp.msg")
local options = require("mp.options")
local input = require("mp.input")
local theme = {["main-menu-color"] = "ffffff", ["main-menu-font-size"] = 18, ["mark-mode-color"] = "ffc66e", ["mark-mode-font-size"] = 28, ["clock-color"] = "ffffff", ["clock-font-size"] = 32}
local state = {["current-mpd-path"] = nil, ["current-start-time"] = nil, ["main-overlay"] = nil, ["mark-overlay"] = nil, ["marked-points"] = {}, ["current-mark"] = nil, ["clock-overlay"] = nil, ["clock-timer"] = nil, ["activated?"] = false, ["mark-mode-enabled?"] = false}
local settings = {["seek-offset"] = 3600, ["utc-offset"] = nil}
if (nil == settings["utc-offset"]) then
  local local_offset = (os.time() - os.time(os.date("!*t")))
  settings["utc-offset"] = local_offset
else
end
local main_menu_map = nil
local display_main_overlay = nil
local Point = {}
Point.new = function(self, time_pos, start_time, mpd_path)
  _G.assert((nil ~= mpd_path), "Missing argument mpd-path on ytpb.fnl:34")
  _G.assert((nil ~= start_time), "Missing argument start-time on ytpb.fnl:34")
  _G.assert((nil ~= time_pos), "Missing argument time-pos on ytpb.fnl:34")
  _G.assert((nil ~= self), "Missing argument self on ytpb.fnl:34")
  local obj = {["time-pos"] = time_pos, ["start-time"] = start_time, ["mpd-path"] = mpd_path}
  obj.timestamp = (obj["start-time"] + obj["time-pos"])
  obj["rewound?"] = false
  setmetatable(obj, self)
  self.__index = self
  return obj
end
Point.format = function(self, _3futc_offset)
  _G.assert((nil ~= self), "Missing argument self on ytpb.fnl:42")
  local seconds = (math.floor(self.timestamp) + (_3futc_offset or 0))
  local milliseconds = (self.timestamp % 1)
  return (os.date("!%Y-%m-%d %H:%M:%S", seconds) .. "." .. string.sub(string.format("%.3f", milliseconds), 3))
end
local function ass(...)
  return string.format("{%s}", table.concat({...}))
end
local function ass_b(value)
  return string.format("{\\b1}%s{\\b0}", value)
end
local function ass_fs(size, value)
  return string.format("{\\fs%s}%s", size, value)
end
local function ass_fs_2a(size)
  return string.format("\\fs%s", size)
end
local function rgb__3ebgr(value)
  local r, g, b = string.match(value, "(%w%w)(%w%w)(%w%w)")
  return (b .. g .. r)
end
local function ass_c_2a(rgb, _3ftag_prefix)
  return string.format("\\%dc&H%s&", (_3ftag_prefix or 1), rgb__3ebgr(rgb))
end
local function ass_c(rgb, _3ftag_prefix)
  return string.format("{%s}", ass_c_2a(rgb, _3ftag_prefix))
end
local function timestamp__3eisodate(value)
  return os.date("!%Y%m%dT%H%M%S%z", value)
end
local function parse_mpd_start_time(content)
  local function isodate__3etimestamp(value)
    local offset = (os.time() - os.time(os.date("!*t")))
    local pattern = "(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)%.?(%d*)+00:00"
    local year, month, day, hour, min, sec, ms = string.match(value, pattern)
    local sec0 = (sec + offset)
    local ms0 = tonumber(ms)
    local function _2_()
      if ms0 then
        return (ms0 / 1000)
      else
        return 0
      end
    end
    return (os.time({year = year, month = month, day = day, hour = hour, min = min, sec = sec0}) + _2_())
  end
  local _, _0, start_time_str = content:find("availabilityStartTime=\"([^\"]+)\"")
  return isodate__3etimestamp(start_time_str)
end
local function update_current_mpd()
  state["current-mpd-path"] = mp.get_property("path")
  local _3_ = io.open(state["current-mpd-path"])
  if (nil ~= _3_) then
    local f = _3_
    state["current-start-time"] = parse_mpd_start_time(f:read("*all"))
    return f:close()
  else
    return nil
  end
end
local function seek_offset__3eseconds(value)
  local total_seconds = 0
  do
    local pattern = "(%d+%.?%d*)(%a*)"
    local symbols = {d = 86400, h = 3600, m = 60, s = 1}
    for number, symbol in string.gmatch(value, pattern) do
      local function _5_()
        local x = symbol
        return symbols[x]
      end
      if ((nil ~= symbol) and _5_()) then
        local x = symbol
        total_seconds = (total_seconds + (number * symbols[x]))
      elseif (symbol == "") then
        error({msg = "Time symbol is missing"})
      else
        local _ = symbol
        error({msg = ("Unknown time symbol: " .. symbol)})
      end
    end
  end
  return total_seconds
end
local function format_clock_time_string(timestamp)
  local date_time_part = os.date("!%Y\226\128\147%m\226\128\147%d %H:%M:%S", (timestamp + settings["utc-offset"]))
  local hours = math.floor((settings["utc-offset"] / 3600))
  local minutes = math.floor(((settings["utc-offset"] % 3600) / 60))
  local hh_part = string.format("%+03d", hours)
  local function _7_()
    if (0 > minutes) then
      return string.format(":%02d", minutes)
    else
      return ""
    end
  end
  return (string.format("%s %s", date_time_part, hh_part) .. _7_())
end
local function draw_clock()
  local time_pos = mp.get_property_native("time-pos", 0)
  local time_string = format_clock_time_string((time_pos + state["current-start-time"]))
  local ass_text = (ass("\\an9\\bord2", ass_c_2a(theme["clock-color"]), ass_fs_2a(theme["clock-font-size"])) .. time_string)
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
  local header_font_size = (1.2 * theme["mark-mode-font-size"])
  local point_labels = {"A", "B"}
  local lines = {string.format("%sMark mode%s", ass("\\an8\\bord2", ass_fs_2a(header_font_size), ass_c_2a(theme["mark-mode-color"])), ass_c("FFFFFF"))}
  for i, point in ipairs(state["marked-points"]) do
    local point_label_template
    if (i == state["current-mark"]) then
      point_label_template = "(%s)"
    else
      point_label_template = "\\h%s\\h"
    end
    local point_label = string.format(point_label_template, point_labels[i])
    local point_string = point:format(settings["utc-offset"])
    table.insert(lines, string.format("{\\an8\\fnmonospace}%s %s", ass_fs(theme["mark-mode-font-size"], point_label), ass_fs(theme["mark-mode-font-size"], point_string)))
  end
  return table.concat(lines, "\\N")
end
local function display_mark_overlay()
  state["mark-overlay"].data = render_mark_overlay()
  return (state["mark-overlay"]):update()
end
local function mark_new_point()
  if not state["mark-mode-enabled?"] then
    enable_mark_mode()
    display_main_overlay()
  else
  end
  do
    local time_pos = mp.get_property_native("time-pos")
    local new_point = Point:new(time_pos, state["current-start-time"], state["current-mpd-path"])
    local _12_ = state["marked-points"]
    if (((_G.type(_12_) == "table") and (_12_[1] == nil)) or ((_G.type(_12_) == "table") and (nil ~= _12_[1]) and (nil ~= _12_[2]))) then
      state["marked-points"][1] = new_point
      state["current-mark"] = 1
      if state["marked-points"][2] then
        state["marked-points"][2] = nil
      else
      end
    elseif ((_G.type(_12_) == "table") and (nil ~= _12_[1]) and (_12_[2] == nil)) then
      local a = _12_[1]
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
local function edit_current_point()
  if (nil == state["current-mark"]) then
    return mp.commandv("show-text", "No marked points")
  else
    do
      local time_pos = mp.get_property_native("time-pos")
      local new_point = Point:new(time_pos, state["current-start-time"], state["current-mpd-path"])
      local time_string = new_point:format(settings["utc-offset"])
      do end (state["marked-points"])[state["current-mark"]] = new_point
      local _let_16_ = state["marked-points"]
      local a = _let_16_[1]
      local b = _let_16_[2]
      if (b and (a.timestamp > b.timestamp)) then
        state["marked-points"] = {b, a}
        if (new_point.timestamp == b.timestamp) then
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
end
local function register_seek_after_restart(time_pos)
  local function seek_after_restart()
    mp.unregister_event(seek_after_restart)
    local time_pos0 = tonumber(time_pos)
    local seek_timer = nil
    local function try_to_seek()
      local cache_state = mp.get_property_native("demuxer-cache-state")
      if (0 ~= #cache_state["seekable-ranges"]) then
        seek_timer:kill()
        local function callback(name, value)
          if (value == true) then
            return
          else
          end
          mp.unobserve_property(callback)
          if state["clock-timer"] then
            draw_clock()
            do end (state["clock-timer"]):resume()
            return mp.osd_message("")
          else
            return nil
          end
        end
        mp.observe_property("seeking", "bool", callback)
        return mp.commandv("seek", time_pos0, "absolute")
      else
        return nil
      end
    end
    seek_timer = mp.add_periodic_timer(0.2, try_to_seek)
    return nil
  end
  return mp.register_event("playback-restart", seek_after_restart)
end
local function load_and_seek_to_point(point)
  mp.osd_message("Seeking to point...", 999)
  register_seek_after_restart(point["time-pos"])
  return mp.commandv("loadfile", point["mpd-path"], "replace")
end
local function request_rewind(timestamp, callback)
  mp.osd_message("Rewinding...", 999)
  mp.set_property_native("pause", true)
  if (state["clock-timer"]):is_enabled() then
    stop_clock()
  else
  end
  mp.register_script_message("yp:rewind-completed", callback)
  return mp.commandv("script-message", "yp:rewind", timestamp)
end
local function go_to_point(index)
  local point
  do
    local t_24_ = state["marked-points"]
    if (nil ~= t_24_) then
      t_24_ = t_24_[index]
    else
    end
    point = t_24_
  end
  if point then
    state["current-mark"] = index
    mp.set_property_native("pause", true)
    if (state["current-mpd-path"] == point["mpd-path"]) then
      mp.commandv("seek", tostring(point["time-pos"]), "absolute")
    else
      if point["rewound?"] then
        load_and_seek_to_point(point)
      else
        local function callback(mpd_path, time_pos)
          mp.unregister_script_message("yp:rewind-completed")
          register_seek_after_restart(time_pos)
          point["time-pos"] = time_pos
          point["rewound?"] = true
          return nil
        end
        request_rewind(timestamp__3eisodate(point.timestamp), callback)
      end
    end
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
local function render_column(column)
  local right_margin = 10
  local key_font_size = (1.2 * theme["main-menu-font-size"])
  local rendered_lines = {}
  local max_label_length = 0
  local max_desc_length = 0
  for _, key in ipairs(column.keys) do
    do
      local key_dividers_num = (#key.binds - 1)
      local total_label_length
      local function _30_()
        local total = 0
        for _0, _31_ in ipairs(key.binds) do
          local _each_32_ = _31_
          local key_label = _each_32_[1]
          total = (total + #key_label)
        end
        return total
      end
      total_label_length = (key_dividers_num + _30_())
      if (max_label_length < total_label_length) then
        max_label_length = total_label_length
      else
      end
    end
    local desc_length = #key.desc
    if (max_desc_length < desc_length) then
      max_desc_length = desc_length
    else
    end
  end
  local function fill_rest_with(symbol, text, max_length)
    return string.rep(symbol, (max_length - #text))
  end
  table.insert(rendered_lines, string.format("%s %s%s%s", ass_fs(theme["main-menu-font-size"], ass_b(column.header)), ass_fs(key_font_size, ass_b(string.rep(" ", max_label_length))), ass_fs(theme["main-menu-font-size"], ""), fill_rest_with(" ", column.header, (max_desc_length + right_margin))))
  for _, key in ipairs(column.keys) do
    local label
    local _35_
    do
      local tbl_18_auto = {}
      local i_19_auto = 0
      for _0, _36_ in ipairs(key.binds) do
        local _each_37_ = _36_
        local key_label = _each_37_[1]
        local val_20_auto = key_label
        if (nil ~= val_20_auto) then
          i_19_auto = (i_19_auto + 1)
          do end (tbl_18_auto)[i_19_auto] = val_20_auto
        else
        end
      end
      _35_ = tbl_18_auto
    end
    label = table.concat(_35_, "/")
    local aligned_label = (fill_rest_with("\\h", label, max_label_length) .. label)
    table.insert(rendered_lines, string.format("%s%s%s", ass_fs(key_font_size, ass_b(aligned_label)), ass_fs(theme["main-menu-font-size"], (" " .. key.desc)), fill_rest_with(" ", key.desc, (max_desc_length + right_margin))))
  end
  return rendered_lines
end
local function post_render_mark_column(column_lines)
  if state["mark-mode-enabled?"] then
    local tbl_18_auto = {}
    local i_19_auto = 0
    for _, line in ipairs(column_lines) do
      local val_20_auto = string.format("%s%s%s", ass_c(theme["mark-mode-color"]), line, ass_c(theme["main-menu-color"]))
      if (nil ~= val_20_auto) then
        i_19_auto = (i_19_auto + 1)
        do end (tbl_18_auto)[i_19_auto] = val_20_auto
      else
      end
    end
    return tbl_18_auto
  else
    return column_lines
  end
end
local function stack_columns(...)
  local lines = {}
  do
    local max_column_size
    local function _41_(...)
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
    max_column_size = math.max(table.unpack(_41_(...)))
    for i = 1, max_column_size do
      local line = ""
      for _, column in pairs({...}) do
        line = (line .. (column[i] or string.format("{\\alpha&HFF&}%s{\\alpha&H00&}", column[1])))
      end
      table.insert(lines, line)
    end
  end
  return lines
end
local function _43_()
  local ass_tags = ass("\\an4\\fnmonospace\\bord2", ass_c_2a(theme["main-menu-color"]))
  do
    local _let_44_ = main_menu_map
    local rewind_col = _let_44_[1]
    local mark_mode_col = _let_44_[2]
    local other_col = _let_44_[3]
    local rendered_columns = {render_column(rewind_col), post_render_mark_column(render_column(mark_mode_col)), render_column(other_col)}
    local stacked_columns = stack_columns(table.unpack(rendered_columns))
    local _45_
    do
      local tbl_18_auto = {}
      local i_19_auto = 0
      for _, line in ipairs(stacked_columns) do
        local val_20_auto = (ass_tags .. line)
        if (nil ~= val_20_auto) then
          i_19_auto = (i_19_auto + 1)
          do end (tbl_18_auto)[i_19_auto] = val_20_auto
        else
        end
      end
      _45_ = tbl_18_auto
    end
    state["main-overlay"].data = table.concat(_45_, "\\N")
  end
  return (state["main-overlay"]):update()
end
display_main_overlay = _43_
local function rewind_key_handler()
  mp.set_property_native("pause", true)
  local now = os.date("!%Y%m%dT%H%z")
  local function _47_(value)
    local function callback(mpd_path, time_pos)
      mp.unregister_script_message("yp:rewind-completed")
      return register_seek_after_restart(time_pos)
    end
    request_rewind(value, callback)
    return input.terminate()
  end
  return input.get({prompt = "Rewind date:", default_text = now, cursor_position = 12, submit = _47_})
end
local function seek_backward_key_handler()
  mp.osd_message("Seeking backward...", 999)
  local function callback(_, time_pos)
    mp.unregister_script_message("yp:rewind-completed")
    return register_seek_after_restart(time_pos)
  end
  local cur_time_pos = mp.get_property_native("time-pos")
  local cur_timestamp = (state["current-start-time"] + cur_time_pos)
  return request_rewind(timestamp__3eisodate((cur_timestamp - settings["seek-offset"])), callback)
end
local function seek_forward_key_handler()
  mp.osd_message("Seeking forward...", 999)
  local function callback(_, time_pos)
    mp.unregister_script_message("yp:rewind-completed")
    return register_seek_after_restart(time_pos)
  end
  local cur_time_pos = mp.get_property_native("time-pos")
  local cur_timestamp = (state["current-start-time"] + cur_time_pos)
  local target = (cur_timestamp + settings["seek-offset"])
  if (target < os.time()) then
    return request_rewind(timestamp__3eisodate(target), callback)
  else
    return mp.osd_message("Seek forward unavailable")
  end
end
local function change_seek_offset_key_handler()
  local function submit_function(value)
    local ok_3f, value_or_error = pcall(seek_offset__3eseconds, value)
    if ok_3f then
      settings["seek-offset"] = value_or_error
      return input.terminate()
    else
      return input.log_error(value_or_error.msg)
    end
  end
  return input.get({prompt = "New seek offset:", default_text = "1h", submit = submit_function})
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
  local function _51_(value)
    do
      local hours = 3600
      settings["utc-offset"] = ((tonumber(value) or 0) * hours)
    end
    draw_clock()
    if state["mark-mode-enabled?"] then
      display_mark_overlay()
    else
    end
    return input.terminate()
  end
  return input.get({prompt = "New timezone offset: UTC", default_text = "+00", cursor_position = 2, submit = _51_})
end
local key_binding_names = {}
local function deactivate()
  state["activated?"] = false
  if state["mark-mode-enabled?"] then
    do end (state["mark-overlay"]):remove()
  else
  end
  do end (state["main-overlay"]):remove()
  for _, name in ipairs(key_binding_names) do
    mp.remove_key_binding(name)
  end
  return nil
end
local function register_keys(menu_map)
  local added_key_bindings = {}
  for _, column in ipairs(main_menu_map) do
    for _0, item in ipairs(column.keys) do
      for _1, _54_ in ipairs(item.binds) do
        local _each_55_ = _54_
        local key = _each_55_[1]
        local name = _each_55_[2]
        local func = _each_55_[3]
        mp.add_forced_key_binding(key, name, func)
        table.insert(added_key_bindings, name)
      end
    end
  end
  return added_key_bindings
end
local function define_main_menu_map()
  local function define_key_line(description, ...)
    local bindings = {...}
    return {desc = description, binds = bindings}
  end
  local function _56_()
    return go_to_point(1)
  end
  local function _57_()
    return go_to_point(2)
  end
  return {{header = "Rewind and seek", keys = {define_key_line("rewind", {"r", "rewind", rewind_key_handler}), define_key_line("seek backward/forward", {"<", "seek-backward", seek_backward_key_handler}, {">", "seek-forward", seek_forward_key_handler}), define_key_line("change seek offset", {"F", "change-seek-offset", change_seek_offset_key_handler})}}, {header = "Mark mode", keys = {define_key_line("mark new point", {"m", "mark-point", mark_new_point}), define_key_line("edit point", {"e", "edit-point", edit_current_point}), define_key_line("go to point A/B", {"a", "go-to-point-A", _56_}, {"b", "go-to-point-B", _57_})}}, {header = "Other", keys = {define_key_line("take a screenshot", {"s", "take-screenshot", take_screenshot_key_handler}), define_key_line("toggle clock", {"C", "toggle-clock", toggle_clock_key_handler}), define_key_line("change timezone", {"T", "change-timezone", change_timezone_key_handler}), define_key_line("quit", {"q", "quit", deactivate})}}}
end
local function activate()
  state["activated?"] = true
  main_menu_map = define_main_menu_map()
  key_binding_names = register_keys(main_menu_map)
  state["main-overlay"] = mp.create_osd_overlay("ass-events")
  display_main_overlay()
  if state["mark-mode-enabled?"] then
    return display_mark_overlay()
  else
    return nil
  end
end
local function _59_()
  if not state["activated?"] then
    return activate()
  else
    return deactivate()
  end
end
mp.add_forced_key_binding("Ctrl+p", "activate", _59_)
local function on_file_loaded()
  update_current_mpd()
  if (nil == state["clock-timer"]) then
    return start_clock()
  else
    return nil
  end
end
return mp.register_event("file-loaded", on_file_loaded)
