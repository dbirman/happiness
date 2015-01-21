breed [trees tree]
breed [squirs squir]
breed [flowers flower]
flowers-own [age frate]
trees-own [srate]
patches-own [apples pollen]
squirs-own [energy speed hed eud hed_a eud_s eud_p]
links-own [lage]


to setup
  clear-all
  create-trees 10 [
    setxy random-xcor random-ycor
    set srate random new-srate
    set shape "circle"
    set color green
  ]
  reset-ticks
end

to add-squirrels
  create-squirs num-squirrels [
    setxy random-xcor random-ycor
    set energy 100
    set speed random 5 + 1
    set hed 0
    set eud 0
    set hed_a random 100 / 100
    set eud_s random 100 / 100
    set eud_p random 100 / 100
  ]
end

to go
  ;; First lets deal with apples and moving them around
  tr-drop_apples
  pa-roll_apples
  fl-age
  fl-smell
  tr-replace
  ;; Second lets let the squirrels wander around and eat some apples
  if count squirs > 0 [sq-go]
  ;; Finally update the color of the patches
  pa-colorize
  l-age
  tick
end

to l-age
  ask links [set lage lage + 1]
  ask links [if lage > 50 [die]]
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
     [ let col 10 + apples / 20
       ifelse col <= 15
       [set pcolor col] [set pcolor red]
     ]
     [ let col 40 + pollen / (1 + m)
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

to tr-replace
  if ticks mod 300 = 0 [
    ask n-of 2 trees [
      let r srate
      hatch-flowers 1 [
        set age random 250
        set frate r
        set shape "circle"
        set color yellow
        setxy random-xcor random-ycor]
      die
    ]
  ]
end

to sq-go
  ;; To decide whether a squirrel will eat, socialize, mate, or move, we first check their overall strategy
  ask squirs [
    ifelse hed > eud
    [sq-hed] ;; Hedonic motivation means they will either EAT, FOLLOW APPLES, or RANDOM WALK
    [ ifelse hed = eud [ifelse random 2 = 0 [sq-hed] [sq-eud]] [sq-eud] ];; Eudaimonic motivation means they will either SOCIALIZE, FOLLOW POLLEN, LINK WALK, or RANDOM WALK
  ]
  ;; Every 100 ticks the 10 worst squirrels die and are replaced with the 10 best squirrel's attributes
  sq-evolve
  sq-boredom
end

to sq-hed
  ;;A hedonic motivated squirrel will eat or move uphill, based on whether it is hungry (E < 500).
  sq-follow_apples
end

to sq-eat
  ;; At most a squirrel can eat 10 apples at a time, which gives them 100 energy.
  let change 0
  ifelse [apples] of patch-here > max-apple-consumption
  [ask patch-here [set apples apples - max-apple-consumption]
    set change max-apple-consumption * energy-per-apple]
  [let cur_app apples
    ask patch-here [set apples 0]
    set change energy-per-apple * cur_app]
  set energy energy + change
  ;;Since we just ate we get a boost to our hedonic aspect, that boost is evolutionary though (based on the hed_a multiplier)
  set hed hed + hed_a * change
end

to sq-follow_apples
  let cur_p patch-here
  uphill apples
  ifelse not (cur_p = patch-here) 
  [ set energy energy - 5 ] ;; It costs 5 energy to switch patches
  [ ifelse [apples] of patch-here > 0 [sq-eat] [sq-random_walk]] ;; If you can't do better than this spot, eat, except if there's nothing to eat then wander
end

to sq-random_walk
  rt random 360
  fd 1
  set energy energy - 2 ;; Random walking is cheaper than regular walking
end

to sq-eud
  ifelse energy > median [energy] of squirs
  [ifelse count squirs in-radius 2 > 1
    [sq-socialize]
    [sq-follow_pollen] ;; Following pollen 
  ]
  [sq-follow_pollen] ;; Socializing equalizes energy levels
end

to sq-follow_pollen
  let cur_p patch-here
  uphill pollen
  ifelse not (cur_p = patch-here)
  [ set energy energy - 5 ] ;; Moved uphill
  [ ifelse [apples] of patch-here > 0 [sq-eat] [sq-link_walk]] ;; If we can't move, try eating, if we can't do that then link-walk
  set eud eud + eud_p * 1
end

to sq-link_walk
  ifelse count link-neighbors > 0 [
    let friend one-of link-neighbors
    face friend
    fd 1
    set energy energy - 5 ;; Standard move 
  ]
  [ sq-random_walk ] ;; Really there's nothing to do but wander.
end

to sq-socialize
  ;; Equalize my energy with another squirrel that has energy
  if count squirs in-radius 2 > 1 [
    let o one-of other squirs in-radius 2
    if ([energy] of o) > 0 [
      create-link-with o
      let avge ([energy] of o + energy) / 2
      ask o [set energy avge]
      set energy avge
    ]
  ]
  set eud eud + eud_s * .5
end

to sq-evolve
  ;;Evolution! We kill the worst 10 squirrels and create 10 copies of the best squirrels
  let ev_squirrels round (perc-squirs-evolve * num-squirrels)
  if ticks mod 100 = 0 [
    ask min-n-of ev_squirrels squirs [energy] [die]
    ask max-n-of ev_squirrels squirs [energy] [
      set energy energy - 200
      hatch-squirs 1 [
        set energy 150
        rt random 360
        fd random 3
        sq-evolve_helper
      ]
    ]
  ]
end

to sq-evolve_helper
  set hed_a hed_a + (random .1 - .05)
  if hed_a > 1 [set hed_a 1]
  if hed_a < 0 [set hed_a 0]
  set eud_s eud_s + (random 1 - .05)
  if eud_s > 1 [set eud_s 1]
  if eud_s < 0 [set eud_s 0]
  set eud_p eud_p + (random 1 - .05)
  if eud_p > 1 [set eud_p 1]
  if eud_p < 0 [set eud_p 0]
end

to sq-boredom
  ;;Squirrel boredom causes them to lose motivation, more quickly for hedonic aspects.
  ask squirs [
    set hed hed * .5 - 1
    if hed < 0 [ set hed 0 ]
    set eud eud * .9 - 1
    if eud < 0 [ set eud 0 ]
    set energy energy - 1 ;; All squirrels use up 1 energy per turn
    
    ;;Temporary
    set label round energy
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
210
10
708
529
30
30
8.0
1
10
1
1
1
0
1
1
1
-30
30
-30
30
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
0.1
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
Average Hedonic_Apple Modifier
mean [hed_a] of squirs
2
1
11

MONITOR
725
66
929
111
Average Eudamonic Social Modifier
mean [eud_s] of squirs
2
1
11

MONITOR
725
120
933
165
Average Eudaimonic Pollen Modifier
mean [eud_p] of squirs
2
1
11

PLOT
959
16
1159
166
Modifiers
time
modifier value
0.0
10.0
0.0
1.0
true
true
"" "if count squirs > 0 [\nset-current-plot-pen \"Hedonic\"\nplot mean [hed_a] of squirs\nset-current-plot-pen \"Eudaimonic_S\"\nplot mean [eud_s] of squirs\nset-current-plot-pen \"Eudaimonic_P\"\nplot mean [eud_p] of squirs\n]"
PENS
"Hedonic" 1.0 0 -4699768 true "" "none"
"Eudaimonic_S" 1.0 0 -11085214 true "" "none"
"Eudaimonic_P" 1.0 0 -817084 true "" "none"

SLIDER
16
152
188
185
perc-squirs-evolve
perc-squirs-evolve
0
1
0.2
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
11
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
0.06
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
1
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
3
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
10
3
.01
1
NIL
HORIZONTAL

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
