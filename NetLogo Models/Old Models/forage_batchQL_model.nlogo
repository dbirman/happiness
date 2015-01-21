breed [foragers forager]

patches-own [seed? penergy ps fs]
foragers-own [next-task taskn hed eud-val time-eat time-soc time-rep prev-in prev-sol prev-err prev-hed age]

globals [m-mat]
extensions [matrix profiler]
  

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
  ;;set m-mat matrix:from-row-list [[-0.214616554484611 0.7339873070414322 1.6938437581265358 0.9878659399869423 1.4770991200153674] [3.1095586516078897 -1.9440145382618885 -0.40520276034981345 -6.12559829253334 -0.6623781624068499] [-1.503740216909707 2.905454628241707 -1.4285428528462663 4.403804669186012 0.412269636466878] [-1.7264770491168822 -1.2824932789182664 3.906587718337165 -2.585300731414685 0.9599937445891163] [0.7083895084193246 -1.698468301010443 -6.969400147251367 2.0979369614422727 3.545676768738642] [2.109395291008595 0.7362351056865766 2.6993697062216655 -0.9261320209016717 -2.17869160431636] [-1.8556775570780288 0.21096910306235508 7.656283130525085 -4.160485554735606 -2.5888732641243197] [5.233729715547469 -2.2929460341055856 -11.6512468994418 4.738076993060867 1.4503138178158652] [-3.980914623266723 -1.3465242404592732 2.2848448443740113 -2.85047741309292 -4.506040013073056] [0.976411814993666 -1.5089956090918906 0.6835705482755982 -4.0039498667279165 -9.383351707034125]]
  set m-mat matrix:from-column-list (list zeros zeros zeros zeros zeros)
  set m-mat mod-matrix m-mat
end

to setup
  patches-add
  foragers-add
end

to go
  patches-do
  foragers-do
  tick
end

;;;;;;;;;;;;;;
;; FORAGERS ;;
;;;;;;;;;;;;;;

to foragers-add
  create-foragers num-foragers [fhelper-init]
end

to foragers-do
  ;ask max-n-of 10 foragers [time-eat] [die]
  ;ask n-of 10 foragers [hatch-foragers 1 [set color color + random-normal 0 .2 set time-eat 0 set time-soc 100 set time-rep 100 set m-mat mod-matrix m-mat set age 0]]
  ask foragers [
    let v fhelper-values
    let sol fhelper-calc-out v
    forager-pick-task sol
    fhelper-discount v sol ;; Q-Learning
    fhelper-basics
    run next-task
  ]
end

to-report fhelper-values
  let te ifelse-value (time-eat > 20) [-1] [1]
  let ts ifelse-value (time-soc > 30) [-1] [1]
  let tr ifelse-value (time-rep > 50) [-1] [1]
  ;;SENSES
  set prev-in (sentence hed (eud-val / 50 - 1) (count foragers-on patch-here) te ts tr prev-sol)
  report matrix:from-row-list (list prev-in)
end

to-report fhelper-calc-out [values]
  let sol calc-sol values
  set prev-sol sol
  ;; Now find the maximum from solution
  report sol
end

to forager-pick-task [sol]
  ;let bsol boltz sol
  let i position (max sol) sol + 1 ;(max bsol) bsol + 1
  fhelper-snt i
end

to-report calc-sol [values]
  let sol map [sig ?] (matrix:get-row matrix:times values m-mat 0)
  ;; Use Boltzmann's equation to modify
  report sol
end

to-report boltz [values]
  let e_v map [e ^ (? / boltz-temp)] values
  report map [? / (sum e_v)] e_v
end

