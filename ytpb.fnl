(local mp (require :mp))
(local msg (require :mp.msg))
(local options (require :mp.options))
(local input (require :mp.input))

(local theme {:main-menu-color :ffffff
              :main-menu-font-size 18
              :mark-mode-color :ffc66e
              :mark-mode-font-size 28
              :clock-color :ffffff
              :clock-font-size 32})

(local state {:current-mpd-path nil
              :current-start-time nil
              :activated? false
              :main-overlay nil
              :mark-mode-enabled? false
              :mark-overlay nil
              :marked-points []
              :current-mark nil
              :clock-overlay nil
              :clock-timer nil})

(local settings {:seek-offset 3600 :utc-offset nil})
(if (= nil settings.utc-offset)
    (let [local-offset (- (os.time) (os.time (os.date :!*t)))]
      (set settings.utc-offset local-offset)))

(var main-menu-map nil)
(var display-main-overlay nil)

(local Point {})

(lambda Point.new [self time-pos start-time mpd-path]
  (local obj {: time-pos : start-time : mpd-path})
  (set obj.timestamp (+ obj.start-time obj.time-pos))
  (set obj.rewound? false)
  (setmetatable obj self)
  (set self.__index self)
  obj)

(lambda Point.format [self ?utc-offset]
  (let [seconds (+ (math.floor self.timestamp) (or ?utc-offset 0))
        milliseconds (% self.timestamp 1)]
    (.. (os.date "!%Y-%m-%d %H:%M:%S" seconds) "."
        (string.sub (string.format "%.3f" milliseconds) 3))))

;;; Utility functions

(fn ass [...]
  (string.format "{%s}" (table.concat [...])))

(fn ass-b [value]
  (string.format "{\\b1}%s{\\b0}" value))

(fn ass-fs [size value]
  (string.format "{\\fs%s}%s" size value))

(fn ass-fs* [size]
  (string.format "\\fs%s" size))

(fn rgb->bgr [value]
  (let [(r g b) (string.match value "(%w%w)(%w%w)(%w%w)")]
    (.. b g r)))

(fn ass-c* [rgb ?tag-prefix]
  (string.format "\\%dc&H%s&" (or ?tag-prefix 1) (rgb->bgr rgb)))

(fn ass-c [rgb ?tag-prefix]
  (string.format "{%s}" (ass-c* rgb ?tag-prefix)))

(fn timestamp->isodate [value]
  (os.date "!%Y%m%dT%H%M%S%z" value))

(fn parse-mpd-start-time [content]
  (fn isodate->timestamp [value]
    (let [offset (- (os.time) (os.time (os.date :!*t)))
          pattern "(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)%.?(%d*)+00:00"
          (year month day hour min sec ms) (string.match value pattern)
          sec (+ sec offset)
          ms (tonumber ms)]
      (+ (os.time {: year : month : day : hour : min : sec})
         (if ms (/ ms 1000) 0))))

  (let [(_ _ start-time-str) (content:find "availabilityStartTime=\"([^\"]+)\"")]
    (isodate->timestamp start-time-str)))

(fn update-current-mpd []
  (set state.current-mpd-path (mp.get_property :path))
  (case (io.open state.current-mpd-path)
    f (do
        (set state.current-start-time (parse-mpd-start-time (f:read :*all)))
        (f:close))))

(fn seek-offset->seconds [value]
  (var total-seconds 0)
  (let [pattern "(%d+%.?%d*)(%a*)"
        symbols {:d 86400 :h 3600 :m 60 :s 1}]
    (each [number symbol (string.gmatch value pattern)]
      (case symbol
        (where x (. symbols x))
        (set total-seconds (+ total-seconds (* number (. symbols x))))
        "" (error {:msg "Time symbol is missing"})
        _ (error {:msg (.. "Unknown time symbol: " symbol)}))))
  total-seconds)

;;; Clock

(fn format-clock-time-string [timestamp]
  (let [date-time-part (os.date "!%Y–%m–%d %H:%M:%S"
                                (+ timestamp settings.utc-offset))
        hours (math.floor (/ settings.utc-offset 3600))
        minutes (math.floor (/ (% settings.utc-offset 3600) 60))
        hh-part (string.format "%+03d" hours)]
    (.. (string.format "%s %s" date-time-part hh-part)
        (if (> 0 minutes)
            (string.format ":%02d" minutes) ""))))

