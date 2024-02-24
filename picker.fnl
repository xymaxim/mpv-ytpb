(local mp (require :mp))

(var input-prompt nil)
(var input-text nil)
(var cursor-position nil)

(var timer nil)

(local date-pattern "(%d%d%d%d)-(%d%d)-(%d%d) (%d%d):(%d%d):(%d%d) ([+-]%d%d)")
(local submit-date-pattern "%1%2%3T%4%5%6%7")
(local input-mask "****-**-** **:**:** ***")

(local date-constraints {:m #(and (not= 0 $1) (<= $1 12))
                         :d #(and (not= 0 $1) (<= $1 31))
                         :H #(<= $1 24)
                         :M #(<= $1 59)
                         :S #(<= $1 59)})

(setmetatable date-constraints {:__index (fn [] (fn [_] true))})

(local ass-begin (mp.get_property :osd-ass-cc/0))
(local ass-end (mp.get_property :osd-ass-cc/1))

(fn validate-input-date [date]
  (var ok? true)
  (let [matches [(string.match date date-pattern)]]
    (if (not= nil (next matches))
        (let [[y m d H M S z] matches
              terms {: y : m : d : H : M : S : z}]
          (each [key value (pairs terms) &until (= ok? false)]
            (set ok? ((. date-constraints key) (tonumber value)))))
        (set ok? false)))
  ok?)

(fn shift-cursor [direction]
  (var selected? false)
  (var new-position (+ cursor-position direction))
  (while (not selected?)
    (let [input-length (length input-mask)]
      (case new-position
        0 (set new-position input-length)
        (where x (= x (+ input-length 1))) (set new-position 1)))
    (if (not= "*" (string.sub input-mask new-position new-position))
        (set new-position (+ new-position direction))
        (do
          (set cursor-position new-position)
          (set selected? true)))))

(fn replace-char [str index replace]
  (string.format "%s%s%s" (str:sub 1 (- index 1)) replace (str:sub (+ index 1))))

(fn show []
  (let [under-cursor (input-text:sub cursor-position cursor-position)
        under-cursor-hl (string.format "{\\b1}%s{\\b0}" under-cursor)
        input (replace-char input-text cursor-position under-cursor-hl)]
    (mp.osd_message (string.format "%s%s %s%s" ass-begin input-prompt input
                                   ass-end) 999)))

(fn input-symbol [symbol]
  (let [new-input (replace-char input-text cursor-position symbol)]
    (when (validate-input-date new-input)
      (set input-text new-input) true)))

(fn make-shift-cursor-handler [direction]
  (fn []
    (shift-cursor direction)
    (show)))

(var submit-callback nil)

(fn submit-handler []
  (let [date (input-text:gsub date-pattern submit-date-pattern)]
    (submit-callback date)))

(local key-handlers {:LEFT (make-shift-cursor-handler -1)
                     :RIGHT (make-shift-cursor-handler 1)
                     :ENTER submit-handler})

(local input-symbols [:0 :1 :2 :3 :4 :5 :6 :7 :8 :9 "+" "-"])
(each [_ symbol (ipairs input-symbols)]
  (tset key-handlers symbol (fn []
                              (when (input-symbol symbol)
                                (shift-cursor 1))
                              (show))))

(fn enable-key-bindings []
  (each [key handler (pairs key-handlers)]
    (let [flag (if (or (= key :LEFT) (= key :RIGHT)) :repeatable nil)]
      (mp.add_forced_key_binding key (.. :picker- key) handler flag))))

(fn activate []
  (enable-key-bindings)
  (show)
  (if (= nil timer)
      (set timer (mp.add_periodic_timer 3 show))))

(fn get [args]
  (set input-prompt args.prompt)
  (set input-text args.default)
  (set submit-callback args.submit)
  (set cursor-position (or args.cursor-pos 1))
  (activate))

(fn terminate []
  (each [key _ (pairs key-handlers)]
    (mp.remove_key_binding (.. :picker- key)))
  (timer:kill)
  (mp.osd_message ""))

(tset key-handlers :ESC terminate)

{: get : terminate}
