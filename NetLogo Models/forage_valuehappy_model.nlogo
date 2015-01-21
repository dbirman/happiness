; Initialize variables
; Patches will have food and water
patches-own [seed? water?]
breed [foragers forager]
; Foragers will have happiness, states, and a 'score' for how much they have reproduced (a measure of fitness?)
foragers-own [hed eud hunger thirst social eud-value hed-value rep-score]

; Clears everything
to reset
  clear-all
  ask patches [set seed? false set water? false]
  reset-ticks
end

; Initializes a few patches with food and water, adds some foragers, colors patches appropriately
to setup
  ask n-of init-food patches [set seed? true]
  ask n-of init-water patches with [not seed?] [set water? true]
  create-foragers init-foragers [setxy random-xcor random-ycor set hunger random 100 set thirst random 100 set social random 100 set eud-value eud-value-init set hed-value hed-value-init]
  patch-color
end

; The "tick" function. This moves the foragers around and then updates the patches.
to go
  foragers-do
  patches-do
  tick
end

;;;;;;;;;;;;;;
;; FORAGERS ;;
;;;;;;;;;;;;;;

; Called by "go"
; Each forager updates its hedonic and eudaimonic values appropriately, deals with its needs, acts, and then evaluates its surroundings to decide where to move
; Note: the first line kills foragers who are very hungry, thirsty, or without enough socializing. If you turn this on you have to also turn on reproduction.
to foragers-do
  ask foragers [
    ;if random-float 1 < (hunger * hunger * .00001 / 3 + thirst * thirst * .00001 / 3 + social * social * .00001 / 3) [die]
    set eud get-eud
    set hed get-hed
    ; Calculate your needs
    forager-needs
    ;; REPORTS: NORTH, EAST, SOUTH, WEST
    ; Eat/drink/socialize/reproduce
    forager-action
    ; Move to the direction with the highest value!
    forager-evaluate
  ]
end

; Called by 'foragers-do'
; Foragers function
; Figures out what direction this forager considers the 'best' direction to move in (overweighting its current location), then moves there
to forager-evaluate
  let values forager-value
  ;; Okay, now pick the best direction and break ties randomly
  let mval max values
  let mpatches [] ;; This will be a list of the best directions to go
  if item 0 values = mval [set mpatches lput patch-at 0 0 mpatches]
  if item 1 values = mval [set mpatches lput patch-at 0 1 mpatches]
  if item 2 values = mval [set mpatches lput patch-at 1 0 mpatches]
  if item 3 values = mval [set mpatches lput patch-at 0 -1 mpatches]
  if item 4 values = mval [set mpatches lput patch-at -1 0 mpatches]
  let np one-of mpatches
  if not (np = nobody) [
  face np
  move-to np
  ]
end

; called by 'foragers-do'
; Foragers function
; Decides what action the forager will do on this tick, determined by whether I am hedonically or eudaimonically happy/unhappy
; Foragers reproduce when they're both eudaimonically and hedonically happy
; Foragers eat/drink when they're eudaimonically happy but hedonically unhappy (temporary unhappiness)
; Foragers socialize when they're eudaimonically unhappy but hedonically happy (long-term unhappiness)
; Foragers will do everything except reproduce when they're just toally unhappy
;
; Note: If on-hedeud (a switch in the interface) is not enabled, it just picks randomly from the possible actions
to forager-action
  ifelse on-hedeud [
    ifelse eud > eud-value
    [
      ifelse hed > hed-value [
        ;; EUD HAPPY, HED HAPPY
        ;; // DO ??
        reproduce
      ] [
      ;; EUD HAPPY, HED UNHAPPY
      eat
      drink
      ]
    ]
    [
      ifelse hed > hed-value [
        ;; EUD UNHAPPY, HED HAPPY
        socialize
      ] [
      ;; EUD UNHAPPY, HED UNHAPPY
      eat
      drink
      socialize
      ]
    ]
  ]
  [
    run one-of (list task eat task drink task socialize task reproduce)
  ]
end