(fn draw-clock []
  (let [time-pos (mp.get_property_native :time-pos 0)
        time-string (format-clock-time-string (+ time-pos
                                                 state.current-start-time))
        ass-text (.. (ass "\\an9\\bord2" (ass-c* theme.clock-color)
                          (ass-fs* theme.clock-font-size))
                     time-string)]
    (set state.clock-overlay.data ass-text)
    (state.clock-overlay:update)))

(fn start-clock []
  (set state.clock-overlay (mp.create_osd_overlay :ass-events))
  (draw-clock)
  (set state.clock-timer (mp.add_periodic_timer 1 draw-clock)))

(fn stop-clock []
  (state.clock-timer:stop)
  (state.clock-overlay:remove))

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
  (local header-font-size (* 1.2 theme.mark-mode-font-size))
  (local point-labels [:A :B])
  (local lines [(string.format "%sMark mode%s"
                               (ass "\\an8\\bord2" (ass-fs* header-font-size)
                                    (ass-c* theme.mark-mode-color))
                               (ass-c :FFFFFF))])
  (each [i point (ipairs state.marked-points)]
    (let [point-label-template (if (= i state.current-mark) "(%s)" "\\h%s\\h")
          point-label (string.format point-label-template (. point-labels i))
          point-string (point:format settings.utc-offset)]
      (table.insert lines
                    (string.format "{\\an8\\fnmonospace}%s %s"
                                   (ass-fs theme.mark-mode-font-size
                                           point-label)
                                   (ass-fs theme.mark-mode-font-size
                                           point-string)))))
  (table.concat lines "\\N"))

(fn display-mark-overlay []
  (set state.mark-overlay.data (render-mark-overlay))
  (state.mark-overlay:update))

(fn mark-new-point []
  (if (not state.mark-mode-enabled?)
      (do
        (enable-mark-mode)
        (display-main-overlay)))
  (let [time-pos (mp.get_property_native :time-pos)
        new-point (Point:new time-pos state.current-start-time
                             state.current-mpd-path)]
    (case state.marked-points
      (where (or [nil] [a b])) (do
                                 (tset state.marked-points 1 new-point)
                                 (set state.current-mark 1)
                                 (if (. state.marked-points 2)
                                     (tset state.marked-points 2 nil)))
      [a nil] (do
                (if (>= new-point.timestamp a.timestamp)
                    (do
                      (tset state.marked-points 2 new-point)
                      (set state.current-mark 2))
                    (do
                      (set state.marked-points [new-point a])
                      (set state.current-mark 1)
                      (mp.commandv :show-text "Points swapped"))))))
  (display-mark-overlay))

(fn edit-current-point []
  (if (= nil state.current-mark)
      (mp.commandv :show-text "No marked points")
      (do
        (let [time-pos (mp.get_property_native :time-pos)
              new-point (Point:new time-pos state.current-start-time
                                   state.current-mpd-path)
              time-string (new-point:format settings.utc-offset)]
          (tset state.marked-points state.current-mark new-point)
          (let [[a b] state.marked-points]
            (if (and b (> a.timestamp b.timestamp))
                (do
                  (set state.marked-points [b a])
                  (set state.current-mark
                       (if (= new-point.timestamp b.timestamp) 1 2))
                  (mp.commandv :show-text "Points swapped")))))
        (display-mark-overlay))))

(fn register-seek-after-restart [time-pos]
  (fn seek-after-restart []
    (mp.unregister_event seek-after-restart)
    (local time-pos (tonumber time-pos))
    (var seek-timer nil)

    (fn try-to-seek []
      (local cache-state (mp.get_property_native :demuxer-cache-state))
      (if (not= 0 (length cache-state.seekable-ranges))
          (do
            (seek-timer:kill)
            (fn callback [name value]
              (if (= value true)
                  (lua :return))
              (mp.unobserve_property callback)
              (if state.clock-timer
                  (do
                    (draw-clock)
                    (state.clock-timer:resume)
                    (mp.osd_message ""))))

            (mp.observe_property :seeking :bool callback)
            (mp.commandv :seek time-pos :absolute))))

    (set seek-timer (mp.add_periodic_timer 0.2 try-to-seek)))

  (mp.register_event :playback-restart seek-after-restart))

(fn load-and-seek-to-point [point]
  (mp.osd_message "Seeking to point..." 999)
  (register-seek-after-restart point.time-pos)
  (mp.commandv :loadfile point.mpd-path :replace))

(fn request-rewind [timestamp callback]
  (mp.osd_message :Rewinding... 999)
  (mp.set_property_native :pause true)
  (if (state.clock-timer:is_enabled)
      (stop-clock))
  (mp.register_script_message "yp:rewind-completed" callback)
  (mp.commandv :script-message "yp:rewind" timestamp))

