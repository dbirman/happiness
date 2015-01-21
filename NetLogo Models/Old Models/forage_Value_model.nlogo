breed [foragers forager]

patches-own [seed? penergy ps fs value]
foragers-own [next-task taskn hed eud-val time-eat ter time-soc tsr time-rep trr age complete? hed? pcount preset]

globals [table next-seed hdata edata]
extensions [profiler]
  
to PROFILE
  reset
  setup
  profiler:start
  repeat 100 [ go ]
  profiler:stop
  print profiler:report
  profiler:reset
end

to reset
  clear-all
  reset-ticks
  ask patches [set seed? false]
  set next-seed init-seed
  set edata []
  set hdata []
end

to setup
  with-local-randomness [
    set-seed
    patches-add
  ]
  foragers-add
end

to go
  with-local-randomness [
    set-seed
    patches-do
  ]
  foragers-do
  tick
end

to track-data
  set hdata lput mean [hed] of foragers hdata
  set edata lput mean [eud-val] of foragers edata
end

to set-seed
  random-seed next-seed
  set next-seed random 1000000
end

;;;;;;;;;;;;;;
;; FORAGERS ;;
;;;;;;;;;;;;;;

to foragers-add
  create-foragers num-foragers [fhelper-init]
end

to foragers-do
  ask foragers [
    ;; Our policy is *learned*, so lets pick our next task by calculating outputs, no learning!
    if pcount >= preset [set preset 100 - preset set pcount 0 set hed? not hed?]
    move forager-max-value
    if complete? = true [
      ifelse time-eat * 1.5 > time-soc and time-eat * 2 > time-rep [fhelper-snt 1]
      [
        ifelse time-soc * 1.5 > time-rep [fhelper-snt 2]
        [
          fhelper-snt 3
        ]
      ]
    ]
    fhelper-basics
    run next-task
  ]
end

to-report forager-max-value
  ;; Find the patch with the highest value that is visible
  ask patches in-radius 4 [patch-value]
  report max-one-of patches in-radius 4 [value]
end
  
to patch-value
  ;; We need a reinforcement learning based approach here? But what to use!?!??! Q-Learning?
  ifelse [taskn] of myself = 1
  [
    ifelse [hed?] of myself = true
    [set value ps-error]
    [set value ps-error * [time-eat] of myself + random 100]
  ]
  [
    ifelse [taskn] of myself = 2
    [
      ;;taskn = 2 (soc)
      ifelse [hed?] of myself = true
      [set value fs-error]
      [set value fs-error * [time-soc] of myself + random 100]
    ]
    [
      ;;taskn = 3 (rep)
      ifelse [hed?] of myself = true
      [set value fs-error]
      [set value fs-error * [time-rep] of myself + random 100]
    ]
  ]
end

;;;;;;;;;;;;;
;; ACTIONS ;;
;;;;;;;;;;;;;

to move [aim]
  let p min-one-of neighbors [distance aim]
  face p
  move-to p
end

to eat
  if [penergy] of patch-here > 0 [
    set time-eat max (list (time-eat - ter) 0)
    set ter ter * .75
    ask patch-here [set penergy penergy - 1]
    set complete? true
  ]
end

to soc
  if count other foragers-on patch-here > 0 [
    set time-soc max (list (time-soc - tsr) 0)
    set tsr tsr * .5
    set complete? true
  ]
end

to rep
  if random-float 1 < rep-rate and count other foragers-on patch-here > 0 [
    ;set time-eat time-eat + 10
    set time-rep max (list (time-rep - trr) 0)
    set trr trr * .25
    set complete? true
  ]
end

;;;;;;;;;;;;;
;; PATCHES ;;
;;;;;;;;;;;;;

to patches-add
  ask n-of num-patches patches [phelper-init]
end

to patches-do
  ask patches [
    if random-float 1 < .01 and count patches with [seed?] < num-patches [ask one-of patches [phelper-init]]
    set ps ps - .05
    set fs fs - .05
    if fs < 0 [set fs 0] if ps < 0 [set ps 0]
    set fs fs + .5 * count foragers-here
    if seed? [set ps ps + 1]
    if penergy > 0 [ set penergy penergy - const-energ-dec ]
    if penergy < 0 and seed? [set penergy 0 set pcolor 0 set seed? false]
    if scent-colors [
      ifelse fs = 0
      [ ifelse ps = 0 
        [set pcolor black]
        [set pcolor 52 + ps * 6]
      ]
      [set pcolor 12 + fs * 6]
    ]
    if value-colors [
      let vmod max [value] of patches
      ifelse value > 0 [set pcolor 42 + value / vmod * 6] [set pcolor black]
      set value 0
    ]
  ]
  diffuse ps .5
  diffuse fs .5
end

;;;;;;;;;;;;;
;; HELPERS ;;
;;;;;;;;;;;;;

to fhelper-snt [n]
  set next-task fhelper-translate-task n
  set taskn n
  set complete? false
end

to-report fhelper-translate-task [val]
  if val = 1 [report task eat]
  if val = 2 [report task soc]
  if val = 3 [report task rep]
end

to-report fhelper-calc-eud [te ts tr]
  report ( 300 - (te + ts + tr) ) / 3
end

to fhelper-basics
  set age age + 1
  set pcount pcount + 1
  set time-eat time-eat + 1
  if time-eat > mem [set time-eat mem]
  set time-soc time-soc + 1
  if time-soc > mem [set time-soc mem]
  set time-rep time-rep + 1
  if time-rep > mem [set time-rep mem]
  set ter min (list (ter + 10) 100)
  set tsr min (list (tsr + 10) 100)
  set trr min (list (trr + 10) 100)
  let neud fhelper-calc-eud time-eat time-soc time-rep
  if ticks > 2 [set hed ifelse-value (time-eat < 10) [1] [ifelse-value (time-rep < 0) [1] [-1]]]
  set eud-val neud