; Called by 'foragers-do'
; Gets the value of moving in each of the possible directions and compares them to staying in place
to-report forager-value
  ;; This is complicated, we want to look in four directions and figure out the "value" of this direction to this forager.
  ;; This works by looking out and discounting each direction's seed, water, and social availability.
  ;; First, get the values for each direction
  let directions get-directions
  let mult item 5 directions
  let hval get-mult-list [32] get-value-list item 0 directions 
  let nval get-mult-list mult get-value-list item 1 directions
  let eval get-mult-list mult get-value-list item 2 directions
  let sval get-mult-list mult get-value-list item 3 directions
  let wval get-mult-list mult get-value-list item 4 directions
  report (list sum hval sum nval sum eval sum sval sum wval)
end

; Helper function
; Calculates the value of a specific patch
to-report get-value [p]
  let r (count patches with [seed?] / count patches with [water?])
  if p = nobody [report 0]
  report count (other foragers-on p) * social * soc-mult + food-mult * hunger * [ifelse-value seed? [1] [0]] of p + thirst-mult * thirst * r * [ifelse-value water? [1] [0]] of p
end

; Updates this foragers needs (0->100 max)
to forager-needs
  set hunger hunger + 1
  if hunger > 100 [set hunger 100]
  set thirst thirst + 1
  if thirst > 100 [set thirst 100]
  set social social + 1
  if social > 100 [set social 100]
end

;;;;;;;;;;;;;
;; ACTIONS ;;
;;;;;;;;;;;;;

; Eat whatever is on this patch
to eat
  if [seed? = true] of patch-here [set hunger 0 ask patch-here [set seed? false]]
end

; Drink from the water on this patch
to drink
  if [water? = true] of patch-here [set thirst 0]
end

; Socialize with other foragers here
to socialize
  if count other foragers-on patch-here > 0 [set social 0]
end

; If you can, reproduce (this costs you hunger/thirst/social, but increases your "score")
; The score is a read-out of forager fitness, more or less
to reproduce
  ;if count other foragers-on patch-here > 0 and hunger < 20 and thirst < 20 and social < 20 [new-forager]
  if count other foragers-on patch-here > 0 and hunger < 20 and thirst < 20 and social < 20  [set rep-score rep-score + 1
  set hunger hunger + 10
  set thirst thirst + 10
  set social social + 10
  ]
  ;set hunger 50
  ;set thirst 50
  ;set social 50
end

;;;;;;;;;;;;;
;; PATCHES ;;
;;;;;;;;;;;;;

; Called by 'go'
; Checks to see if we should add more food
; Updates each patches color
to patches-do
  if random-float 1 < seed-rate [ask one-of patches with [not seed?] [set seed? true]]
  patch-color
end

; Called by 'patches-do'
; Sets patch colors appropriately
to patch-color
  ask patches [
    if seed? [set pcolor green]
    if water? [set pcolor blue]
    if not seed? and not water? [set pcolor black]
  ]
end

;;;;;;;;;;;;;
;; HELPERS ;;
;;;;;;;;;;;;;

; Adds a new forager, can be used to by 'reproduce' to add new foragers to the world
to new-forager
  hatch-foragers 1 [set hunger 10 set thirst 10 set social 10 set eud-value random-normal [eud-value] of myself mut-rate set hed-value random-normal [hed-value] of myself (mut-rate * 2)] 
end

