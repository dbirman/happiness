breed [trees tree]
breed [squirs squir]
breed [flowers flower]
flowers-own [age frate]
trees-own [srate tage]
patches-own [apples pollen]
squirs-own [energy age mode walk_s following r_f r_s r_m t_f t_s t_m] ;; Mode is FOOD/1, SHARE/2, MATE/3
links-own [lage]


to setup
  clear-all
  create-trees 10 [
    setxy random-xcor random-ycor
    set srate random new-srate + 1
    set shape "circle"
    set color green
    set tage random 500 + 100
  ]
  reset-ticks
end

to add-squirrels
  create-squirs num-squirrels [
    setxy random-xcor random-ycor
    set energy 100
    set mode random 3 + 1
    set walk_s random 2
    let f random 100
    let s random 100
    let m random 100
    set r_f f / (f + s + m)
    set r_s s / (f + s + m)
    set r_m m / (f + s + m)
  ]
end

to go
  ;; First lets deal with apples and moving them around
  pa-rot_apples
  pa-evap_pollen
  tr-drop_apples
  pa-roll_apples
  fl-age
  fl-smell
  t-age
  tr-replace
  ;; Second lets let the squirrels wander around and eat some apples
  if count squirs > 0 [sq-go]
  ;; Finally update the color of the patches
  pa-colorize
  l-age
  tick
end


to sq-go
  ;;What do squirrels do? Well, they can choose between a few actions:
  ;; (1) Eat apples on this patch
  ;; (2) Look for a patch with more apples
  ;; (3) Look for a patch with more pollen (a sign of future apples)
  ;; (4) Share apples with another nearby squirrel (creates a link)
  ;; (5) Move towards a linked squirrel and try to mate (both squirrels have to do it for it to work)
  ;; To decide between these things we have a flow chart, it works like this:
  ;; Squirrels have three modes "FOOD", "SHARE", "MATE".
  ;; On one tick each squirrel checks first to see if it should change modes, this depends on how long it has been in its current mode and the % of time it needs to devote to each mode.
  ;; If a squirrels energy drops below 100 it switches to food mode
  ;; If it doesn't switch then it does the mode's flowchart:
  ;; "FOOD":
  ;; (A) Check for apples
  ;; (B) Check for another patch with more apples
  ;; (C) Check for another patch with more pollen
  ;; (D-E) Pick a strategy based on your "walk-strategy" value
  ;; (D) Move towards a nearby linked squirrel
  ;; (D) Keep going roughly in one direction
  ;; "SHARE":
  ;; (A) Check for a linked squirrel in radius, share with that squirrel.
  ;; (B) Check for unlinked squirrels, share with them.
  ;; (C) Find the closest linked squirrel and move towards it
  ;; (D) Find the closest unlinked squirrel and move towards it
  ;; "MATE":
  ;; (A) Mate with a nearby linked squirrel, this kills the lowest energy squirrel out there
  ;; (B) Find the closest linked squirrel and move towards it
  ;; (C) Move to "SHARE" mode
  ask-concurrent squirs [sq-act]
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; SQUIRREL FUNCTIONS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to sq-act
  set age age + 1
  set energy energy - 1 ;; Life takes 10/tick
  sq-add_modes
  sq-change_modes
  ifelse not (energy < 100) [
    if mode = 1 [sq-f_mode]
    if mode = 2 [sq-s_mode]
    if mode = 3 [sq-m_mode]
  ]
  [ sq-f_mode ]
end

to sq-f_mode
  if (not sq-eat) [
    if not sq-move_uphill_apples [
      if not sq-move_uphill_pollen [
        ifelse walk_s = 1
        [sq-move_randomwalk]
        [ if not sq-move_linkwalk [sq-move_randomwalk] ]
      ]
    ]
  ]
end

to sq-s_mode
  if not sq-share_linked
  [ if not sq-share_unlinked 
    [ if not sq-move_linkwalk 
      [ sq-move_randomwalk ]
    ]
  ]
end

to sq-m_mode
  if not sq-mate
  [ if not sq-move_linkwalk
    [ sq-s_mode ] ;; If you aren't linked, then act as if you are in share mode (i.e. try to create links)
  ]
end

to-report sq-mate
  if count link-neighbors in-radius 2 > 0 [
    let friend one-of link-neighbors in-radius 2
    if [energy] of friend > 100 [
      ;; Mate!
      ask friend [set energy energy - 50]
      set energy energy - 50
      let mrf r_f
      let mrs r_s
      let mrm r_m
      hatch-squirs 1 [ sq-set_new_vars mrf mrs mrm color]
      ;; Kill one squirrel
      ask min-one-of squirs [energy] [die]
    ]
    set mode 1 ;; Done mating, start eating!
    report true
  ]
  report false