end

to fhelper-init
  setxy random-xcor random-ycor
  set color one-of base-colors
  set hed 0
  set eud-val 0
  set time-eat random 100
  set time-soc random 100
  set time-rep random 100
  set pcount 0
  ifelse random-float 1 < .5 [set preset pref * 100 set hed? true] [set preset (1 - pref) * 100 set hed? false]
  set ter 100
  set tsr 100
  set trr 100
  set age random 0
  fhelper-snt 1
end

to-report zeros
  report znum 11
end
to-report znum [v]
  report n-values v [0]
end

to-report mut-rate
  report .5
end

to-report uphill-ps
  report max-one-of neighbors4 [ps-error]
end

to-report uphill-fs
  report max-one-of neighbors4 [fs-error]
end

to phelper-init
  set penergy random max-penergy + 1
  set seed? true
end

to-report ps-error
  report random-normal ps (ps * error-rate)
end

to-report fs-error
  report random-normal fs (fs * error-rate)
end
@#$#@#$#@
GRAPHICS-WINDOW
224
13
676
486
10
10
21.05
1
10
1
1
1
0
1
1
1
-10
10
-10
10
1
1
1
ticks
20.0

SLIDER
32
60
204
93
num-patches
num-patches
0
5
7
1
1
NIL
HORIZONTAL

CHOOSER
43
103
181
148
max-penergy
max-penergy
100 50 25
2

BUTTON
5
12
69
45
Reset
reset
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
72
13
136
46
Setup
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
144
15
207
48
Go
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

CHOOSER
12
164
150
209
const-energ-dec
const-energ-dec
0.05
0

SLIDER
12
266
184
299
error-rate
error-rate
0
1
0.1
.05
1
NIL
HORIZONTAL

SLIDER
17
317
189
350
num-foragers
num-foragers
0
100
10
5
1
NIL
HORIZONTAL

CHOOSER
20
373
158
418
mem
mem
100
0

CHOOSER
24
425
162
470
rep-rate
rep-rate
0.1 0.5
0

PLOT
702
312
902
462
plot 2
NIL
NIL
0.0
10.0
0.0
100.0
true
false
"" "if count foragers > 0 [\nset-current-plot-pen \"default\"\nplot 90\nset-current-plot-pen \"pen-1\"\nplot 80\nset-current-plot-pen \"pen-2\"\nplot mean [eud-val] of foragers\n]"
PENS
"default" 1.0 0 -16777216 true "" ""
"pen-1" 1.0 0 -7500403 true "" ""
"pen-2" 1.0 0 -2674135 true "" ""

PLOT
929
314
1129
464
 Eat --- Soc --- Rep
NIL
NIL
1.0
4.0
0.0
1.0
true
false
"" "if count foragers > 1 [\nclear-plot\nforeach [1 2 3] [\nplotxy ? count foragers with [taskn = ?] / count foragers\n]\n]"
PENS
"default" 1.0 1 -16777216 true "" ""

MONITOR
701
23
755
68
Age
mean [age] of foragers
2
1
11

MONITOR
765
23
822
68
Energy
mean [penergy] of patches with [penergy > 0]
2
1
11

PLOT
703
159
903
309
plot 1
NIL
NIL
0.0
10.0
-1.5
1.5
true
false
"" "if count foragers > 0 [\nset-current-plot-pen \"default\"\nplot mean [hed] of turtles\nset-current-plot-pen \"zero\"\nplot 0\n]"
PENS
"default" 1.0 0 -16777216 true "" ""
"zero" 1.0 0 -2674135 true "" ""

SWITCH
949
24
1072
57
scent-colors
scent-colors
0
1
-1000

SWITCH
1079
25
1202
58
value-colors
value-colors
1
1
-1000

PLOT
923
159
1123
309
Time Values
NIL
NIL
1.0
4.0
0.0
100.0
true
false
"" "if count foragers > 0 [\nclear-plot\nplotxy 1 mean [time-eat] of foragers\nplotxy 2 mean [time-soc] of foragers\nplotxy 3 mean [time-rep] of foragers\n]"
PENS
"default" 1.0 1 -16777216 true "" ""

SLIDER
975
78
1147
111
pref
pref
0
1
0.85
.01
1
NIL
HORIZONTAL

SLIDER
713
97
885
130
init-seed
init-seed
0
10
5
1
1
NIL
HORIZONTAL

@#$#@#$#@
BOLTZMANN EXPLORATION:
@article{kaelbling1996reinforcement,
  title={Reinforcement learning: A survey},
  author={Kaelbling, Leslie Pack and Littman, Michael L and Moore, Andrew W},
  journal={arXiv preprint cs/9605103},
  year={1996}
}




The idea in this version of the model is to match reward values with actual objects in the environment (seed locations and other foragers). And then create a spline map 
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
<experiments>
  <experiment name="E1" repetitions="3" runMetricsEveryStep="true">
    <setup>reset
setup
repeat 1000 [go track-data]</setup>
    <timeLimit steps="1"/>
    <metric>mean edata</metric>
    <metric>standard-deviation edata</metric>
    <metric>mean hdata</metric>
    <metric>standard-deviation hdata</metric>
    <enumeratedValueSet variable="pref">
      <value value="0.15"/>
      <value value="0.5"/>
      <value value="0.85"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-patches">
      <value value="1"/>
      <value value="3"/>
      <value value="5"/>
      <value value="7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init-seed">
      <value value="1"/>
      <value value="2"/>
      <value value="3"/>
      <value value="4"/>
      <value value="5"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
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
