(local mp (require :mp))
(local options (require :mp.options))
(local input (require :mp.input))

(local state {:main-overlay nil
              :mark-overlay nil
              :mark-mode-enabled? false
              :marked-points []})

(local settings {:seek_offset :10m})

(local key-binds {})

(fn b [value]
  (string.format "{\\b1}%s{\\b0}" value))

(fn fs [size value]
  (string.format "{\\fs%s}%s" size value))

(fn render-column [column keys-order]
  (local right-margin 10)
  (local main-font-size 18)
  (local key-font-size (* 1.2 main-font-size))
  (var rendered-lines [])
  (var max-key-length 0)
  (var max-desc-length 0)
  (each [key desc (pairs column.keys)]
    (let [key-length (length key)]
      (if (> key-length max-key-length)
          (set max-key-length key-length)))
    (let [desc-length (length desc)]
      (if (> desc-length max-desc-length)
          (set max-desc-length desc-length))))
  (table.insert rendered-lines
                (string.format "%s %s%s%s"
                               (fs main-font-size (b column.header))
                               (fs key-font-size
                                   (b (string.rep " " max-key-length)))
                               (fs main-font-size "")
                               (string.rep " "
                                           (+ right-margin
                                              (- max-desc-length
                                                 (length column.header))))))
  (var aligned-key nil)
  (each [_ key (ipairs keys-order)]
    (let [aligned-key (.. (string.rep "\\h" (- max-key-length (length key)))
                          key)]
      (table.insert rendered-lines
                    (let [desc (. column.keys key)]
                      (string.format "%s%s%s"
                                     (fs key-font-size (b aligned-key))
                                     (fs main-font-size (.. " " desc))
                                     (string.rep " "
                                                 (+ right-margin
                                                    (- max-desc-length
                                                       (length desc)))))))))
  rendered-lines)

(fn stack-columns [...]
  (var lines [])
  (let [max-column-size (math.max (table.unpack (icollect [_ column (ipairs [...])]
                                                  (length column))))]
    (for [i 1 max-column-size]
      (var line "")
      (each [_ column (pairs [...])]
        (set line (.. line
                      (or (?. column i)
                          (string.format "{\\alpha&HFF&}%s{\\alpha&H00&}"
                                         (. column 1))))))
      (table.insert lines line)))
  lines)

(fn display-main-overlay []
  (local line-tags "{\\an4}{\\fnmonospace}")
  (local rewind-column {:header "Rewind and seek"
                        :keys {:r :rewind
                               :</> "seek backward/forward"
                               :O "change seek offset"}})
  (local mark-mode-column
         {:header "Mark mode"
          :keys {:m "mark new point" :e "edit point" :A/B "go to point A/B"}})
  (local other-column {:header :Other :keys {:s "take a screenshot" :q :quit}})
  (local rewind-column-lines (render-column rewind-column [:r "</>" :O]))
  (local mark-mode-column-lines (render-column mark-mode-column [:m :e :A/B]))
  (local other-column-lines (render-column other-column [:s :q]))
  (let [stacked-columns (stack-columns rewind-column-lines
                                       mark-mode-column-lines other-column-lines)]
    (set state.main-overlay.data
         (table.concat (icollect [_ line (ipairs stacked_columns)]
                         (string.format "{\\an4}{\\fnmonospace}%s" line))
                       "\\N")))
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
  (local point-labels [:A :B])
  (var content "{\\an8}Mark mode\\N")
  (table.sort state.marked-points)
  (each [i point (ipairs state.marked-points)]
    (set content
         (.. content
             (string.format "{\\an8}{\\fnmonospace}%s %s\\N"
                            (fs 28 (. point-labels i)) (fs 28 point)))))
  content)

(fn activate-mark-mode []
  (if (= nil state.mark-overlay)
      (set state.mark-overlay (mp.create_osd_overlay :ass-events)))
  (set state.mark-mode-enabled? true))

(fn mark-new-point []
  (if (not state.mark-mode-enabled?)
      (activate-mark-mode))
  (let [time-pos (mp.get_property :time-pos)]
    (if (= (length state.marked-points) 2)
        (each [key _ (ipairs state.marked-points)]
          (tset state.marked-points key nil)))
    (table.insert state.marked-points time-pos))
  (set state.mark-overlay.data (render-mark-overlay))
  (state.mark-overlay:update))

(fn go-to-point [index]
  (mp.commandv :seek (tostring (. state.marked-points index)) :absolute)
  (mp.set_property_native :pause true))

(fn take-screenshot-key-handler []
  (mp.commandv :script-message "yp:take-screenshot"))

(fn activate []
  (tset key-binds :r [:rewind rewind-key-handler])
  (tset key-binds "<" [:seek-backward seek-backward-key-handler])
  (tset key-binds ">" [:seek-forward seek-forward-key-handler])
  (tset key-binds :O [:change-seek-offset change-seek-offset-key-handler])
  (tset key-binds :m [:mark-new-point mark-new-point])
  (tset key-binds :A [:go-to-point-A (fn [] (go-to-point 1))])
  (tset key-binds :B [:go-to-point-B (fn [] (go-to-point 2))])
  (tset key-binds :s [:take-screenshot take-screenshot-key-handler])
  (tset key-binds :q [:quit deactivate])
  (each [key [name func] (pairs key-binds)]
    (mp.add_forced_key_binding key name func))
  (set state.main-overlay (mp.create_osd_overlay :ass-events))
  (display-main-overlay))

(mp.add_forced_key_binding :Ctrl+p :activate activate)
