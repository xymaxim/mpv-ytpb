(local mp (require :mp))
(local options (require :mp.options))
(local input (require :mp.input))

(local state {:current-mpd nil
              :current-start-time nil
              :activated? false
              :main-overlay nil
              :mark-mode-enabled? false
              :mark-overlay nil
              :marked-points []
              :current-mark nil
              :clock-overlay nil
              :clock-timer nil})

(local settings {:seek_offset :10m})

(local key-binds {})

;;; Utility functions

(fn b [value]
  (string.format "{\\b1}%s{\\b0}" value))

(fn fs [size value]
  (string.format "{\\fs%s}%s" size value))

(fn parse-mpd-start-time [content]
  (local offset (- (os.time) (os.time (os.date :!*t))))
  (let [(_ _ start-time-str) (content:find "availabilityStartTime=\"(.+)\"")
        date-pattern "(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)+00:00"
        (year month day hour min sec) (string.match start-time-str date-pattern)]
    (let [sec (+ sec offset)]
      (os.time {: year : month : day : hour : min : sec}))))

(fn update-current-mpd []
  (tset state :current-mpd {:path (mp.get_property :path)})
  (case (io.open state.current-mpd.path)
    f (do
        (set state.current-start-time (parse-mpd-start-time (f:read :*all)))
        (set state.current-mpd.start-time state.current-start-time)
        (f:close))))

;;; Clock

(fn draw-clock []
  (let [time-pos (mp.get_property_native :time-pos 0)
        time-string (os.date "!%Y-%m-%d %H:%M:%S %z"
                             (+ time-pos state.current-start-time))
        ass-text (string.format "{\\an9\\bord10\\3c&H908070&}%s" time-string)]
    (set state.clock-overlay.data ass-text)
    (state.clock-overlay:update)))

(fn start-clock []
  (set state.clock-overlay (mp.create_osd_overlay :ass-events))
  (draw-clock)
  (set state.clock-timer (mp.add_periodic_timer 1 draw-clock)))

;;: Mark mode

(fn enable-mark-mode []
  (if (= nil state.mark-overlay)
      (set state.mark-overlay (mp.create_osd_overlay :ass-events)))
  (set state.mark-mode-enabled? true))

(fn disable-mark-mode []
  (set state.mark-mode-enabled? false)
  (set state.marked-points [])
  (if (not= nil state.mark-overlay)
      (state.mark-overlay:remove)))

(fn render-mark-overlay []
  (local point-labels [:A :B])
  (var content "{\\an8}Mark mode\\N")
  (each [i point (ipairs state.marked-points)]
    (let [point-label (string.format (if (= i state.current-mark) "(%s)"
                                         "\\h%s\\h")
                                     (. point-labels i))]
      (set content
           (.. content
               (string.format "{\\an8}{\\fnmonospace}%s %s\\N"
                              (fs 28 point-label) (fs 28 point.string))))))
  content)

(fn display-mark-overlay []
  (set state.mark-overlay.data (render-mark-overlay))
  (state.mark-overlay:update))

(fn format-time-string [timestamp]
  (os.date "!%Y-%m-%d %H:%M:%S%z" timestamp))

(fn mark-new-point []
  (local cache-state (mp.get_property_native :demuxer-cache-state))
  (if (not state.mark-mode-enabled?)
      (enable-mark-mode))
  (let [time-pos (mp.get_property_native :time-pos)
        time-string (format-time-string (+ time-pos state.current-start-time))
        new-point {:value time-pos :string time-string :mpd state.current-mpd}]
    (case state.marked-points
      (where (or [nil] [a b])) (do
                                 (tset state.marked-points 1 new-point)
                                 (set state.current-mark 1)
                                 (if b
                                     (tset state.marked-points 2 nil)))
      [a nil] (do
                (if (>= time-pos a.value)
                    (do
                      (tset state.marked-points 2 new-point)
                      (set state.current-mark 2))
                    (do
                      (set state.marked-points [new-point a])
                      (set state.current-mark 1)
                      (mp.commandv :show-text "Points swapped"))))))
  (display-mark-overlay))

(fn edit-point []
  (let [time-pos (mp.get_property_native :time-pos)
        time-string (format-time-string (+ time-pos state.current-start-time))
        new-point {:value time-pos :string time-string :mpd state.current-mpd}]
    (tset state.marked-points state.current-mark new-point)
    (let [[a b] state.marked-points]
      (if (and b (> a.value b.value))
          (do
            (set state.marked-points [b a])
            (set state.current-mark (if (= time-pos b.value) 1 2))
            (mp.commandv :show-text "Points swapped")))))
  (display-mark-overlay))

