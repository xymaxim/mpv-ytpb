local mp = require("mp")
local options = require("mp.options")
local input = require("mp.input")
local state = {["main-overlay"] = nil, ["mark-overlay"] = nil, ["marked-points"] = {a = nil, b = nil}, ["mark-mode-enabled?"] = false}
local settings = {seek_offset = "10m"}
local key_binds = {}
local function display_main_overlay()
  state["main-overlay"].data = "{\\an4}{\\fnmonospace}{\\fs18}{\\b1}Rewind and seek{\\fs22}   {\\fs18}              Mark mode{\\fs22}  {\\fs18}                Other\n{\\an4}{\\fnmonospace}{\\fs22}{\\b1}\\h\\hr{\\b0}{\\fs18} rewind                      {\\fs22}{\\b1}\\h\\hm{\\b0}{\\fs18} toggle mode            {\\fs22}{\\b1}s{\\b0}{\\fs18} take a screenshot\n{\\an4}{\\fnmonospace}{\\fs22}{\\b1}</>{\\b0}{\\fs18} seek backward/forward       {\\fs22}{\\b1}a/b{\\b0}{\\fs18} mark point A/B         {\\fs22}{\\b1}q{\\b0}{\\fs18} quit\n{\\an4}{\\fnmonospace}{\\fs22}{\\b1}\\h\\hO{\\b0}{\\fs18} change seek offset          {\\fs22}{\\b1}A/B{\\b0}{\\fs18} go to point A/B"
  return (state["main-overlay"]):update()
end
local function deactivate()
  for _, _1_ in pairs(key_binds) do
    local _each_2_ = _1_
    local name = _each_2_[1]
    local _0 = _each_2_[2]
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
  local function _4_(value)
    mp.commandv("script-message", "yp:rewind", value)
    return input.terminate()
  end
  return input.get({prompt = "Rewind date:", default_text = now, cursor_position = 12, submit = _4_})
end
local function seek_forward_key_handler()
  return mp.commandv("script-message", "yp:seek", settings.seek_offset)
end
local function seek_backward_key_handler()
  return mp.commandv("script-message", "yp:seek", ("-" .. settings.seek_offset))
end
local function change_seek_offset_key_handler()
  local function _5_(value)
    if string.find(value, "[dhms]") then
      settings.seek_offset = value
      return input.terminate()
    else
      return input.log_error("Invalid value, should be [%dd][%Hh][%Mm][%Ss]")
    end
  end
  return input.get({prompt = "New seek offset:", default_text = settings.seek_offset, submit = _5_})
end
local function render_mark_overlay()
  local content = "{\\an8}Mark mode\\N"
  for _, point_name in pairs({"a", "b"}) do
    local point_value
    do
      local t_7_ = state["marked-points"]
      if (nil ~= t_7_) then
        t_7_ = t_7_[point_name]
      else
      end
      point_value = t_7_
    end
    if point_value then
      content = (content .. string.format("{\\an8}{\\fnmonospace}{\\fs28}%s {\\fs28}%s\\N", string.upper(point_name), point_value))
    else
    end
  end
  return content
end
local function display_mark_overlay()
  state["mark-overlay"].data = render_mark_overlay()
  return (state["mark-overlay"]):update()
end
local function toggle_mark_mode()
  state["mark-mode-enabled?"] = not state["mark-mode-enabled?"]
  if (nil == state["mark-overlay"]) then
    state["mark-overlay"] = mp.create_osd_overlay("ass-events")
  else
  end
  if state["mark-mode-enabled?"] then
    display_mark_overlay()
  else
    do end (state["mark-overlay"]):remove()
  end
  for point_name, _ in pairs(state["marked-points"]) do
    state["marked-points"][point_name] = nil
  end
  return nil
end
local function mark_point(point_name)
  if not state["mark-mode-enabled?"] then
    toggle_mark_mode()
  else
  end
  do
    local time_pos = mp.get_property("time-pos")
    do end (state["marked-points"])[point_name] = time_pos
  end
  return display_mark_overlay()
end
local function take_screenshot_key_handler()
  return mp.commandv("script-message", "yp:take-screenshot")
end
local function activate()
  key_binds["r"] = {"rewind", rewind_key_handler}
  key_binds["<"] = {"seek-backward", seek_backward_key_handler}
  key_binds[">"] = {"seek-forward", seek_forward_key_handler}
  key_binds["O"] = {"change-seek-offset", change_seek_offset_key_handler}
  key_binds["m"] = {"toggle-mark-mode", toggle_mark_mode}
  local function _13_()
    return mark_point("a")
  end
  key_binds["a"] = {"mark-point-a", _13_}
  local function _14_()
    return mark_point("b")
  end
  key_binds["b"] = {"mark-point-b", _14_}
  key_binds["s"] = {"take-screenshot", take_screenshot_key_handler}
  key_binds["q"] = {"quit", deactivate}
  for key, _15_ in pairs(key_binds) do
    local _each_16_ = _15_
    local name = _each_16_[1]
    local func = _each_16_[2]
    mp.add_forced_key_binding(key, name, func)
  end
  state["main-overlay"] = mp.create_osd_overlay("ass-events")
  return display_main_overlay()
end
return mp.add_forced_key_binding("Ctrl+p", "activate", activate)
