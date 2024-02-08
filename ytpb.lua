local mp = require("mp")
local options = require("mp.options")
local input = require("mp.input")
local state = {["main-overlay"] = nil, ["mark-overlay"] = nil, ["marked-points"] = {}, ["mark-mode-enabled?"] = false}
local settings = {seek_offset = "10m"}
local key_binds = {}
local function b(value)
  return string.format("{\\b1}%s{\\b0}", value)
end
local function fs(size, value)
  return string.format("{\\fs%s}%s", size, value)
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
    local function _3_()
      local desc = column.keys[key]
      return string.format("%s%s%s", fs(key_font_size, b(aligned_key0)), fs(main_font_size, (" " .. desc)), string.rep(" ", (right_margin + (max_desc_length - #desc))))
    end
    table.insert(rendered_lines, _3_())
  end
  return rendered_lines
end
local function stack_columns(...)
  local lines = {}
  do
    local max_column_size
    local function _4_(...)
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
    max_column_size = math.max(table.unpack(_4_(...)))
    for i = 1, max_column_size do
      local line = ""
      for _, column in pairs({...}) do
        local function _6_(...)
          local t_7_ = column
          if (nil ~= t_7_) then
            t_7_ = t_7_[i]
          else
          end
          return t_7_
        end
        line = (line .. (_6_() or string.format("{\\alpha&HFF&}%s{\\alpha&H00&}", column[1])))
      end
      table.insert(lines, line)
    end
  end
  return lines
end
local function display_main_overlay()
  local line_tags = "{\\an4}{\\fnmonospace}"
  local rewind_column = {header = "Rewind and seek", keys = {r = "rewind", ["</>"] = "seek backward/forward", O = "change seek offset"}}
  local mark_mode_column = {header = "Mark mode", keys = {m = "mark new point", e = "edit point", ["A/B"] = "go to point A/B"}}
  local other_column = {header = "Other", keys = {s = "take a screenshot", q = "quit"}}
  local rewind_column_lines = render_column(rewind_column, {"r", "</>", "O"})
  local mark_mode_column_lines = render_column(mark_mode_column, {"m", "e", "A/B"})
  local other_column_lines = render_column(other_column, {"s", "q"})
  do
    local stacked_columns = stack_columns(rewind_column_lines, mark_mode_column_lines, other_column_lines)
    local _9_
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
      _9_ = tbl_18_auto
    end
    state["main-overlay"].data = table.concat(_9_, "\\N")
  end
  return (state["main-overlay"]):update()
end
local function deactivate()
  for _, _11_ in pairs(key_binds) do
    local _each_12_ = _11_
    local name = _each_12_[1]
    local _0 = _each_12_[2]
    mp.remove_key_binding(name)
  end
  do end (state["main-overlay"]):remove()
  if (nil ~= state["mark-overlay"]) then
    do end (state["mark-overlay"]):remove()
  else
  end
  state["mark-mode-enabled?"] = false
  return nil
end
local function rewind_key_handler()
  local now = os.date("%Y%m%dT%H%z")
  local function _14_(value)
    mp.commandv("script-message", "yp:rewind", value)
    return input.terminate()
  end
  return input.get({prompt = "Rewind date:", default_text = now, cursor_position = 12, submit = _14_})
end
local function seek_forward_key_handler()
  return mp.commandv("script-message", "yp:seek", settings.seek_offset)
end
local function seek_backward_key_handler()
  return mp.commandv("script-message", "yp:seek", ("-" .. settings.seek_offset))
end
local function change_seek_offset_key_handler()
  local function _15_(value)
    if string.find(value, "[dhms]") then
      settings.seek_offset = value
      return input.terminate()
    else
      return input.log_error("Invalid value, should be [%dd][%Hh][%Mm][%Ss]")
    end
  end
  return input.get({prompt = "New seek offset:", default_text = settings.seek_offset, submit = _15_})
end
local function render_mark_overlay()
  local point_labels = {"A", "B"}
  local content = "{\\an8}Mark mode\\N"
  table.sort(state["marked-points"])
  for i, point in ipairs(state["marked-points"]) do
    content = (content .. string.format("{\\an8}{\\fnmonospace}%s %s\\N", fs(28, point_labels[i]), fs(28, point)))
  end
  return content
end
local function activate_mark_mode()
  if (nil == state["mark-overlay"]) then
    state["mark-overlay"] = mp.create_osd_overlay("ass-events")
  else
  end
  state["mark-mode-enabled?"] = true
  return nil
end
local function mark_new_point()
  if not state["mark-mode-enabled?"] then
    activate_mark_mode()
  else
  end
  do
    local time_pos = mp.get_property("time-pos")
    if (#state["marked-points"] == 2) then
      for key, _ in ipairs(state["marked-points"]) do
        state["marked-points"][key] = nil
      end
    else
    end
    table.insert(state["marked-points"], time_pos)
  end
  state["mark-overlay"].data = render_mark_overlay()
  return (state["mark-overlay"]):update()
end
local function take_screenshot_key_handler()
  return mp.commandv("script-message", "yp:take-screenshot")
end
local function activate()
  key_binds["r"] = {"rewind", rewind_key_handler}
  key_binds["<"] = {"seek-backward", seek_backward_key_handler}
  key_binds[">"] = {"seek-forward", seek_forward_key_handler}
  key_binds["O"] = {"change-seek-offset", change_seek_offset_key_handler}
  key_binds["m"] = {"mark-new-point", mark_new_point}
  key_binds["s"] = {"take-screenshot", take_screenshot_key_handler}
  key_binds["q"] = {"quit", deactivate}
  for key, _20_ in pairs(key_binds) do
    local _each_21_ = _20_
    local name = _each_21_[1]
    local func = _each_21_[2]
    mp.add_forced_key_binding(key, name, func)
  end
  state["main-overlay"] = mp.create_osd_overlay("ass-events")
  return display_main_overlay()
end
return mp.add_forced_key_binding("Ctrl+p", "activate", activate)