(fn go-to-point [index]
  (local point (?. state.marked-points index))
  (if point
      (do
        (set state.current-mark index)
        (mp.set_property_native :pause true)
        (if (= state.current-mpd-path point.mpd-path)
            (mp.commandv :seek (tostring point.time-pos) :absolute)
            (do
              (if point.rewound?
                  (load-and-seek-to-point point)
                  (do
                    (fn callback [mpd-path time-pos]
                      (mp.unregister_script_message "yp:rewind-completed")
                      (register-seek-after-restart time-pos)
                      (set point.time-pos time-pos)
                      (set point.rewound? true))
                    (request-rewind (timestamp->isodate point.timestamp)
                                    callback)))))
        (display-mark-overlay)
        (if (state.clock-timer:is_enabled)
            (draw-clock)))
      (mp.commandv :show-text "Point not marked")))

;;; Main

(fn render-column [column]
  (local right-margin 10)
  (local key-font-size (* 1.2 theme.main-menu-font-size))
  (var rendered-lines [])
  (var max-label-length 0)
  (var max-desc-length 0)
  (each [_ key (ipairs column.keys)]
    (let [key-dividers-num (- (length key.binds) 1)
          total-label-length (+ key-dividers-num
                                (accumulate [total 0 _ [key-label] (ipairs key.binds)]
                                  (+ total (length key-label))))]
      (if (< max-label-length total-label-length)
          (set max-label-length total-label-length)))
    (let [desc-length (length key.desc)]
      (if (< max-desc-length desc-length)
          (set max-desc-length desc-length))))

  (fn fill-rest-with [symbol text max-length]
    (string.rep symbol (- max-length (length text))))

  (table.insert rendered-lines
                (string.format "%s %s%s%s"
                               (ass-fs theme.main-menu-font-size
                                       (ass-b column.header))
                               (ass-fs key-font-size
                                       (ass-b (string.rep " " max-label-length)))
                               (ass-fs theme.main-menu-font-size "")
                               (fill-rest-with " " column.header
                                               (+ max-desc-length right-margin))))
  (each [_ key (ipairs column.keys)]
    (let [label (table.concat (icollect [_ [key-label] (ipairs key.binds)]
                                key-label) "/")
          aligned-label (.. (fill-rest-with "\\h" label max-label-length) label)]
      (table.insert rendered-lines
                    (string.format "%s%s%s"
                                   (ass-fs key-font-size (ass-b aligned-label))
                                   (ass-fs theme.main-menu-font-size
                                           (.. " " key.desc))
                                   (fill-rest-with " " key.desc
                                                   (+ max-desc-length
                                                      right-margin))))))
  rendered-lines)

(fn post-render-mark-column [column-lines]
  (if state.mark-mode-enabled?
      (icollect [_ line (ipairs column-lines)]
        (string.format "%s%s%s" (ass-c theme.mark-mode-color) line
                       (ass-c theme.main-menu-color)))
      column-lines))

(fn stack-columns [...]
  (var lines [])
  (let [max-column-size (math.max (table.unpack (icollect [_ column (ipairs [...])]
                                                  (length column))))]
    (for [i 1 max-column-size]
      (var line "")
      (each [_ column (pairs [...])]
        (set line (.. line
                      (or (. column i)
                          (string.format "{\\alpha&HFF&}%s{\\alpha&H00&}"
                                         (. column 1))))))
      (table.insert lines line)))
  lines)

(set display-main-overlay
     (fn []
       (local ass-tags
              (ass "\\an4\\fnmonospace\\bord2" (ass-c* theme.main-menu-color)))
       (let [[rewind-col mark-mode-col other-col] main-menu-map
             rendered-columns [(render-column rewind-col)
                               (-> (render-column mark-mode-col)
                                   (post-render-mark-column))
                               (render-column other-col)]
             stacked-columns (stack-columns (table.unpack rendered-columns))]
         (set state.main-overlay.data
              (table.concat (icollect [_ line (ipairs stacked_columns)]
                              (.. ass-tags line))
                            "\\N")))
       (state.main-overlay:update)))

;;; Setup

(fn rewind-key-handler []
  (mp.set_property_native :pause true)
  (let [now (os.date "!%Y%m%dT%H%z")]
    (input.get {:prompt "Rewind date:"
                :default_text now
                :cursor_position 12
                :submit (fn [value]
                          (fn callback [mpd-path time-pos]
                            (mp.unregister_script_message "yp:rewind-completed")
                            (register-seek-after-restart time-pos))

                          (request-rewind value callback)
                          (input.terminate))})))