to fhelper-discount [values sol]
  ;;WHAT DO I HAVE:
  ; prev-in :: Previous input values
  ; values :: Current input values
  ; sol :: Current solution
  ; prev-sol :: Previous solution
  ; hed :: Current reward
  ; prev-hed :: Previous reward
  ;;NOTE: To get hed we had to actually complete this action, since it wouldn't be possible to calculate that in advance... (this could be implemented)
  
  ;; Q-Learn: Q(s,a) = (1-b) * IMMEDIATE REWARD + (b) * BEST POSSIBLE FUTURE REWARD (i.e. given optimal action, what is my reward)
  let i taskn - 1 ;; This is the position in solution of the task we chose
  
  ;; USING Q-LEARNING Q(s,a) = (1-B) * Q(s,a) + B * (r + gV(s')), where V(s') = max action Q(s',a) (i.e. best reward expected from s')

  ;let new-Q (1 - beta) * prev-hed + beta * (prev-hed + gamma * hed)
  let new-q prev-hed + gamma * item i sol
  
  let c matrix:get-column m-mat i
  let dw 0
  ;; USING BACK-PROPAGATION
  foreach n-values length prev-in [?] [
    let target new-Q
    let output item i prev-sol
    let err output * (1 - output) * (target - output)
    set dw ((learn-rate) * err * item ? prev-in)
    set c replace-item ? c (item ? c + dw)
  ]
  matrix:set-column m-mat i c
  
  set prev-hed hed
  set prev-err dw
end

;;;;;;;;;;;;;
;; ACTIONS ;;
;;;;;;;;;;;;;

to move-rand
  let dir one-of neighbors4
  face dir
  move-to dir
end

to move-ps
  let dir uphill-ps
  face dir
  move-to dir
end

to move-fs
  let dir uphill-fs
  face dir
  move-to dir
end

to eat
  if [penergy] of patch-here > 0 [
    set time-eat 0
    ask patch-here [set penergy penergy - 1]
  ]
end

to soc
  if count other foragers-on patch-here > 0 [
    set time-soc max (list (time-soc - time-soc * count foragers-on patch-here) 0)
  ]
end

to rep
  if random-float 1 < rep-rate and count other foragers-on patch-here > 0 [
    set time-eat time-eat + 10
    set time-rep 0
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
    set fs fs + .01 * count foragers-here
    if penergy > 0 [
      set penergy penergy - const-energ-dec
      set ps log (penergy + 1) 10
    ]
    if penergy < 0 and seed? [set penergy 0 set pcolor 0 set seed? false ask one-of patches with [seed? = false] [phelper-init]]
    set ps ps * evaporation + (log evaporation 10)
    set fs fs * evaporation + (log evaporation 10)
    if fs < 0 [set fs 0] if ps < 0 [set ps 0]
    ifelse fs = 0
    [set fs 0
      ifelse ps = 0 [ set ps 0 set pcolor black]
      [set pcolor 52 + ps * 6]
    ]
    [set pcolor 12 + fs * 6]
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
end

to-report fhelper-translate-task [val]
  if val = 1 [report task move-ps]
  if val = 2 [report task move-fs]
  if val = 3 [report task eat]
  if val = 4 [report task soc]
  if val = 5 [report task rep]
end

to-report fhelper-calc-eud
  report 100 - (.5 * time-eat + .3 * time-soc + .2 * time-rep)
end

to fhelper-basics
  set age age + 1
  set time-eat time-eat + 1
  if time-eat > mem [set time-eat mem];die]
  set time-soc time-soc + 1
  if time-soc > mem [set time-soc mem]
  set time-rep time-rep + 1
  if time-rep > mem [set time-rep mem]
  let neud fhelper-calc-eud
  if ticks > 2 [set hed neud - eud-val + ifelse-value (time-rep < 15) [15 - time-rep] [0]]
  set eud-val neud
end

to fhelper-init
  setxy random-xcor random-ycor
  set color one-of base-colors
  set hed 0
  set eud-val 0
  set prev-in [0 0 0 0 0 0 0 0 0 0 0]
  set time-eat random 100
  set time-soc random 100
  set time-rep random 100
  set age random 0
  set prev-sol [0 0 0 0 0] ;; Q-matrix, always starts at zero
  set prev-err 0 ;; Reward, starts at zero
  fhelper-snt 1
end

to-report zeros
  report [0 0 0 0 0 0 0 0 0 0 0]
end
to-report mod-matrix [m]
  report matrix:from-row-list map [modmod ?] matrix:to-row-list m
end

to-report modmod [v]
  ifelse ticks = 0 [report map [random-normal ? mut-rate] v]
  [report map [ifelse-value (random-float 1 < error-rate) [random-normal ? mut-rate] [?]] v]
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

to mprint [m]
  print matrix:pretty-print-text m
end

to-report sig [v]
  ifelse v < 25 and v > -25 [report 1 / (1 + e ^ (- v))] [report 0]
end
@#$#@#$#@
GRAPHICS-WINDOW
210
15
639
465
20
20
10.22
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
20.0

SLIDER
32
60
204
93
num-patches
num-patches
0
100
15
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
13
222
185
255
evaporation
evaporation
.99
.9999
0.993
.0005
1
NIL
HORIZONTAL

SLIDER
12
266
184
299
error-rate
error-rate
0
1
0.15
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
1000
500
25
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
700
74
989
299
plot 1
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot count foragers"

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
"" "if count foragers > 0 [\nplot mean [eud-val] of foragers\n]"
PENS
"default" 1.0 0 -16777216 true "" ""

PLOT
929
314
1129
464
PS -- FS -- Eat -- Soc -- Rep
NIL
NIL
1.0
6.0
0.0
1.0
true
false
"" "if count foragers > 1 [\nclear-plot\nforeach [1 2 3 4 5] [\nplotxy ? count foragers with [taskn = ?] / count foragers\n]\n]"
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

SLIDER
1075
47
1247
80
gamma
gamma
0
1
0.89
.01
1
NIL
HORIZONTAL

SLIDER
1075
91
1247
124
boltz-temp
boltz-temp
0
10
4
1
1
NIL
HORIZONTAL

SLIDER
1079
139
1251
172
learn-rate
learn-rate
0
1
0.01
.01
1
NIL
HORIZONTAL

SLIDER
1073
179
1245
212
delta
delta
0
1
0.1
.01
1
NIL
HORIZONTAL

SLIDER
1071
219
1243
252
N+
N+
1
2
1.2
.01
1
NIL
HORIZONTAL

INPUTBOX
1070
260
1225
320
dMax
2
1
0
Number

INPUTBOX
1226
263
1381
323
dMin
1.0E-4
1
0
Number

SLIDER
1078
10
1250
43
beta
beta
0
1
0.9
.01
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
  <experiment name="E1-compare-difficulty" repetitions="5" runMetricsEveryStep="false">
    <setup>reset
setup</setup>
    <go>go</go>
    <timeLimit steps="10000"/>
    <metric>matrix:to-row-list mean-m-mat</metric>
    <metric>count foragers</metric>
    <enumeratedValueSet variable="max-penergy">
      <value value="25"/>
      <value value="50"/>
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
