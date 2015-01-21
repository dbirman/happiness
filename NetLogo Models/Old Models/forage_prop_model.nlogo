;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Forage "Proportions" Model ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;; NEUROETHOLOGY IDEAS: ;;;;;

;; The MVT holds that in a spare environment, where the rate of food intake on a single patch decreases as the food disappears (because "searching" for the food takes more time)
;; suggests that the ideal time to switch is when caloric intake rate drops below the average rate for the environment (learned).
;; To approximate the MVT each forager has an evolved threshold value which (the average environmental food rate) which it uses to determine whether to move or stay in a given week. 

breed [foragers forager]
foragers-own [food age p-g p-e p-m p-o p-mt ate? prev-eat life-eat]
globals [death-by-hunger death-by-age dead]
patches-own [pfood]


;; AUTOMATIC LAUNCH

to auto
  reset
  while [ticks < 100] [
    go
  ]
  add-foragers
  while [ticks < 500 and count foragers > 0] [
    go
  ]
end

;; RESET
to reset
  clear-all
  reset-ticks
end

;; RUN SIMULATION (one-week)
to go
  do-patches
  do-foragers
  do-cleanup
  tick
end

;;;;;;;;;;;;;;;;;;;;
;; MAIN FUNCTIONS ;;
;;;;;;;;;;;;;;;;;;;;

to do-patches
  ask patches [
    if pfood >= 50 [ set pfood pfood + food-grow-rate
      set pfood pfood + count neighbors with [pfood >= 50] * food-grow-rate
      if random 100 < 1 [ask one-of neighbors [if pfood = 0 [set pfood 50]]]
    ]
     if pfood > max-pfood [set pfood max-pfood]
  ]
  ;; One each tick, one patch gets seeded randomly
  if random-float 1 < .25 [ ask one-of patches [set pfood 50] ]
end

to do-foragers
  ask foragers [ forager-basics ]
  forager-run
  ask foragers [ forager-norm-vals ]
  forager-die
end

;;;;;;;;;;;;;;;;;;;;;
;; FORAGER RUN ;;
;;;;;;;;;;;;;;;;;

to forager-run
  ;; Start off by gathering, if you can
  forager-gather
  ;; Now eat
  forager-eat
  ;; Now, observe and move
  ask foragers [ forager-move forager-obs ]
  ;; Now, socialize!
  ;;forager-soc
  ;; Now, reproduce!
  forager-mate
end

to forager-gather
  ask foragers [
    let pre [pfood] of patch-here * p-g
    ask patch-here [set pfood pfood - pre]
    set prev-eat pre
    set food food + pre
    set life-eat life-eat + pre
  ]
end

to forager-eat
  ask foragers with [p-e >= .01] [
    if food >= 1 [
      set ate? true
      set food food - 1
    ]
  ]
end

to-report forager-obs
  let observed []
  let counter .04
  while [p-o >= counter] [
    set observed (list observed one-of neighbors)
    set counter counter + .04
  ]
  report observed
end

to forager-move [obs]
  ;;1/2 random, 1/2 uphill
  if prev-eat < life-eat [
    ;;show sort obs
    ;;show map patch-pfood-error (sort obs)
    ;;show best-move-to obs
    let counter .04
    while [p-m >= counter] [
      ifelse length obs > 0 [
        let np best-move-to obs
        face np
        move-to np
      ]
      [
        ifelse random-float 1 < .5
        [uphill pfood]
        [
          let np one-of neighbors
          face np
          move-to np
        ]
      ]
      set counter counter + .04
    ]
  ]
end

to forager-mate
  ask foragers [
    if random-float 1 < p-mt and food > 0 and count foragers in-radius 1 < 10 and age > 100 and age < 400 [
      set food food - 1
      hatch-foragers 1 [
        set food 1
        set color [color] of myself + random-float 1 - .5
        set p-g [p-g] of myself + random-float .1 - .05
        set p-e [p-e] of myself + random-float .1 - .05
        set p-m [p-m] of myself + random-float .1 - .05
        set p-mt [p-mt] of myself + random-float .1 - .05
        set age 0
        set ate? true
        set life-eat 0
      ]
    ]
  ]
end

;;;;;;;;;;;;;;;;;;;;;;
;; HELPER FUNCTIONS ;;
;;;;;;;;;;;;;;;;;;;;;;

to-report best-move-to [obs]
  ;; Takes a series of observed patches and returns the highest-valued one (pfood)
  ;; If the same patch shows up twice, it simply gets two opportunities to be observed. In order to not overvalue
  ;; by always taking the maximum, we pull duplicates out first.
  set obs sort obs ;; Sort by patches, so that equal patches will be on the same slot
  report map-max obs map patch-pfood-error obs
