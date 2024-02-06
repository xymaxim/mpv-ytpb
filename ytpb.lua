local mp = require("mp")
local options = require("mp.options")
local input = require("mp.input")
local state = {osd = mp.create_osd_overlay("ass-events")}
local settings = {seek_offset = "10m"}
local key_binds = {}
local function display_keys_overlay()
  state.osd.data = "{\\an4}{\\fnmonospace}{\\fs18}{\\b1}Rewind and seek\n{\\an4}{\\fnmonospace}{\\fs18}{\\b1}r{\\b0} {\\fs18}rewind\n{\\an4}{\\fnmonospace}{\\fs18}{\\b1}b{\\b0} seek backward\n{\\an4}{\\fnmonospace}{\\fs18}{\\b1}f{\\b0} seek forward\n{\\an4}{\\fnmonospace}{\\fs18}{\\b1}O{\\b0} change seek offset\\N\\N\n{\\an4}{\\fnmonospace}{\\fs18}{\\b1}Miscellaneous\n{\\an4}{\\fnmonospace}{\\fs18}{\\b1}s{\\b0} take a screenshot\n{\\an4}{\\fnmonospace}{\\fs18}{\\b1}q{\\b0} quit"
  return (state.osd):update()
end
local function deactivate()
  for _, _1_ in pairs(key_binds) do
    local _each_2_ = _1_
    local name = _each_2_[1]
    local _0 = _each_2_[2]
    mp.remove_key_binding(name)
  end
  return (state.osd):remove()
end
local function take_screenshot_key_handler()
  return mp.commandv("script-message", "yp:take-screenshot")
end
local function rewind_key_handler()
  return mp.commandv("script-message-to", "console", "type", "script-message yp:rewind ''; keypress ESC", 27)
end
local function seek_forward_key_handler()
  return mp.commandv("script-message", "yp:seek", settings.seek_offset)
end
local function seek_backward_key_handler()
  return mp.commandv("script-message", "yp:seek", ("-" .. settings.seek_offset))
end
local function change_seek_offset_key_handler()
  local function _3_(value)
    if string.find(value, "[dhms]") then
      settings.seek_offset = value
      return input.terminate()
    else
      return input.log_error("Invalid value, should be [%dd][%Hh][%Mm][%Ss]")
    end
  end
  return input.get({prompt = "Seek offset:", default_text = settings.seek_offset, submit = _3_})
end
local function activate()
  key_binds["r"] = {"rewind", rewind_key_handler}
  key_binds["b"] = {"seek-backward", seek_backward_key_handler}
  key_binds["f"] = {"seek-forward", seek_forward_key_handler}
  key_binds["O"] = {"change-seek-offset", change_seek_offset_key_handler}
  key_binds["s"] = {"take-screenshot", take_screenshot_key_handler}
  key_binds["q"] = {"quit", deactivate}
  do
    local do_and_deactivate
    local function _5_(func)
      local function _6_()
        func()
        return deactivate()
      end
      return _6_
    end
    do_and_deactivate = _5_
    for key, _7_ in pairs(key_binds) do
      local _each_8_ = _7_
      local name = _each_8_[1]
      local func = _each_8_[2]
      mp.add_forced_key_binding(key, name, do_and_deactivate(func))
    end
  end
  return display_keys_overlay()
end
return mp.add_forced_key_binding("Ctrl+p", "activate", activate)