; Returns my eudaimonic happiness (how well i'm doing on not being hungry/thirsty/non-social)
to-report get-eud
  report (300 - hunger - thirst - social) / 300
end

; Returns my hedonic happiness (did I recently eat, drink, or socialize)
to-report get-hed
  report (ifelse-value (hunger < 10) [1] [0]) + (ifelse-value (thirst < 10) [1] [0]) + (ifelse-value (social < 10) [1] [0])
end

; Mapping function to map 'get-value' onto a list
to-report get-value-list [plist]
  report map get-value plist
end

; Mapping function to multiply a list by a fixed value
to-report get-mult-list [mult plist]
  report (map [?1 * ?2] mult plist)
end

; Returns a large array containing all of the different patches in each direction, uses an algorithm to pick up the patches within distance 5 patches in all directions
to-report get-directions
  let STAY (list patch-here)
  let NORTH []
  let EAST []
  let SOUTH []
  let WEST []
  let weight []
  foreach [1 2 3 4 5] [
    let layer ?
      foreach map [? - layer] (n-values (3 + (2 * (layer - 1))) [?]) [
        set NORTH (sentence NORTH (patch-at ? layer))
        set EAST (sentence EAST (patch-at layer ?))
        set SOUTH (sentence SOUTH (patch-at ? (- layer)))
        set WEST (sentence WEST (patch-at (- layer) ?))
        set weight (sentence weight (16 / (1 + layer)))
    ]
  ]
  report (list STAY NORTH EAST SOUTH WEST weight)
end
@#$#@#$#@
GRAPHICS-WINDOW
207
10
668
492
5
5
41.0
1
10
1
1
1
0
0
0
1
-5
5
-5
5
1
1
1
ticks
8.0

BUTTON
7
49
71
82
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
7
10
71
43
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
136
9
199
42
Run
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

PLOT
680
13
981
232
Hunger, Thirst, Social
NIL
NIL
0.0
10.0
0.0
100.0
true
true
"" "if count foragers > 0 [\nset-current-plot-pen \"hmean\"\nplot mean [hunger] of foragers\nset-current-plot-pen \"tmean\"\nplot mean [thirst] of foragers\nset-current-plot-pen \"smean\"\nplot mean [social] of foragers\nforeach [who] of foragers [\nset-current-plot-pen \"hunger\"\nplotxy ticks [hunger] of forager ?\nset-current-plot-pen \"thirst\"\nplotxy ticks [thirst] of forager ?\nset-current-plot-pen \"social\"\nplotxy ticks [social] of forager ?\n]\n]"
PENS
"hunger" 1.0 2 -5509967 true "" ""
"thirst" 1.0 2 -5516827 true "" ""
"social" 1.0 2 -526419 true "" ""
"tmean" 1.0 0 -13791810 true "" ""
"smean" 1.0 0 -1184463 true "" ""
"hmean" 1.0 0 -13840069 true "" ""

SLIDER
14
130
186
163
food-mult
food-mult
0
1
0.5
.05
1
NIL
HORIZONTAL

SLIDER
16
176
188
209
thirst-mult
thirst-mult
0
1
0.2
.05
1
NIL
HORIZONTAL

SLIDER
17
219
189
252
soc-mult
soc-mult
0
1
0.1
.05
1
NIL
HORIZONTAL

SLIDER
18
268
190
301
seed-rate
seed-rate
0
5
0.35
0.05
1
NIL
HORIZONTAL

PLOT
681
239
881
389
Eudaimonic
NIL
NIL
0.0
10.0
0.0
1.0
true
false
"" "if count foragers > 0 [\nset-plot-x-range ticks - 90 ticks + 10\nset-current-plot-pen \"pen-1\"\nforeach [who] of foragers [ plotxy ticks [get-eud] of forager ? ]\nset-current-plot-pen \"default\"\nplot mean [get-eud] of foragers\n]"
PENS
"default" 1.0 0 -16777216 true "" ""
"pen-1" 1.0 2 -4539718 true "" ""

PLOT
885
239
1085
389
Hedonic
NIL
NIL
0.0
10.0
0.0
3.0
true
false
"" "if count foragers > 0 [\nset-plot-x-range ticks - 90 ticks + 10\nset-current-plot-pen \"pen-1\"\nforeach [who] of foragers [plotxy ticks (random-float 1 - .5) + [hed] of forager ?]\nset-current-plot-pen \"default\"\nplot mean [hed] of foragers\n]"
PENS
"default" 1.0 0 -16777216 true "" ""
"pen-1" 1.0 2 -3026479 true "" ""

SLIDER
17
317
189
350
eud-value-init
eud-value-init
0
1
0.71
.01
1
NIL
HORIZONTAL

SLIDER
17
358
189
391
hed-value-init
hed-value-init
0
3
3
.5
1
NIL
HORIZONTAL

PLOT
993
13
1193
163
Foragers
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
"default" 1.0 0 -16777216 true "" "plot count turtles"

PLOT
1094
241
1294
391
Hed-V Eud-V
NIL
NIL
0.0
10.0
0.0
2.0
true
true
"" "if count foragers > 0 [\nset-current-plot-pen \"hed-V\"\nplot mean [hed-value] of foragers\nset-current-plot-pen \"eud-V\"\nplot mean [eud-value] of foragers\n]"
PENS
"hed-V" 1.0 0 -16777216 true "" ""
"eud-V" 1.0 0 -7500403 true "" ""

SLIDER
17
405
189
438
mut-rate
mut-rate
0
1
0
.01
1
NIL
HORIZONTAL

SWITCH
91
89
207
122
on-hedeud
on-hedeud
1
1
-1000

SLIDER
683
434
855
467
init-water
init-water
0
10
3
1
1
NIL
HORIZONTAL

SLIDER
684
470
856
503
init-food
init-food
0
100
10
1
1
NIL
HORIZONTAL

SLIDER
685
401
857
434
init-foragers
init-foragers
0
100
15
1
1
NIL
HORIZONTAL

PLOT
869
393
1069
543
Rep-Score
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" "if count foragers > 0 [\nset-plot-x-range ticks - 90 ticks + 10\nset-current-plot-pen \"pen-1\"\nforeach [who] of foragers [ plotxy ticks [rep-score] of forager ? ]\nset-current-plot-pen \"default\"\nplot mean [rep-score] of foragers\n]"
PENS
"default" 1.0 0 -16777216 true "" ""
"pen-1" 1.0 2 -7500403 true "" ""

@#$#@#$#@
# Forager Value Model

## Purpose

This model was designed to explore the happiness of _minimally social foragers_ within a variable environment. Foragers track their happiness over time as they eat, drink, and socialize.

## Entities, State Variables, and Scales

### Patches

The patches make up a square, edge-wrapped, grid of 11x11 cells (the edge-wrapping therefore makes this world a torus). Patches can become _seeded_ in which case they get enough food to feed a forager. Patches can also be _water_ sources. A patch can have an unlimited number of foragers present at any given time.

### Foragers

Foragers are independent agents who have a location. On each tick foragers evaluate their needs, determine their current happiness, make an action (eat/drink/socialize/reproduce), and then move. Foragers always move to the neighboring location (4neighbor) that has the highest 'value', a weighted function of their needs * what is on the patches in that direction. Foragers consider staying put as well.

## Design Concepts

### Basic Principles

Foragers are a simplified example of an organism trying to solve the problem of _foresight_ in a complex and varying environment [1]. 

1/20/2015 - I am continuing to update this...

### Adaptation: Hunger

### Objectives

NOT IMPLEMENTED

### Learning

### Prediction

NOT IMPLEMENTED

### Sensing and Error

### Interaction

### Stochasticity

### Collectives

### Observation

Currently 

## Initialization

Press __Reset__ to clear all data, graphs, and the environment. Press __Setup__ to add an intial layer of food, water, and foragers. Press __Run__ to launch the simulation.

## Input Data

## Submodels

# Credits and References

This model was implemented by Daniel Birman, according to the outline proposed in [1], using NetLogo [2]. The valuehappy concept (predicting future happiness from present value) is derived from Boltzmann exploration where choices are made probabilistically relative to the expected reward. The model descriptions follows the ODD (Overview, Design concepts, Details) protocol [3, 4].

## References

[1] Edelman, S. (2014). Explorations of happiness: proposed research. Personal Communication.

[2] Grimm, V., Berger, U., Bastiansen, F., Eliassen, S., Ginot, V., Giske, J., ... & DeAngelis, D. L. (2006). A standard protocol for describing individual-based and agent-based models. Ecological modelling, 198(1), 115-126.

[3] Grimm, V., Berger, U., DeAngelis, D. L., Polhill, J. G., Giske, J., & Railsback, S. F. (2010). The ODD protocol: a review and first update. Ecological Modelling, 221(23), 2760-2768.

[4] Wilensky, U. (1999). NetLogo. http://ccl.northwestern.edu/netlogo/. Center for Connected Learning and Computer-Based Modeling, Northwestern Institute on Complex Systems, Northwestern University.
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