end

to sq-set_new_vars [mrf mrs mrm col]
  set energy 50
  rt random 360
  fd 2
  set col col + (random 5) - 2
  set age 0
  set mode 1
  set walk_s random 2
  set following -1
  let f mrf + (random 16 - 8) / 100
  let s mrs + (random 16 - 8) / 100
  let m mrm + (random 16 - 8) / 100
  set r_f f / (f + s + m)
  if r_f < 0 [set r_f 0]
  if r_f > 1 [set r_f 1]
  set r_s s / (f + s + m)
  if r_s < 0 [set r_s 0]
  if r_s > 1 [set r_s 1]
  set r_m m / (f + s + m)
  if r_m < 0 [set r_m 0]
  if r_m > 1 [set r_m 1]
end

to-report sq-eat
  if [apples] of patch-here > 0 [
    let capps [apples] of patch-here
    if capps > max-apple-consumption [set capps max-apple-consumption]
    ask patch-here [set apples apples - capps]
    set energy energy + capps * energy-per-apple
    report true
  ] 
  report false
end

to-report sq-share_linked
  if count link-neighbors in-radius 2 > 1 [
    let friend one-of link-neighbors in-radius 2
    create-link-with friend [set lage 0]
    let avgE ([energy] of friend + energy) / 2
    ask friend [set energy avgE]
    set energy avgE
    set mode 1 ;; Just shared, go eat
    report true
  ]
  report false
end

to-report sq-share_unlinked
  if count squirs in-radius 2 > 1 [
    let friend one-of other squirs in-radius 2
    create-link-with friend [set lage 0]
    let avgE ([energy] of friend + energy) / 2
    ask friend [set energy avgE]
    set energy avgE
    set mode 1 ;; Just shraed, go eat
    report true
  ]
  report false
end

to-report sq-move_linkwalk
  if count link-neighbors > 0 [
    if following = -1 or following = nobody [set following (one-of link-neighbors)]
    if not (following = nobody or following = 0) [
      face following
      fd 1
      report true
    ]
    report false
  ]
  report false
end

to sq-move_randomwalk
  rt (random 21) - 10
  fd 1
end

to-report sq-move_uphill_apples
  let ph patch-here
  uphill apples
  report not (ph = patch-here)
end

to-report sq-move_uphill_pollen
  let ph patch-here
  uphill pollen
  report not (ph = patch-here)
end

to sq-change_modes
  let fq t_f / age
  let sq t_s / age
  let mq t_m / age
  let time_spent 0
  if mode = 1 and fq > r_f [ ;; We spent more than our share of time in this mode
    if random 100 > 94 [ ;; 5% of the time, when greater than our share, we switch modes to the smallest mode
      ifelse sq < mq [set mode 2] [set mode 3]
      sq-reset_vars
    ]
  ]
  if mode = 2 and sq > r_s [ ;; We spent more than our share of time in this mode
    if random 100 > 97 [ ;; 2% of the time, when greater than our share, we switch modes to the smallest mode
      ifelse fq < mq [set mode 1] [set mode 3]
      sq-reset_vars
    ]
  ]
  if mode = 3 and mq > r_m [ ;; We spent more than our share of time in this mode
    if random 100 > 97 [ ;; 2% of the time, when greater than our share, we switch modes to the smallest mode
      ifelse sq < fq [set mode 2] [set mode 1]
      sq-reset_vars
    ]
  ]
end

to sq-reset_vars
  set following -1
end

