local mp = require("mp")
local input = require("mp.input")
local msg = require("mp.msg")
local options = require("mp.options")
local utils = require("mp.utils")
local picker
package.preload["picker"] = package.preload["picker"] or function(...)
  local mp = require("mp")
  local input_prompt = nil
  local input_text = nil
  local cursor_position = nil
  local selected_field = "HH"
  local timer = nil
  local date_pattern = "(%d%d%d%d)-(%d%d)-(%d%d) (%d%d):(%d%d):(%d%d) ([+-]%d%d)"
  local submit_date_pattern = "%1%2%3T%4%5%6%7"
  local fields = {["yy**"] = {1, 2}, ["**yy"] = {3, 4}, mm = {6, 7}, dd = {9, 10}, HH = {12, 13}, MM = {15, 16}, SS = {18, 19}, ["+/-"] = {21, 21}, zz = {22, 24}}
  local function cycle_iter(items, _3fstart)
    local position = (_3fstart or 1)
    local size = #items
    local function _1_(direction)
      _G.assert((nil ~= direction), "Missing argument direction on ./picker.fnl:27")
      position = (direction + position)
      local function _2_()
        local x = position
        return (size < position)
      end
      if ((nil ~= position) and _2_()) then
        local x = position
        position = 1
      else
        local function _3_()
          local x = position
          return (position < 1)
        end
        if ((nil ~= position) and _3_()) then
          local x = position
          position = size
        else
        end
      end
      return items[position]
    end
    return _1_
  end
  local fields_order = {"yy**", "**yy", "mm", "dd", "HH", "MM", "SS", "+/-", "zz"}
  local fields_iter = cycle_iter(fields_order, 5)
  local date_constraints
  local function _5_(_241)
    return ((0 ~= _241) and (_241 <= 12))
  end
  local function _6_(_241)
    return ((0 ~= _241) and (_241 <= 31))
  end
  local function _7_(_241)
    return (_241 <= 24)
  end
  local function _8_(_241)
    return (_241 <= 59)
  end
  local function _9_(_241)
    return (_241 <= 59)
  end
  date_constraints = {m = _5_, d = _6_, H = _7_, M = _8_, S = _9_}
  local function _10_()
    local function _11_(_)
      return true
    end
    return _11_
  end
  setmetatable(date_constraints, {__index = _10_})
  local ass_begin = mp.get_property("osd-ass-cc/0")
  local ass_end = mp.get_property("osd-ass-cc/1")
  local function validate_input_date(date)
    local ok_3f = true
    do
      local matches = {string.match(date, date_pattern)}
      if (nil ~= next(matches)) then
        local _let_12_ = matches
        local y = _let_12_[1]
        local m = _let_12_[2]
        local d = _let_12_[3]
        local H = _let_12_[4]
        local M = _let_12_[5]
        local S = _let_12_[6]
        local z = _let_12_[7]
        local terms = {y = y, m = m, d = d, H = H, M = M, S = S, z = z}
        for key, value in pairs(terms) do
          if (ok_3f == false) then break end
          ok_3f = date_constraints[key](tonumber(value))
        end
      else
        ok_3f = false
      end
    end
    return ok_3f
  end
  local function replace_char(str, index, replace)
    return string.format("%s%s%s", str:sub(1, (index - 1)), replace, str:sub((index + 1)))
  end
  local function replace_sub(str, start, _end, replace)
    return string.format("%s%s%s", str:sub(1, (start - 1)), replace, str:sub((_end + 1)))
  end
  local function show()
    local _let_14_ = fields[selected_field]
    local field_start = _let_14_[1]
    local field_end = _let_14_[2]
    local under_cursor = input_text:sub(field_start, field_end)
    local under_cursor_hl = string.format("{\\b1}%s{\\b0}", under_cursor)
    local input = replace_sub(input_text, field_start, field_end, under_cursor_hl)
    return mp.osd_message(string.format("%s%s%s%s", ass_begin, input_prompt, input, ass_end), 999)
  end
  local function input_symbol(symbol)
    local new_input = replace_char(input_text, cursor_position, symbol)
    if validate_input_date(new_input) then
      input_text = new_input
      return true
    else
      return nil
    end
  end
  local function shift_field(direction)
    selected_field = fields_iter(direction)
    cursor_position = fields[selected_field][1]
    return nil
  end
  local function shift_cursor(direction)
    local _let_16_ = fields[selected_field]
    local field_start = _let_16_[1]
    local field_end = _let_16_[2]
    local new_position = (cursor_position + direction)
    local function _17_()
      local x = new_position
      return (field_end < x)
    end
    if ((nil ~= new_position) and _17_()) then
      local x = new_position
      return shift_field(1)
    else
      local function _18_()
        local x = new_position
        return (x < field_start)
      end
      if ((nil ~= new_position) and _18_()) then
        local x = new_position
        return shift_field(-1)
      else
        local _ = new_position
        cursor_position = new_position
        return nil
      end
    end
  end
  local function shift_field_handler(direction)
    local function _20_()
      shift_field(direction)
      return show()
    end
    return _20_
  end
  local function change_field_value(by)
    local function limit_value(value, min, max)
      local function _21_()
        local x = value
        return (x < min)
      end
      if ((nil ~= value) and _21_()) then
        local x = value
        return min
      else
        local function _22_()
          local x = value
          return (x > max)
        end
        if ((nil ~= value) and _22_()) then
          local x = value
          return max
        else
          local _ = value
          return value
        end
      end
    end
    local function cycle_value(value, field)
      local function cycle_within(x, min, max)
        local function _24_()
          local x0 = x
          return (x0 < min)
        end
        if ((nil ~= x) and _24_()) then
          local x0 = x
          return max
        else
          local function _25_()
            local x0 = x
            return (x0 > max)
          end
          if ((nil ~= x) and _25_()) then
            local x0 = x
            return min
          else
            local _ = x
            return x
          end
        end
      end
      if (field == "mm") then
        return cycle_within(value, 1, 12)
      elseif (field == "dd") then
        return cycle_within(value, 1, 31)
      elseif (field == "HH") then
        return cycle_within(value, 0, 23)
      elseif ((field == "MM") or (field == "SS")) then
        return cycle_within(value, 0, 59)
      else
        local _ = field
        return value
      end
    end
    local _let_28_ = fields[selected_field]
    local field_start = _let_28_[1]
    local field_end = _let_28_[2]
    local field_value = input_text:sub(field_start, field_end)
    local new_value
    if (selected_field == "+/-") then
      if ("+" == field_value) then
        new_value = "-"
      else
        new_value = "+"
      end
    else
      local _ = selected_field
      local attempt_value = (by + tonumber(field_value))
      local accepted_value
      if ((selected_field == "yy**") or (selected_field == "**yy")) then
        accepted_value = limit_value(attempt_value, 0, 99)
      else
        accepted_value = cycle_value(attempt_value, selected_field)
      end
      new_value = string.format("%02d", accepted_value)
    end
    local new_input = replace_sub(input_text, field_start, field_end, new_value)
    if validate_input_date(new_input) then
      input_text = new_input
      return nil
    else
      return nil
    end
  end
  local function change_field_value_handler(by)
    local function _33_()
      change_field_value(by)
      return show()
    end
    return _33_
  end
  local submit_callback = nil
  local function submit_handler()
    local date = input_text:gsub(date_pattern, submit_date_pattern)
    return submit_callback(date)
  end
  local key_handlers = {LEFT = shift_field_handler(-1), RIGHT = shift_field_handler(1), UP = change_field_value_handler(1), DOWN = change_field_value_handler(-1), ENTER = submit_handler}
  local input_symbols = {"0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "+", "-"}
  for _, symbol in ipairs(input_symbols) do
    local function _34_()
      if input_symbol(symbol) then
        shift_cursor(1)
      else
      end
      return show()
    end
    key_handlers[symbol] = _34_
  end
  local function enable_key_bindings()
    for key, handler in pairs(key_handlers) do
      local repeatable_keys = {LEFT = "", RIGHT = "", UP = "", DOWN = ""}
      local flag
      if repeatable_keys[key] then
        flag = "repeatable"
      else
        flag = nil
      end
      mp.add_forced_key_binding(key, ("picker-" .. key), handler, flag)
    end
    return nil
  end
  local function activate()
    enable_key_bindings()
    show()
    if (nil == timer) then
      timer = mp.add_periodic_timer(3, show)
      return nil
    else
      return nil
    end
  end
  local function get(args)
    input_prompt = args.prompt
    input_text = args.default
    submit_callback = args.submit
    cursor_position = (args["cursor-pos"] or 1)
    return activate()
  end
  local function terminate()
    for key, _ in pairs(key_handlers) do
      mp.remove_key_binding(("picker-" .. key))
    end
    if timer then
      timer:kill()
    else
    end
    return mp.osd_message("")
  end
  key_handlers["ESC"] = terminate
  return {get = get, terminate = terminate}
end
picker = require("picker")
local theme = {["main-menu-color"] = "ffffff", ["main-menu-font-size"] = 18, ["mark-mode-color"] = "ffffff", ["mark-mode-font-size"] = 28, ["clock-color"] = "ffffff", ["clock-font-size"] = 32}
local state = {["current-stream-id"] = nil, ["current-mpd-path"] = nil, ["current-start-time"] = nil, ["main-overlay"] = nil, ["mark-overlay"] = nil, ["marked-points"] = {}, ["current-mark"] = nil, ["clock-overlay"] = nil, ["clock-timer"] = nil, ["activated?"] = false, ["mark-mode-enabled?"] = false}
local socket_path = nil
local ytpb_mpv_handle = nil
local settings = {["seek-offset"] = 3600, ["utc-offset"] = nil}
if (nil == settings["utc-offset"]) then
  local local_offset = (os.time() - os.time(os.date("!*t")))
  settings["utc-offset"] = local_offset
else
end
local Point = {}
Point.new = function(self, time_pos, start_time, mpd_path)
  _G.assert((nil ~= mpd_path), "Missing argument mpd-path on ytpb.fnl:38")
  _G.assert((nil ~= start_time), "Missing argument start-time on ytpb.fnl:38")
  _G.assert((nil ~= time_pos), "Missing argument time-pos on ytpb.fnl:38")
  _G.assert((nil ~= self), "Missing argument self on ytpb.fnl:38")
  local obj = {["time-pos"] = time_pos, ["start-time"] = start_time, ["mpd-path"] = mpd_path}
  obj.timestamp = (obj["start-time"] + obj["time-pos"])
  obj["rewound?"] = false
  setmetatable(obj, self)
  self.__index = self
  return obj
end
Point.format = function(self, _3futc_offset)
  _G.assert((nil ~= self), "Missing argument self on ytpb.fnl:46")
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
    local function _40_()
      if ms0 then
        return (ms0 / 1000)
      else
        return 0
      end
    end
    return (os.time({year = year, month = month, day = day, hour = hour, min = min, sec = sec0}) + _40_())
  end
  local _, _0, start_time_str = content:find("availabilityStartTime=\"([^\"]+)\"")
  return isodate__3etimestamp(start_time_str)
end
local function update_current_mpd()
  state["current-mpd-path"] = mp.get_property("path")
  local _41_ = io.open(state["current-mpd-path"])
  if (nil ~= _41_) then
    local f = _41_
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
      local function _43_()
        local x = symbol
        return symbols[x]
      end
      if ((nil ~= symbol) and _43_()) then
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
  local function _45_()
    if (0 > minutes) then
      return string.format(":%02d", minutes)
    else
      return ""
    end
  end
  return (string.format("%s %s", date_time_part, hh_part) .. _45_())
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
local display_main_overlay = nil
local function mark_new_point()
  if not state["mark-mode-enabled?"] then
    enable_mark_mode()
    display_main_overlay()
  else
  end
  do
    local time_pos = mp.get_property_native("time-pos")
    local new_point = Point:new(time_pos, state["current-start-time"], state["current-mpd-path"])
    local _50_ = state["marked-points"]
    if (((_G.type(_50_) == "table") and (_50_[1] == nil)) or ((_G.type(_50_) == "table") and (nil ~= _50_[1]) and (nil ~= _50_[2]))) then
      state["marked-points"][1] = new_point
      state["current-mark"] = 1
      if state["marked-points"][2] then
        state["marked-points"][2] = nil
      else
      end
    elseif ((_G.type(_50_) == "table") and (nil ~= _50_[1]) and (_50_[2] == nil)) then
      local a = _50_[1]
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
      local _let_54_ = state["marked-points"]
      local a = _let_54_[1]
      local b = _let_54_[2]
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
local function request_rewind(date, callback)
  mp.osd_message("Rewinding...", 999)
  mp.set_property_native("pause", true)
  if (state["clock-timer"]):is_enabled() then
    stop_clock()
  else
  end
  mp.register_script_message("yp:rewind-completed", callback)
  return mp.commandv("script-message", "yp:rewind", date)
end
local function go_to_point(index)
  local point
  do
    local t_62_ = state["marked-points"]
    if (nil ~= t_62_) then
      t_62_ = t_62_[index]
    else
    end
    point = t_62_
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
      local function _68_()
        local total = 0
        for _0, _69_ in ipairs(key.binds) do
          local _each_70_ = _69_
          local key_label = _each_70_[1]
          total = (total + #key_label)
        end
        return total
      end
      total_label_length = (key_dividers_num + _68_())
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
    local _73_
    do
      local tbl_18_auto = {}
      local i_19_auto = 0
      for _0, _74_ in ipairs(key.binds) do
        local _each_75_ = _74_
        local key_label = _each_75_[1]
        local val_20_auto = key_label
        if (nil ~= val_20_auto) then
          i_19_auto = (i_19_auto + 1)
          do end (tbl_18_auto)[i_19_auto] = val_20_auto
        else
        end
      end
      _73_ = tbl_18_auto
    end
    label = table.concat(_73_, "/")
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
    local function _79_(...)
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
    max_column_size = math.max(table.unpack(_79_(...)))
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
local main_menu_map = nil
local function _81_()
  local ass_tags = ass("\\an4\\fnmonospace\\bord2", ass_c_2a(theme["main-menu-color"]))
  do
    local _let_82_ = main_menu_map
    local rewind_col = _let_82_[1]
    local mark_mode_col = _let_82_[2]
    local other_col = _let_82_[3]
    local rendered_columns = {render_column(rewind_col), post_render_mark_column(render_column(mark_mode_col)), render_column(other_col)}
    local stacked_columns = stack_columns(table.unpack(rendered_columns))
    local _83_
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
      _83_ = tbl_18_auto
    end
    state["main-overlay"].data = table.concat(_83_, "\\N")
  end
  return (state["main-overlay"]):update()
end
display_main_overlay = _81_
local function rewind_key_handler()
  mp.set_property_native("pause", true)
  local time_pos = mp.get_property_native("time-pos", 0)
  local time_string = format_clock_time_string((time_pos + state["current-start-time"]))
  local function _85_(date)
    local function callback(mpd_path, time_pos0)
      mp.unregister_script_message("yp:rewind-completed")
      return register_seek_after_restart(time_pos0)
    end
    picker.terminate()
    return request_rewind(date, callback)
  end
  return picker.get({prompt = "> Rewind to:\n", default = string.gsub(time_string, "\226\128\147", "-"), ["cursor-pos"] = 12, submit = _85_})
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
  local cur_time_pos = mp.get_property_native("time-pos")
  local cur_timestamp = (state["current-start-time"] + cur_time_pos)
  local date_time_part = os.date("!%Y%m%d-%H%M%S", cur_timestamp)
  local path = string.format("%s-%s.jpg", state["current-stream-id"], date_time_part)
  return mp.commandv("osd-msg", "screenshot-to-file", path)
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
  local function _89_(value)
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
  return input.get({prompt = "New timezone offset: UTC", default_text = "+00", cursor_position = 2, submit = _89_})
end
local key_binding_names = {}
local function deactivate()
  state["activated?"] = false
  if state["mark-mode-enabled?"] then
    do end (state["mark-overlay"]):remove()
  else
  end
  do end (state["main-overlay"]):remove()
  picker.terminate()
  for _, name in ipairs(key_binding_names) do
    mp.remove_key_binding(name)
  end
  return nil
end
local function register_keys(menu_map)
  local added_key_bindings = {}
  for _, column in ipairs(main_menu_map) do
    for _0, item in ipairs(column.keys) do
      for _1, _92_ in ipairs(item.binds) do
        local _each_93_ = _92_
        local key = _each_93_[1]
        local name = _each_93_[2]
        local func = _each_93_[3]
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
  local function _94_()
    return go_to_point(1)
  end
  local function _95_()
    return go_to_point(2)
  end
  return {{header = "Rewind and seek", keys = {define_key_line("rewind", {"r", "rewind", rewind_key_handler}), define_key_line("seek backward/forward", {"<", "seek-backward", seek_backward_key_handler}, {">", "seek-forward", seek_forward_key_handler}), define_key_line("change seek offset", {"F", "change-seek-offset", change_seek_offset_key_handler})}}, {header = "Mark mode", keys = {define_key_line("mark new point", {"m", "mark-point", mark_new_point}), define_key_line("edit point", {"e", "edit-point", edit_current_point}), define_key_line("go to point A/B", {"a", "go-to-point-A", _94_}, {"b", "go-to-point-B", _95_})}}, {header = "Other", keys = {define_key_line("take screenshot", {"s", "take-screenshot", take_screenshot_key_handler}), define_key_line("toggle clock", {"C", "toggle-clock", toggle_clock_key_handler}), define_key_line("change timezone", {"T", "change-timezone", change_timezone_key_handler}), define_key_line("quit", {"q", "quit", deactivate})}}}
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
local function _97_()
  if not state["activated?"] then
    return activate()
  else
    return deactivate()
  end
end
mp.add_forced_key_binding("Ctrl+p", "activate", _97_)
local function run_hook(ytpb_url)
  mp.set_property("stream-open-filename", "null://")
  mp.set_property("idle", "yes")
  mp.commandv("playlist-play-index", "none")
  local function on_file_loaded()
    update_current_mpd()
    return start_clock()
  end
  mp.register_event("file-loaded", on_file_loaded)
  local stream_url_or_id = ytpb_url:sub(8)
  local socket_path0 = ("/tmp/mpv-ytpb-socket-" .. utils.getpid())
  local global_args = table.concat({"--no-config", "--debug"}, " ")
  local args = table.concat({"--ipc-server", socket_path0, stream_url_or_id}, " ")
  state["current-stream-id"] = stream_url_or_id
  mp.set_property("input-ipc-server", socket_path0)
  local command = {"ytpb-mpv", global_args, "listen", args, "&"}
  state["socket-path"] = socket_path0
  state["ytpb-mpv-handle"] = io.popen(table.concat(command, " "), "w")
  return nil
end
local function on_load_file()
  local open_filename = mp.get_property("stream-open-filename", "")
  if (1 == open_filename:find("ytpb://")) then
    msg.info("ytpb URL detected, run hook")
    return run_hook(open_filename)
  else
    return nil
  end
end
mp.add_hook("on_load", 50, on_load_file)
local function _100_()
  do end (state["ytpb-mpv-handle"]):close()
  return os.remove(state["socket-path"])
end
return mp.register_event("shutdown", _100_)
