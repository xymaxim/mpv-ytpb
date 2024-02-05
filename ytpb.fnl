(local mp (require :mp))
(local options (require :mp.options))

(local state {:osd (mp.create_osd_overlay :ass-events)})

(local settings {:seek_offset :10m})

(local key-binds {})

(fn display-keys-overlay []
  (set state.osd.data "{\\an4}{\\fnmonospace}{\\fs18}{\\b1}Rewind and seek
{\\an4}{\\fnmonospace}{\\fs18}{\\b1}r{\\b0} {\\fs18}rewind
{\\an4}{\\fnmonospace}{\\fs18}{\\b1}b{\\b0} seek backward
{\\an4}{\\fnmonospace}{\\fs18}{\\b1}f{\\b0} seek forward\\N\\N
{\\an4}{\\fnmonospace}{\\fs18}{\\b1}Miscellaneous
{\\an4}{\\fnmonospace}{\\fs18}{\\b1}s{\\b0} take a screenshot
{\\an4}{\\fnmonospace}{\\fs18}{\\b1}q{\\b0} quit")
  (state.osd:update))

(fn deactivate []
  (each [_ [name _] (pairs key-binds)]
    (mp.remove_key_binding name))
  (state.osd:remove))

(fn take-screenshot-key-handler []
  (mp.commandv :script-message "yp:take-screenshot"))

(fn rewind-key-handler []
  (mp.commandv :script-message-to :console :type
               "script-message yp:rewind ''; keypress ESC" 27))

(fn seek-forward-key-handler []
  (mp.commandv :script-message "yp:seek" settings.seek_offset))

(fn seek-backward-key-handler []
  (mp.commandv :script-message "yp:seek" (.. "-" settings.seek_offset)))

(fn activate []
  (tset key-binds :r [:rewind rewind-key-handler])
  (tset key-binds :b [:seek-backward seek-backward-key-handler])
  (tset key-binds :f [:seek-forward seek-forward-key-handler])
  (tset key-binds :s [:take-screenshot take-screenshot-key-handler])
  (tset key-binds :q [:quit deactivate])
  (let [do-and-deactivate (fn [func] (fn [] (func) (deactivate)))]
    (each [key [name func] (pairs key-binds)]
      (mp.add_forced_key_binding key name (do-and-deactivate func))))
  (display-keys-overlay))

(mp.add_forced_key_binding :Ctrl+p :activate activate)