end

to-report map-max [plist mlist] ;; Reports the maximum of "mlist", after removing any doubles
  while [length plist > 1] [
    ifelse first plist = item 1 plist [
      ;; Same item, average mlist and remove
      set plist remove-item 1 plist
      set mlist replace-item 0 mlist ((item 0 mlist + item 1 mlist) / 2)
      set mlist remove-item 1 mlist
    ][
      ifelse first mlist > item 1 mlist + 1 [
        set plist remove-item 1 plist
        set mlist remove-item 1 mlist
      ][
        set plist remove-item 0 plist
        set mlist remove-item 0 mlist
      ]
    ]  
  ]
  report first plist
end

to-report patch-pfood-error [curp]
  report random-normal [pfood] of curp (error-rate * [pfood] of curp)
end

to forager-die
  ask foragers [ 
    if ate? = false [set death-by-hunger death-by-hunger + 1 set dead dead + 1 die ]
    if age > 500 and random 500 < (age - 500) [set death-by-age death-by-age + 1 set dead dead + 1 die]
  ]
end

to-report count-no [as]
  if as = nobody [report 0]
  report count as
end

to forager-basics
  set age age + 1
  set ate? false
end

to add-food
  ask n-of 10 patches [ set pfood 50 ]
  do-cleanup
end

to forager-norm-vals
  let total p-g + p-e + p-m + p-o + p-mt
  set p-g p-g / total
  set p-e p-e / total
  set p-m p-m / total
  set p-o p-o / total
  set p-mt p-mt / total
end

to add-foragers
  create-foragers num-fors [
    setxy random-xcor random-ycor
    set age 0
    set p-g .2
    set p-e .2
    set p-m .2
    ifelse on-obs [ set p-o .2 ] [set p-o 0] 
    set p-mt .2
    forager-norm-vals
    set life-eat 0
  ]
end

