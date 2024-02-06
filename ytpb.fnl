(local mp (require :mp))
(local options (require :mp.options))
(local input (require :mp.input))

(local state {:osd (mp.create_osd_overlay :ass-events)})

(local settings {:seek_offset :10m})

(local key-binds {})

(fn display-keys-overlay []
  (set state.osd.data
       "{\\an4}{\\fnmonospace}{\\fs18}{\\b1}Rewind and seek{\\b0}                   {\\b1}Other{\\b0}
{\\an4}{\\fnmonospace}{\\fs22}{\\b1}\\h\\hr{\\b0}{\\fs18} rewind                        {\\fs22}{\\b1}s{\\b0}{\\fs18} take a screenshot
{\\an4}{\\fnmonospace}{\\fs22}{\\b1}b/f{\\b0}{\\fs18} seek backward/forward         {\\fs22}{\\b1}q{\\b0}{\\fs18} quit
{\\an4}{\\fnmonospace}{\\fs22}{\\b1}\\h\\hO{\\b0}{\\fs18} change seek offset")
  (state.osd:update))

(fn deactivate []
  (each [_ [name _] (pairs key-binds)]
    (mp.remove_key_binding name))
  (state.osd:remove))

(fn take-screenshot-key-handler []
  (mp.commandv :script-message "yp:take-screenshot"))

(fn rewind-key-handler []
  (let [now (os.date "%Y%m%dT%H%z")]
    (input.get {:prompt "Rewind date:"
                :default_text now
                :cursor_position 12
                :submit (fn [value]
                          (mp.commandv :script-message "yp:rewind" value)
                          (input.terminate))})))

(fn seek-forward-key-handler []
  (mp.commandv :script-message "yp:seek" settings.seek_offset))

(fn seek-backward-key-handler []
  (mp.commandv :script-message "yp:seek" (.. "-" settings.seek_offset)))

(fn change-seek-offset-key-handler []
  (input.get {:prompt "New seek offset:"
              :default_text settings.seek_offset
              :submit (fn [value]
                        (if (string.find value "[dhms]")
                            (do
                              (set settings.seek_offset value)
                              (input.terminate))
                            (input.log_error "Invalid value, should be [%dd][%Hh][%Mm][%Ss]")))}))

(fn activate []
  (tset key-binds :r [:rewind rewind-key-handler])
  (tset key-binds :b [:seek-backward seek-backward-key-handler])
  (tset key-binds :f [:seek-forward seek-forward-key-handler])
  (tset key-binds :O [:change-seek-offset change-seek-offset-key-handler])
  (tset key-binds :s [:take-screenshot take-screenshot-key-handler])
  (tset key-binds :q [:quit deactivate])
  (let [do-and-deactivate (fn [func] (fn [] (func) (deactivate)))]
    (each [key [name func] (pairs key-binds)]
      (mp.add_forced_key_binding key name (do-and-deactivate func))))
  (display-keys-overlay))

(mp.add_forced_key_binding :Ctrl+p :activate activate)