(fn rewind [timestamp]
  (mp.commandv :script-message "yp:rewind"
               (os.date "!%Y-%m-%dT%H:%M:%S%z" timestamp)))

(fn go-to-point [index]
  (local point (?. state.marked-points index))
  (if point
      (do
        (mp.set_property_native :pause true)
        (let [mpd-start-time point.mpd.start-time
              point-timestamp (+ point.mpd.start-time point.value)]
          (if (= state.current-mpd.path point.mpd.path)
              (mp.commandv :seek (tostring point.value) :absolute)
              (rewind point-timestamp)))
        (set state.current-mark index)
        (display-mark-overlay)
        (if (state.clock-timer:is_enabled)
            (draw-clock)))
      (mp.commandv :show-text "Point not marked")))

;;; Main

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
          :keys {:m "mark new point" :e "edit point" :a/b "go to point A/B"}})
  (local other-column {:header :Other
                       :keys {:s "take a screenshot"
                              :T "toggle clock"
                              :q :quit}})
  (local rewind-column-lines (render-column rewind-column [:r "</>" :O]))
  (local mark-mode-column-lines (render-column mark-mode-column [:m :e :a/b]))
  (local other-column-lines (render-column other-column [:s :T :q]))
  (let [stacked-columns (stack-columns rewind-column-lines
                                       mark-mode-column-lines other-column-lines)]
    (set state.main-overlay.data
         (table.concat (icollect [_ line (ipairs stacked_columns)]
                         (string.format "{\\an4}{\\fnmonospace}%s" line))
                       "\\N")))
  (state.main-overlay:update))

;;; Setup

(fn rewind-key-handler []
  (let [now (os.date "!%Y%m%dT%H%z")]
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
  (fn submit-function [value]
    (if (string.find value "[dhms]")
        (do
          (set settings.seek_offset value)
          (input.terminate))
        (input.log_error "Invalid value, should be [%dd][%Hh][%Mm][%Ss]")))

  (input.get {:prompt "New seek offset:"
              :default_text settings.seek_offset
              :submit submit-function}))

(fn take-screenshot-key-handler []
  (mp.commandv :script-message "yp:take-screenshot"))

(fn toggle-clock-key-handler []
  (if (state.clock-timer:is_enabled)
      (do
        (state.clock-timer:kill)
        (state.clock-overlay:remove))
      (do
        (draw-clock)
        (state.clock-timer:resume))))

(fn deactivate []
  "Disable key bindings and hide overlays on closing the main overlay. Keep
marked points, while the mark mode overlay will be hidden."
  (set state.activated? false)
  (if state.mark-mode-enabled?
      (state.mark-overlay:remove))
  (state.main-overlay:remove)
  (each [_ [name _] (pairs key-binds)]
    (mp.remove_key_binding name)))

(fn activate []
  "Register key bindings and show the main overlay. If it's not a first launch,
show the previously marked points."
  (set state.activated? true)
  (tset key-binds :r [:rewind rewind-key-handler])
  (tset key-binds "<" [:seek-backward seek-backward-key-handler])
  (tset key-binds ">" [:seek-forward seek-forward-key-handler])
  (tset key-binds :O [:change-seek-offset change-seek-offset-key-handler])
  (tset key-binds :m [:mark-new-point mark-new-point])
  (tset key-binds :e
        [:edit-point
         (fn []
           (if state.mark-mode-enabled?
               (edit-point)
               (mp.commandv :show-text "No marked points")))])
  (tset key-binds :a [:go-to-point-A #(go-to-point 1)])
  (tset key-binds :b [:go-to-point-B #(go-to-point 2)])
  (tset key-binds :s [:take-screenshot take-screenshot-key-handler])
  (tset key-binds :T [:toggle-clock toggle-clock-key-handler])
  (tset key-binds :q [:quit deactivate])
  (each [key [name func] (pairs key-binds)]
    (mp.add_forced_key_binding key name func))
  (set state.main-overlay (mp.create_osd_overlay :ass-events))
  (display-main-overlay)
  (if state.mark-mode-enabled?
      (display-mark-overlay)))

(mp.add_forced_key_binding :Ctrl+p :activate
                           (fn []
                             (if (not state.activated?)
                                 (activate))))

(fn on-file-loaded []
  (update-current-mpd)
  (start-clock))

(mp.register_event :file-loaded on-file-loaded)