to sq-add_modes
  if mode = 1 [set t_f t_f + 1]
  if mode = 2 [set t_s t_s + 1]
  if mode = 3 [set t_m t_m + 1]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; APPLE FUNCTIONS (without squirrels, average apples = ~2000, max of ~60
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


to pa-rot_apples
  ask patches [
    set apples apples * .9 - .01
    if apples < 0 [set apples 0]
  ]
end

to pa-evap_pollen
  ask patches [
    set pollen pollen * .99 - .001
    if pollen < 0 [set pollen 0]
  ]
end

to l-age
  ask links [set lage lage + 1]
  ask links [if lage > (random 25 + 75) [die]]
end

to tr-drop_apples
  ask trees [
    let dr_apples srate
    ask patch-here [set apples apples + dr_apples]
  ]
end

to pa-roll_apples
  ask-concurrent patches [
    if apples > (1 / apple-slide-rate * 4) [
      let rolled apples / (1 / apple-slide-rate)
      set apples apples - rolled
      ask neighbors [
        set apples apples + rolled / 8
      ]
    ]
  ]
end

to pa-colorize
  let m max [pollen] of patches
  ask patches [
    ifelse (round apples) > 0
     [ let col 10 + apples / 6
       ifelse col <= 15
       [set pcolor col] [set pcolor red]
     ]
     [ let col 40 + pollen * 5
       ifelse col <= 45
       [set pcolor col ] [set pcolor yellow]
     ]
  ]
end

to fl-age
  ask flowers [
    set age age - 1
    if age <= 0 [
      let r frate
      hatch-trees 1 [
        set srate r
        set tage random 500 + 100
        set shape "circle"
        set color green
      ]
      die
    ]
  ]
end

to fl-smell
  diffuse pollen pollen-diff-rate
  ask flowers [
    ask patch-here [
      set pollen pollen + 1
    ]
  ]
end

to t-age
  ask trees [ set tage tage - 1 ]
end

to tr-replace
  ask trees [
    if tage <= 0 [
      let r srate
      hatch-flowers 1 [
        set age random 250
        set frate r
        set shape "circle"
        set color yellow
        setxy random-xcor random-ycor
      ]
      die
    ]
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
252
10
672
451
20
20
10.0
1
10
1
1
1
0
1
1
1
-20
20
-20
20
1
1
1
ticks
30.0

BUTTON
13
11
76
44
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
82
12
145
45
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
16
57
188
90
apple-slide-rate
apple-slide-rate
0
1
0.5
.01
1
NIL
HORIZONTAL

BUTTON
15
103
119
136
Add Squirrels
add-squirrels
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
725
15
918
60
Avg rFood
mean [r_f] of squirs
2
1
11

MONITOR
725
66
929
111
Avg rShare
mean [r_s] of squirs
2
1
11

MONITOR
725
120
933
165
Average rMate
mean [r_m] of squirs
2
1
11

PLOT
959
16
1159
166
Squirrel Strategies
time
modifier value
0.0
10.0
0.0
1.0
true
true
"" "if count squirs > 0 [\nset-current-plot-pen \"Food\"\nplot count squirs with [mode = 1] / num-squirrels\nset-current-plot-pen \"Share\"\nplot count squirs with [mode = 2] / num-squirrels\nset-current-plot-pen \"Mate\"\nplot count squirs with [mode = 3] / num-squirrels\n]"
PENS
"Food" 1.0 0 -7500403 true "" ""
"Share" 1.0 0 -2674135 true "" ""
"Mate" 1.0 0 -955883 true "" ""

SLIDER
16
152
188
185
perc-squirs-evolve
perc-squirs-evolve
0
1
0.06
.01
1
NIL
HORIZONTAL

SLIDER
17
192
189
225
num-squirrels
num-squirrels
0
100
71
1
1
NIL
HORIZONTAL

SLIDER
16
234
188
267
pollen-diff-rate
pollen-diff-rate
0
1
0.9
.01
1
NIL
HORIZONTAL

SLIDER
17
275
198
308
max-apple-consumption
max-apple-consumption
1
25
15
1
1
NIL
HORIZONTAL

SLIDER
18
317
190
350
energy-per-apple
energy-per-apple
1
25
14
1
1
NIL
HORIZONTAL

SLIDER
19
357
191
390
new-srate
new-srate
0
50
9
1
1
NIL
HORIZONTAL

MONITOR
725
302
877
347
Max Apples on one Patch
max [apples] of patches
2
1
11

MONITOR
726
361
807
406
Total Apples
sum [apples] of patches
2
1
11

BUTTON
152
13
232
46
One-Tick
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
727
188
798
233
Average E
mean [energy] of squirs
2
1
11

PLOT
960
182
1160
332
Average Squirrel Age
time
age
0.0
10.0
0.0
10.0
true
false
"" "if count squirs > 0 [\nset-current-plot-pen \"Age\"\nplot mean [age] of squirs\n]"
PENS
"Age" 1.0 0 -16777216 true "" ""

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270

@#$#@#$#@
NetLogo 5.0.4
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 1.0 0.0
0.0 1 1.0 0.0
0.2 0 1.0 0.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180

@#$#@#$#@
0
@#$#@#$#@