to do-cleanup
  ask patches [
    ifelse pfood > 0 [set pcolor 62 + 7 * pfood / max-pfood]
    [set pcolor black]
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
272
10
711
470
16
16
13.0
1
10
1
1
1
0
1
1
1
-16
16
-16
16
1
1
1
ticks
30.0

BUTTON
9
9
72
42
NIL
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
82
10
145
43
run
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

BUTTON
9
49
91
82
NIL
add-food
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
96
50
268
83
max-pfood
max-pfood
0
10000
100
100
1
NIL
HORIZONTAL

BUTTON
10
88
91
121
Foragers
add-foragers
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
96
90
268
123
num-fors
num-fors
0
500
89
1
1
NIL
HORIZONTAL

SLIDER
13
133
185
166
food-grow-rate
food-grow-rate
0
100
5
1
1
NIL
HORIZONTAL

PLOT
722
11
922
161
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

BUTTON
65
335
249
368
PRESS-HERE (AUTOMATIC)
auto
NIL
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
170
188
203
error-rate
error-rate
0
1
0.1
.1
1
NIL
HORIZONTAL

SWITCH
11
476
114
509
on-obs
on-obs
0
1
-1000

PLOT
724
178
924
328
Gather - Eat - Obs - Move - Mate
NIL
NIL
1.0
6.0
0.0
1.0
false
false
"set-plot-pen-interval 1" "clear-plot\nif count foragers > 0 [\nplotxy 1 mean [p-g] of foragers\nplotxy 2 mean [p-e] of foragers\nplotxy 3 mean [p-o] of foragers\nplotxy 4 mean [p-m] of foragers\nplotxy 5 mean [p-mt] of foragers\n]"
PENS
"default" 1.0 1 -16777216 true "" ""

PLOT
929
13
1129
163
Food
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" "if count foragers > 0 [ plot mean [food] of foragers ]"
PENS
"default" 1.0 0 -16777216 true "" ""

MONITOR
1141
14
1216
59
Patch Food
mean [pfood] of patches with [pfood > 0]
2
1
11

PLOT
931
180
1131
330
Age
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
"default" 1.0 0 -16777216 true "" "if count turtles > 0 [ plot mean [age] of turtles]"

BUTTON
149
10
228
43
One Tick
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

PLOT
725
336
925
486
Eating
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" "if count turtles > 0 [\nset-current-plot-pen \"Avg\"\nplot mean [life-eat / (age + 1)] of turtles\nset-current-plot-pen \"Prev\"\nplot mean [prev-eat] of turtles\n]"
PENS
"Avg" 1.0 0 -16777216 true "" ""
"Prev" 1.0 0 -7500403 true "" ""

PLOT
933
338
1133
488
Deaths
time
norm
0.0
10.0
0.0
1.0
true
true
"" "if count turtles > 0 [\nset-current-plot-pen \"Age\"\nplot death-by-age / dead\nset-current-plot-pen \"Hunger\"\nplot death-by-hunger / dead\n]"
PENS
"Age" 1.0 0 -1184463 true "" ""
"Hunger" 1.0 0 -5825686 true "" ""

MONITOR
1136
341
1193
386
Dead
dead
0
1
11

@#$#@#$#@
# Forage "Proportions" Model

# README FIRST:

Right now the model doesn't implement what's written below. It only has foragers who are very simple. On each timestep they either move randomly, or move to the visible patch (neighbors only) with the highest patch food value. They will gather food on the patch and eat one food per timestep. Any forager who doesn't eat on a timestep dies.

That's all! Press the "auto" button to launch it with a basic configuration that works pretty well.

## Purpose

This model was designed to explore the happiness of _minimally social foragers_ within a variable environment. Foragers track their happiness over time as they gather food, share it, and mate with each other.

This is (v5) of the model, v4 explored a model of foragers using hourly ticks, where on each hour the forager could perform one "task". v1-3 explored simplified versions of this same model. v5 replaces the tick spacing of one hour with one week. Instead of using a multitude of variables to track behavior, it is assumed that agents simply spend a "proportion" of each week doing each activity. The proportions give them happiness

## Entities, State Variables, and Scales

### Patches

Each patch is a large space (perhaps a 1x1 kilometer), which can contain _food_ and  _foragers_. Food appears on patches depending on how much food there was there previously (think grass growth), food growth depends on the amount of food in the area (seeds spread by wind I suppose), so each patch gets +100 food per week minimum, and an additional +100 food for each neighbor with food. The chance of spreading food to a neighbor is 3/100 (so on average every 2/3 of a year grass spreads to a neighbor).

### Foragers

Foragers spend their time on patches. Each week a forager devotes a certain amount of time to a variety of activities, including: gathering food, sharing food, eating food, socializing, reproducing, observing the surroundings, and moving to a new patch.

A forager's main need is to eat, and they do so each week by either consuming their own food, or getting food from another forager. A forager who doesn't get anything to eat in a week dies.

Foragers age, the simulation models one year as 50 weeks. Between ages 1 and 30 foragers can do all activities (this could be replaced by a version where between 1 and 10 foragers can only eat/socialize, a way of imitating childhood). After age 30 foragers can no longer reproduce. Foragers die at age 50 (2500 ticks).

### Linked Foragers

Socializing connects two foragers permanently. Foragers who are linked will always choose to share food, reproduce, and socialize, with their links or links-of-links before doing these activities with strangers.

## Process overview and scheduling

Each tick of the simulation runs in the following steps:
 1. Basics
  i. Age foragers, kill old foragers.
  ii. Kill foragers who were unable to eat.
 2. Patches
  i. Increase food on patches
 3. Foragers
  i. Ask each surviving forager to determine its next weeks proportions for activities.
  ii. Deal with activities (linking, reproducing, etc), create new foragers, add links, etc.
 4. Cleanup
  i. Deal with visuals (patch color)

Because on each week the order of events may affect future events within the same week, the order of foragers on each week should be stochastic. 

### Basic Principles

Foragers are a simplified example of an organism trying to solve the problem of _foresight_ in a complex and varying environment [1]. Foragers do this by attempting to solve a simple minimization problem. Each forager has an ideal ratio of activities (some hedonic, some eudaimonic), they receive feedback each week on the difference from their ratio and their ideal ratio. Foragers then adjust their next week's ratio (with some randomness), to try to learn their ideal ratio.

### Adaptation

### Objectives

NOT IMPLEMENTED

### Learning

### Prediction

### Sensing and Error

Foragers can make the decision to change their patch if they think they can obtain more food (or obtain food more consistently) on another patch. To do this they look at neighboring patches (depending on how much time they apportion, more or less patches) and they get back a value for the food on each patch. The value is sampled from a normal distribution with the true mean of the patch and a standard deviation of _error_. A forager who changes patches always goes to the maximum food patch, or if linked, to the patch with the balance of linked friends and food. Foragers can see in all 8 directions.

### Interaction

### Stochasticity

### Collectives

### Observation

Currently 

## Initialization

Pressing the __Reset__ button will set all patches to be un-seeded and kill all existing foragers. Pressing the __Seed Food__ button will seed __init-seed-count__ patches. Pressing the __Add Foragers__ button adds __forager-count__ foragers to the world in random locations, their initial eating threshold is set by the __default-thresh-eat__ variable. They will spawn with _100 energy_ and their initial task will be to _sit_.

## Input Data

The model does not use input. Eventually, the mimic the response of groups to external forcings it may be helpful to use input from real sources (such as food growth patterns in  desert, tropical, or temperate environments).

## Submodels

Within one week a forager devotes a certain amount of time to each of the following activities:

### Submodel Details

The submodels rely on apportioning time into "sub-ticks". Each tick is broken down into 100 sub ticks (think ~14 hours / day of awake time). Each of the models below refers to how much can be done in a sub-tick, although all of this is modeled only at a abstractly.

Although in the abstract sense the submodels shouldn't run in any order, in reality some of the models depend on the others, so I run them in the following order: observe, move, gather, share, eat, socialize, reproduce. Each model is run for all foragers before moving to the next sub-model.

### Gathering Food

One sub-tick is enough time for a forager to gather 1 food. Foragers gather food synchronously, for example: if we have three foragers who want to gather 1, 2, and 3 food, and we have 4 food available, all three foragers will get their first food. The last food will be split between the foragers with 2 and 3 time.

### Sharing Food

Foragers don't have to gather food, they can also obtain it from other foragers who share their food stock. Sharing occurs in the same way as gathering, all the shared food is put into a pool, and all the foragers trying to obtain food get it in the same way.

### Eating Food

If a forager has food on them then they will spend their time eating it. A forager needs to eat 1 food per week to survive to the next round. 

### Socializing

For each sub-tick devoted to socializing a forager will find one neighbor (looking first for linked neighbors or links-of-links, then strangers) and establish or strengthen the link with them.

### Reproducing

For each sub-tick there is a 1/100 chance of reproducing.

### Observing

For each sub-tick the forager will get one measurement of a random neighboring patch's pfood level (taken from a normal distribution with true mean and error). If a forager measures the same patch twice they will average those measurements. Foragers "trust" their measurements based on distance, so the patch they are on is trusted completely, while patches one move away are only trusted at 75% of the observed value.

### Moving

For each sub-tick the forager will make one comparison, first between the patch it is on and one of the observed patches, then between the winner and the next available observed patch. The forager then moves to the winner of all these comparisons.

The ranking takes into account both the observed food and the number of linked foragers on the patch:

(current) vs. (new)
If new has 0 food, then current
Calculate the difference in food and the difference in linked foragers (diff_pfood, diff_lfor)
If diff_pfood and diff_lfor are both > 0

# Credits and References

This model was implemented by Daniel Birman, according to the outline proposed in Edelman 2014, using NetLogo (Wilensky 1999). The model descriptions follows the ODD (Overview, Design concepts, Details) protocol (Grimm et al. 2006, 2010). The MVT concept comes from Charnov 1976, Hayden et al. 2011, and especially Adams et al. 2012--which drives the algorithms in this document.

## References

Adams, G. K., Watson, K. K., Pearson, J., & Platt, M. L. (2012). Neuroethology of decision-making. Current opinion in neurobiology, 22(6), 982–9. doi:10.1016/j.conb.2012.07.009

Charnov, E. L. (1976). Optimal foraging, the marginal value theorem. Theoretical population biology, 9(2), 129-136.

Edelman, S. (2014). Explorations of happiness: proposed research. Personal Communication.

Grimm, V., Berger, U., Bastiansen, F., Eliassen, S., Ginot, V., Giske, J., ... & DeAngelis, D. L. (2006). A standard protocol for describing individual-based and agent-based models. Ecological modelling, 198(1), 115-126.

Grimm, V., Berger, U., DeAngelis, D. L., Polhill, J. G., Giske, J., & Railsback, S. F. (2010). The ODD protocol: a review and first update. Ecological Modelling, 221(23), 2760-2768.

Hayden, B. Y., Pearson, J. M., & Platt, M. L. (2011). Neuronal basis of sequential foraging decisions in a patchy environment. Nature neuroscience, 14(7), 933–9. doi:10.1038/nn.2856

Wilensky, U. (1999). NetLogo. http://ccl.northwestern.edu/netlogo/. Center for Connected Learning and Computer-Based Modeling, Northwestern Institute on Complex Systems, Northwestern University.
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
  <experiment name="experiment" repetitions="2" runMetricsEveryStep="false">
    <setup>reset
  while [ticks &lt; 50] [
    go
  ]
  add-foragers</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles</metric>
    <enumeratedValueSet variable="on-obs">
      <value value="false"/>
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="food-grow-rate">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="error-rate">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-pfood">
      <value value="5000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-fors">
      <value value="500"/>
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
