(local mp (require :mp))

(var input-prompt nil)
(var input-text nil)
(var cursor-position 1)
(var cursor-field 1)

(var timer nil)

(local date-pattern "(%d%d%d%d)-(%d%d)-(%d%d) (%d%d):(%d%d):(%d%d) ([+-]%d%d)")
(local submit-date-pattern "%1%2%3T%4%5%6%7")

(local fields [[1 2]
               [3 4]
               [6 7]
               [9 10]
               [12 13]
               [15 16]
               [18 19]
               [21 21]
               [22 24]])

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

(fn replace-char [str index replace]
  (string.format "%s%s%s" (str:sub 1 (- index 1)) replace (str:sub (+ index 1))))

(fn replace-sub [str start end replace]
  (string.format "%s%s%s" (str:sub 1 (- start 1)) replace (str:sub (+ end 1))))

(fn show []
  (let [[field-start field-end] (. fields cursor-field)
        under-cursor (input-text:sub field-start field-end)
        under-cursor-hl (string.format "{\\b1}%s{\\b0}" under-cursor)
        input (replace-sub input-text field-start field-end under-cursor-hl)]
    (mp.osd_message (string.format "%s%s%s%s" ass-begin input-prompt input
                                   ass-end) 999)))

(fn input-symbol [symbol]
  (let [new-input (replace-char input-text cursor-position symbol)]
    (when (validate-input-date new-input)
      (set input-text new-input) true)))

(fn shift-field [direction]
  (let [new-position (+ cursor-field direction)]
    (case new-position
      0 (set cursor-field (length fields))
      (where x (= x (+ 1 (length fields)))) (set cursor-field 1)
      _ (set cursor-field new-position)))
  (set cursor-position (. (. fields cursor-field) 1)))

(fn shift-cursor [direction]
  (let [[field-start field-end] (. fields cursor-field)
        new-position (+ cursor-position direction)]
    (case new-position
      (where x (< field-end x)) (shift-field 1)
      (where x (< x field-start)) (shift-field -1)
      _ (set cursor-position new-position))))

(fn make-shift-field-handler [direction]
  (fn []
    (shift-field direction)
    (show)))

(fn change-field-value [by]
  (let [[field-start field-end] (. fields cursor-field)
        field-value (input-text:sub field-start field-end)]
    (var new-value nil)
    (if (= 8 cursor-field)
        (set new-value (if (= "+" field-value) "-" "+"))
        (set new-value (string.format "%02d" (+ by (tonumber field-value)))))
    (let [new-input (replace-sub input-text field-start field-end new-value)]
      (if (validate-input-date new-input)
          (set input-text new-input)))))

(fn change-field-value-handler [by]
  (fn []
    (change-field-value by)
    (show)))

(var submit-callback nil)

(fn submit-handler []
  (let [date (input-text:gsub date-pattern submit-date-pattern)]
    (submit-callback date)))

(local key-handlers {:LEFT (make-shift-field-handler -1)
                     :RIGHT (make-shift-field-handler 1)
                     :UP (change-field-value-handler 1)
                     :DOWN (change-field-value-handler -1)
                     :ENTER submit-handler})

(local input-symbols [:0 :1 :2 :3 :4 :5 :6 :7 :8 :9 "+" "-"])
(each [_ symbol (ipairs input-symbols)]
  (tset key-handlers symbol (fn []
                              (when (input-symbol symbol)
                                (shift-cursor 1))
                              (show))))

(fn enable-key-bindings []
  (each [key handler (pairs key-handlers)]
    (let [repeatable-keys {:LEFT "" :RIGHT "" :UP "" :DOWN ""}
          flag (if (. repeatable-keys key) :repeatable nil)]
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