(fn seek-backward-key-handler []
  (mp.osd_message "Seeking backward..." 999)

  (fn callback [_ time-pos]
    (mp.unregister_script_message "yp:rewind-completed")
    (register-seek-after-restart time-pos))

  (let [cur-time-pos (mp.get_property_native :time-pos)
        cur-timestamp (+ state.current-start-time cur-time-pos)]
    (request-rewind (timestamp->isodate (- cur-timestamp settings.seek-offset))
                    callback)))

(fn seek-forward-key-handler []
  (mp.osd_message "Seeking forward..." 999)

  (fn callback [_ time-pos]
    (mp.unregister_script_message "yp:rewind-completed")
    (register-seek-after-restart time-pos))

  (let [cur-time-pos (mp.get_property_native :time-pos)
        cur-timestamp (+ state.current-start-time cur-time-pos)
        target (+ cur-timestamp settings.seek-offset)]
    (if (< target (os.time))
        (request-rewind (timestamp->isodate target) callback)
        (mp.osd_message "Seek forward unavailable"))))

(fn change-seek-offset-key-handler []
  (fn submit-function [value]
    (let [(ok? value-or-error) (pcall seek-offset->seconds value)]
      (if ok?
          (do
            (set settings.seek-offset value-or-error)
            (input.terminate))
          (input.log_error value-or-error.msg))))

  (input.get {:prompt "New seek offset:"
              :default_text :1h
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

(fn change-timezone-key-handler []
  (input.get {:prompt "New timezone offset: UTC"
              :default_text :+00
              :cursor_position 4
              :submit (fn [value]
                        (let [hours 3600]
                          (set settings.utc-offset
                               (* (or (tonumber value) 0) hours)))
                        (draw-clock)
                        (if state.mark-mode-enabled?
                            (display-mark-overlay))
                        (input.terminate))}))

(var key-binding-names [])

(fn deactivate []
  "Disable key bindings and hide overlays on closing the main overlay. Keep
marked points, while the mark mode overlay will be hidden."
  (set state.activated? false)
  (if state.mark-mode-enabled?
      (state.mark-overlay:remove))
  (state.main-overlay:remove)
  (each [_ name (ipairs key-binding-names)]
    (mp.remove_key_binding name)))

(fn register-keys [menu-map]
  (local added-key-bindings [])
  (each [_ column (ipairs main-menu-map)]
    (each [_ item (ipairs column.keys)]
      (each [_ [key name func] (ipairs item.binds)]
        (mp.add_forced_key_binding key name func)
        (table.insert added-key-bindings name))))
  added-key-bindings)

(fn define-main-menu-map []
  (fn define-key-line [description & bindings]
    {:desc description :binds bindings})

  [{:header "Rewind and seek"
    :keys [(define-key-line :rewind
             [:r :rewind rewind-key-handler])
           (define-key-line "seek backward/forward"
             ["<" :seek-backward seek-backward-key-handler]
             [">" :seek-forward seek-forward-key-handler])
           (define-key-line "change seek offset"
             [:F :change-seek-offset change-seek-offset-key-handler])]}
   {:header "Mark mode"
    :keys [(define-key-line "mark new point"
             [:m :mark-point mark-new-point])
           (define-key-line "edit point"
             [:e :edit-point edit-current-point])
           (define-key-line "go to point A/B"
             [:a :go-to-point-A #(go-to-point 1)]
             [:b :go-to-point-B #(go-to-point 2)])]}
   {:header :Other
    :keys [(define-key-line "take a screenshot"
             [:s :take-screenshot take-screenshot-key-handler])
           (define-key-line "toggle clock"
             [:C :toggle-clock toggle-clock-key-handler])
           (define-key-line "change timezone"
             [:T :change-timezone change-timezone-key-handler])
           (define-key-line :quit
             [:q :quit deactivate])]}])

(fn activate []
  "Register key bindings and show the main overlay. If it's not a first launch,
show the previously marked points."
  (set state.activated? true)
  (set main-menu-map (define-main-menu-map))
  (set key-binding-names (register-keys main-menu-map))
  (set state.main-overlay (mp.create_osd_overlay :ass-events))
  (display-main-overlay)
  (if state.mark-mode-enabled?
      (display-mark-overlay)))

(mp.add_forced_key_binding :Ctrl+p :activate
                           (fn []
                             (if (not state.activated?)
                                 (activate)
                                 (deactivate))))

(fn on-file-loaded []
  (update-current-mpd)
  (if (= nil state.clock-timer)
      (start-clock)))

(mp.register_event :file-loaded on-file-loaded)
