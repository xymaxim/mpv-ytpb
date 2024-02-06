(local mp (require :mp))
(local options (require :mp.options))
(local input (require :mp.input))

(local state {:main-overlay nil
              :mark-overlay nil
              :mark-mode-enabled? false
              :marked-points {:a nil :b nil}})

(local settings {:seek_offset :10m})

(local key-binds {})

(fn display-main-overlay []
  (set state.main-overlay.data
       "{\\an4}{\\fnmonospace}{\\fs18}{\\b1}Rewind and seek{\\fs22}   {\\fs18}              Mark mode{\\fs22}  {\\fs18}                Other
{\\an4}{\\fnmonospace}{\\fs22}{\\b1}\\h\\hr{\\b0}{\\fs18} rewind                      {\\fs22}{\\b1}\\h\\hm{\\b0}{\\fs18} toggle mode            {\\fs22}{\\b1}s{\\b0}{\\fs18} take a screenshot
{\\an4}{\\fnmonospace}{\\fs22}{\\b1}</>{\\b0}{\\fs18} seek backward/forward       {\\fs22}{\\b1}a/b{\\b0}{\\fs18} mark point A/B         {\\fs22}{\\b1}q{\\b0}{\\fs18} quit
{\\an4}{\\fnmonospace}{\\fs22}{\\b1}\\h\\hO{\\b0}{\\fs18} change seek offset          {\\fs22}{\\b1}A/B{\\b0}{\\fs18} go to point A/B")
  (state.main-overlay:update))

(fn deactivate []
  (each [_ [name _] (pairs key-binds)]
    (mp.remove_key_binding name))
  (state.main-overlay:remove)
  (if (not= nil state.mark-overlay)
      (state.mark-overlay:remove))
  (set state.mark-mode-enabled? false))

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

(fn render-mark-overlay []
  (var content "{\\an8}Mark mode\\N")
  (each [_ point-name (pairs [:a :b])]
    (let [point-value (?. state.marked-points point-name)]
      (if point-value
          (set content
               (.. content
                   (string.format "{\\an8}{\\fnmonospace}{\\fs28}%s {\\fs28}%s\\N"
                                  (string.upper point-name) point-value))))))
  content)

(fn display-mark-overlay []
  (set state.mark-overlay.data (render-mark-overlay))
  (state.mark-overlay:update))

(fn toggle-mark-mode []
  (set state.mark-mode-enabled? (not state.mark-mode-enabled?))
  (if (= nil state.mark-overlay)
      (set state.mark-overlay (mp.create_osd_overlay :ass-events)))
  (if state.mark-mode-enabled?
      (display-mark-overlay)
      (state.mark-overlay:remove))
  (each [point-name _ (pairs state.marked-points)]
    (tset state.marked-points point-name nil)))

(fn mark-point [point-name]
  (if (not state.mark-mode-enabled?)
      (toggle-mark-mode))
  (let [time-pos (mp.get_property :time-pos)]
    (tset state.marked-points point-name time-pos))
  (display-mark-overlay))

(fn take-screenshot-key-handler []
  (mp.commandv :script-message "yp:take-screenshot"))

(fn activate []
  (tset key-binds :r [:rewind rewind-key-handler])
  (tset key-binds "<" [:seek-backward seek-backward-key-handler])
  (tset key-binds ">" [:seek-forward seek-forward-key-handler])
  (tset key-binds :O [:change-seek-offset change-seek-offset-key-handler])
  (tset key-binds :m [:toggle-mark-mode toggle-mark-mode])
  (tset key-binds :a [:mark-point-a (fn [] (mark-point :a))])
  (tset key-binds :b [:mark-point-b (fn [] (mark-point :b))])
  (tset key-binds :s [:take-screenshot take-screenshot-key-handler])
  (tset key-binds :q [:quit deactivate])
  (each [key [name func] (pairs key-binds)]
    (mp.add_forced_key_binding key name func))
  (set state.main-overlay (mp.create_osd_overlay :ass-events))
  (display-main-overlay))

(mp.add_forced_key_binding :Ctrl+p :activate activate)
