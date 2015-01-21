breed [foragers forager]
foragers-own [age food patch-mem obs-count food-ratio act-ratios ifr act-list hed eud eud-hist eud-cur avg-eat prev aim]
patches-own [pfood]
links-own [strength]


;; GLOBALS FOR STATISTICS

globals [ num-tasks FR-at-death tick-time last-timer]

to reset
  clear-all
  reset-ticks
  set FR-at-death []
  set tick-time []
  set num-tasks 8
end

to go
  reset-timer
  patches-food
  if count foragers > 0 [
    do-foragers
    do-basics
  ]
  if on-matlab [send-to-matlab]
  do-cleanup
  set tick-time lput timer tick-time
  set last-timer timer
  tick
end

to auto-run
  reset
  seed
  while [ticks < 50] [go]
  if on-matlab [send-init-matlab]
  add
  while [ticks < 500 and count foragers > 0] [go]
end

;;;;;;;;;;;;;;;;
;; MAIN FUNCS ;;
;;;;;;;;;;;;;;;;

to seed
  ask n-of seed-count patches [ set pfood food-cutoff / 2 ]
  helper-color
end

to add
  create-foragers num-foragers [
    setxy random-xcor random-ycor
    helper-new-forager
  ]
end

;;;;;;;;;;;;;
;; PATCHES ;;
;;;;;;;;;;;;;

to patches-food
  ifelse remainder ticks 4 = 0 [
    ask patches with [pfood > 0] [
      if pfood >= food-cutoff [ patches-grow ]
      set pfood pfood + food-cutoff / 2
    ]
  ][;;else
    ask patches with [pfood > 0] [
      ifelse pfood >= food-cutoff
      [ set pfood pfood * 1.05 ]
      [ set pfood pfood - (food-cutoff / 10) ]
    ]
  ]
  ask patches with [pfood > max-pfood] [set pfood max-pfood]
  ask patches with [pfood < 0] [set pfood 0]
end

;; Sprout new patches, the chance of seeding is exponential with distance (sort of), this algorithm is a bit messed up. TODO
to patches-grow
   ask patches in-radius 2 [ if random-float 1 < .01 [ ifelse pfood = 0 [set pfood food-cutoff / 2] [set pfood pfood + food-cutoff / 2] ]]
end

;;;;;;;;;;;;;;
;; FORAGERS ;;
;;;;;;;;;;;;;;

;; Go through the foragers activities one-by-one
to for-do-act
  foreach act-list [run helper-num-task ?]
end

to for-kill
  if random death-rate < 1 [ die ]
  ;; If a forager has not eaten, then food ratio is < 10, so as it drops it becomes a multiplier. One week of no eating = food-ratio of 0, so 50% chance of death. Two weeks is 100%.
  if random 100 < ( 10 - food-ratio ) * 5 [
    set FR-at-death lput food-ratio FR-at-death
    die
  ]
end

;;;;;;;;;;;;;;;;
;; ACTIVITIES ;;
;;;;;;;;;;;;;;;;

to gather
  ifelse [pfood] of patch-here = 0 and food < max-food [ run task share] [ helper-gather-food ]
end

to eat
  ifelse food > 0 [ helper-inc-food set hed hed + 1] [ run task gather set hed hed - 1]
end

to share
  ;;;NOT WORKING
  let fh foragers-here with [patch-here = [patch-here] of myself]
  let mu 0
  ask patch-here [set mu mean [food] of fh]
  ask fh [set food food - (food - mu) * .1]
end

to socialize
  ifelse food-ratio < ifr [eat] [
    ifelse count my-links with [link-length < 2] > 0 [
      ask one-of my-links with [link-length < 2] [ set strength strength * 2 ] 
    ] [
    helper-c-l-w one-of other foragers-here
    ]
    set eud-cur eud-cur + 1
  ]
end

to move-somewhere
  ifelse food-ratio < ifr + 5 [move] [
    ifelse aim = patch-here [
      ;;New Aim
      if count my-links > 0 [
        set aim [patch-here] of one-of link-neighbors
      ]
    ] [
      set prev patch-here
      face aim
      move-to reduce [ifelse-value ([distance [aim] of myself] of ?1 < [distance [aim] of myself] of ?2) [?1] [?2]] (sort neighbors)
      set hed hed + 1
      set obs-count 0
      set patch-mem n-values 8 [0]
    ]
  ]
end

to reproduce
  ifelse food-ratio < ifr [eat] [
    ifelse food > min-reproduce-food and random-float 1 < .5 and count other foragers-here > 0 [ ;;This is a happy turtle, so to speak
      set food food - 30
      hatch-foragers 1 [
        helper-new-forager
        create-link-with myself [set strength 500]
        set food-ratio 5
        set food 20
        set color color + random-normal 0 1
        set act-ratios map [random-normal ? (? * .1)] ([act-ratios] of myself)
        set act-ratios map [ifelse-value (? < 0) [random-float .02] [?]] act-ratios
        helper-norm-ratios
      ]
      set hed hed + 1
    ] [set hed hed - 1]
  ]
end

to observe
  let opatch one-of neighbors
  let obs [helper-pfood-error] of opatch + count link-neighbors with [patch-here = opatch]
  let lpos helper-patch-to-index opatch
  ifelse (item lpos patch-mem) = 0
  [ set patch-mem replace-item lpos patch-mem obs ]
  [ set patch-mem replace-item lpos patch-mem ((item lpos patch-mem + obs ) / 2) ]
  set obs-count obs-count + 1
  set eud-cur eud-cur + 1
end

to move
  ifelse obs-count < min-search [run task observe] [
    ;;MOVE TO MAX LOCATION
    ifelse reduce [?1 or ?2] map [? > [helper-pfood-error] of patch-here] patch-mem [
      ifelse not ((reduce [ifelse-value (?1 < (?2 * 1.05) and ?1 > (?2 * .95)) [?1] [-1]] patch-mem) = -1)
      [helper-move one-of neighbors]
      [helper-move helper-index-to-patch position max patch-mem patch-mem]
    ]
    [] ;; Don't move, current patch is best
  ]
end

to wander
  ifelse food-ratio < ifr [
    set eud-cur eud-cur - 1
    move
  ] [
    ifelse random-float 1 < .5 [ helper-move one-of neighbors ] [ helper-move prev ]
    set eud-cur eud-cur + 1
  ]
end

;;;;;;;;;;;;;;;
;; FUNCTIONS ;;
;;;;;;;;;;;;;;;

to do-cleanup
  helper-color
end

to do-foragers
  ask foragers [
    helper-calc-act ;; Includes hedonic/eudaimonic calculations
    set avg-eat 0 set hed 0 set eud-cur 0 ;; Reset hedonic to get the next week's value
    for-do-act
    set food-ratio food-ratio - 10 ;; Use up 1 week of food
    for-kill
    set eud-hist remove-item 0 (lput (eud-cur + hed + count my-links) eud-hist) ;; Set the eud-hist
    set eud mean eud-hist ;; Average out the eudaimonic value
  ]
end

to do-basics
  ask foragers [ set age age + 1]
  ask links [
    set strength strength - link-length
    if strength <= 0 [die]
  ]
end

;;;;;;;;;;;;;
;; HELPERS ;;
;;;;;;;;;;;;;

to helper-move [npatch]
  set prev patch-here
  face npatch
  move-to npatch
  set obs-count 0
  set patch-mem n-values 8 [0]
end

to helper-c-l-w [o]
  if count my-links < max-link-count and not (o = nobody) [create-link-with o [set strength 4 ]]
end

to helper-inc-food
  if food-ratio < max-food-ratio [
    set food food - 1
    set food-ratio food-ratio + 1
  ]
end

to-report helper-pfood-error
  report random-normal pfood (pfood * .1) ;; 10% STD
end

to helper-calc-act
  set act-list []
  if on-wellbeing [
    ifelse hed > 0[
      ifelse eud > hed + 40
      [  ] ;; This is a very happy character, leave him alone! ]
      [ set act-ratios replace-item 2 act-ratios ((item 2 act-ratios) + random-normal 0 .1)
        set act-ratios replace-item 4 act-ratios ((item 4 act-ratios) + random-normal 0 .1)
        set act-ratios replace-item 6 act-ratios ((item 6 act-ratios) + random-normal 0 .1) ]
    ] 
    [ ;; Hedonic unhappiness means... EAT MORE!
      set act-ratios replace-item 0 act-ratios ((item 0 act-ratios) + random-normal 0 .1)
      set act-ratios replace-item 3 act-ratios ((item 3 act-ratios) + random-normal 0 .1)
      set act-ratios replace-item 1 act-ratios ((item 1 act-ratios) + random-normal 0 .1)
    ]
  ]
  helper-norm-ratios
  helper-basic-act-list
  set act-list shuffle act-list
end

to helper-basic-act-list
  foreach (n-values floor (100 / num-tasks) [?]) [set act-list sentence n-values num-tasks [?] act-list]
end

to helper-gather-food
  ;; FOR FUNC
  let gfood 0
  ask patch-here [
    set gfood perc-eat * pfood
    set pfood pfood - gfood
  ]
  set food food + gfood
  set avg-eat avg-eat + gfood
end

to helper-color
  ask patches [
    ifelse pfood > 0
    [ set pcolor 62 + pfood * 6 / max-pfood ]
    [ set pcolor black ]
  ]
end

to helper-new-forager
  set food 0
  set age 0
  set food-ratio 10
  set patch-mem n-values 8 [0]
  set aim patch-here
  set obs-count 0
  set act-ratios n-values num-tasks [1]
  helper-norm-ratios
  set eud-hist [0 0 0 0]
  set ifr random-normal 10 5
  set prev patch-here
end

to helper-norm-ratios
  set act-ratios map [ifelse-value (? < 0) [0] [?]] act-ratios
  set act-ratios map [? / (sum act-ratios)] act-ratios
end

to-report helper-mean-act-ratios
  ;; Take the act ratios for a sub-population of the total, then combine them along the Y axis (map basically)
  let alist [act-ratios] of foragers
  report reduce helper-comb-lists alist
end

to-report helper-comb-lists [list1 list2]
  let rlist []
  while [length list1 > 0] [
    set rlist lput ((first list1 + first list2) / 2) rlist
    set list1 remove-item 0 list1
    set list2 remove-item 0 list2
  ]
  report rlist
end

to-report helper-patch-to-index [p]
  if p = patch-at 0 1 [report 0]
  if p = patch-at 1 1 [report 1]
  if p = patch-at 1 0 [report 2]
  if p = patch-at 1 -1 [report 3]
  if p = patch-at 0 -1 [report 4]
  if p = patch-at -1 -1 [report 5]
  if p = patch-at -1 0 [report 6]
  if p = patch-at -1 1 [report 7]
  show "HELPER-patch-to-index FAILED"
end

to-report helper-index-to-patch [ind]
  if ind = 0 [report patch-at 0 1] ;;  NORTH
  if ind = 1 [report patch-at 1 1] ;;  NORTHEAST
  if ind = 2 [report patch-at 1 0] ;;  EAST
  if ind = 3 [report patch-at 1 -1] ;; SOUTHEAST
  if ind = 4 [report patch-at 0 -1] ;; SOUTH
  if ind = 5 [report patch-at -1 -1];; SOUTHWEST
  if ind = 6 [report patch-at -1 0] ;; WEST
  if ind = 7 [report patch-at -1 1] ;; NORTHWEST
  show "HELPER-index-to-patch FAILED"
end

to-report helper-num-task [num]
  if num = 0 [report task eat]
  if num = 1 [report task share]
  if num = 2 [report task socialize]
  if num = 3 [report task reproduce]
  if num = 4 [report task move]
  if num = 5 [report task gather]
  if num = 6 [report task wander]
  if num = 7 [report task move-somewhere]
end

;;;;
;; MATLAB FUNCTIONS ;;
;;;;;;;;;;;;;;;;;;;;;;

to send-to-matlab
  ;; Captures a "screenshot" of the world and sends it to the matlab run on each tick. 
  
end

to send-init-matlab
  matlab:send-double "init-foragers" count foragers
  matlab:send-double "
end
@#$#@#$#@
GRAPHICS-WINDOW
210
10
649
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
16.0

BUTTON
8
11
72
44
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
77
10
140
43
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

BUTTON
145
10
200
43
1 Tick
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

SLIDER
13
123
185
156
max-pfood
max-pfood
0
2500
200
50
1
NIL
HORIZONTAL

BUTTON
9
50
72
83
Seed
seed
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
77
50
183
83
Add Foragers
add
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
13
89
185
122
num-foragers
num-foragers
0
100
25
5
1
NIL
HORIZONTAL

SLIDER
13
157
185
190
food-cutoff
food-cutoff
0
5000
60
10
1
NIL
HORIZONTAL

PLOT
654
11
899
161
Population
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" "set-plot-x-range 0 ticks + 50"
PENS
"Foragers" 1.0 0 -16777216 true "" "plot count turtles"
"Food" 1.0 0 -13840069 true "" "plot count patches with [pfood > 0]"
"pen-2" 1.0 0 -7500403 true "" "plot count foragers with [food-ratio < ifr]"

PLOT
985
168
1222
318
 Ea - Sh - So - Re -  Mo - Ga - Wa - Ai
NIL
NIL
0.0
8.0
0.0
1.0
false
false
"" "if (remainder ticks 10) = 0 and count foragers > 0 [\nclear-plot\nlet vals helper-mean-act-ratios\nforeach n-values num-tasks [?] [plotxy ? item ? vals]\n]"
PENS
"default" 1.0 1 -16777216 true "" ""

MONITOR
910
12
979
57
Mean Age
mean [age] of foragers
1
1
11

PLOT
984
13
1184
163
Food Ratio
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" "if count foragers > 0 [\nset-plot-x-range 0 ticks + 50\nset-current-plot-pen \"default\"\nplot mean [food-ratio - ifr] of foragers\nset-current-plot-pen \"0\"\nplotxy ticks 0\n]"
PENS
"default" 1.0 0 -16777216 true "" ""
"0" 1.0 0 -7500403 true "" ""

PLOT
654
165
875
315
Hed/Eud
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" "if count turtles > 0 [\nset-plot-x-range 0 ticks + 50\nset-current-plot-pen \"hed\"\nplot mean [hed] of foragers\nset-current-plot-pen \"eud\"\nplot mean [eud] of foragers\n]"
PENS
"hed" 1.0 0 -16777216 true "" ""
"eud" 1.0 0 -7500403 true "" ""

BUTTON
31
286
178
319
500-TICK AUTO RUN
auto-run
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SWITCH
40
325
165
358
on-wellbeing
on-wellbeing
0
1
-1000

MONITOR
678
400
806
445
Food per Forager
sum [pfood] of patches / count foragers
2
1
11

SLIDER
15
416
187
449
min-search
min-search
0
50
40
1
1
NIL
HORIZONTAL

SWITCH
676
468
787
501
on-matlab
on-matlab
1
1
-1000

PLOT
825
350
1025
500
plot 1
ticks
milliseconds per forager
0.0
10.0
0.0
0.0010
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "if count turtles > 0 [plot last-timer / count turtles ]"
"pen-1" 1.0 0 -7500403 true "" "plotxy ticks .001"

SLIDER
14
236
186
269
death-rate
death-rate
0
10000
1000
100
1
NIL
HORIZONTAL

SLIDER
16
454
188
487
max-food
max-food
0
500
50
10
1
NIL
HORIZONTAL

SLIDER
207
490
379
523
max-link-count
max-link-count
0
100
10
5
1
NIL
HORIZONTAL

CHOOSER
13
369
151
414
share-percent
share-percent
0.05 0.1 0.25
1

CHOOSER
12
191
150
236
seed-count
seed-count
5 10 25
0

CHOOSER
400
490
538
535
max-food-ratio
max-food-ratio
25 50 100
0

SLIDER
20
276
192
309
perc-eat
perc-eat
0
1
0.0325
.01
1
NIL
HORIZONTAL

CHOOSER
1049
392
1187
437
min-reproduce-food
min-reproduce-food
50 100 200
0

SWITCH
29
505
140
538
on-matlab
on-matlab
1
1
-1000

@#$#@#$#@
# Forage "Proportions" Model

# README FIRST:

The idea of using 'ticks' in weeks, and 'sub-ticks' in hours is to simplify the calulation of eudaimonic/hedonic measures. My thought is that hedonic is more on the level of hours and eudaimonic is on the level of weeks, so that, weekly, we can simplify these computations. This is a step up from v4 which was only hourly and v5 which was only weekly, which both made calculation of well being very complex.

# TODO:

Consider "link-walking" as a kind of wandering activity?

## Purpose

This model was designed to explore the happiness of _minimally social foragers_ within a variable environment. Foragers track their happiness over time as they gather food, share it, and reproduce with each other.

This is (v6) of the model, v5 used weekly timesteps--but modeled activities implicitly and did not have the detail to fully capture the necessary concepts, v4 explored a model of foragers using hourly ticks, where on each hour the forager could perform one "task". v1-3 explored simplified versions of this same model. v6 combines the models from v5 and v4. Foragers "act" at the level of weekly timesteps (ticks) but the activities within those timesteps are explicitly modeled. 

## Entities, State Variables, and Scales

### Time

I refer to each tick as a "week" and each sub-tick as an "hour" for readability. This is roughly correct given that you can assume the foragers need to sleep. (So, 7*24=168, approx 1/3 sleep).

### Patches

Each patch is a large space (perhaps a 1x1 kilometer), which can contain _food_ and  _foragers_. I think of food as a grass, perhaps growing near sources of water. Every 4 weeks it "rains" which causes all the existing grass to double in quantity, as well as spread randomly to some of the nearby areas (exponential chance with distance). Grass requires other grass to reproduce with, so there is a minimum amount of grass (50) on a patch before it can spread. Grass below the 50 threshold will die off (-5/week). Grass above the threshold will grow slowly (+10%/week).

The grass on a patch is assumed to be spread randomly and thus there is an inherent difficulty in finding it for a forager on that patch. The difficulty of discovering grass is inversely related to the quantity: the relationship is simply that in one hour a forager will discover at most 1% of the available grass.

### Foragers

Each week a forager can spend their time doing several activites: gathering food, sharing food, eating food, socializing, reproducing, observing neighboring patches, and moving to a new patch. Each activity takes one hour to perform, so in one week a forager will perform 100 activities. Foragers must eat on average seven times a week, the chance of dieing on any given week. Like humans it takes ~3 weeks to die of starvation, thus the chance of dieing from not eating is 5% per hour missed (35% if you don't eat in a week). This is calculated as the running difference between eaten food and the ideal of 7/week. A foragers running average cannot exceed +21 (that is, the forager is very fat). Foragers will not waste time eating when they don't have food, instead they will try to gather food.

Foragers age and have a lifespan of up to 20 years. Ideally I would like to implement an aging system, but for the time being foragers simply have a uniform chance of dieing throughout their lifetime (which results in a roughly linear drop in age--of course we should tweak this to fit the truth. The chance of dieing is 1/1000 per week.


### Linked Foragers

Socializing, being born from, sharing with and reproducing with another forager "link" foragers together. Links deteriorate over time, reducing their strength. I tried to guess how long the memory of an encounter would last for the different kinds of links. The add-on rate is a multiplier.

Socializing: one month, x2
Birth: 10 years (no add-on)
Sharing: x1.5
Reproducing: one month, x2 (not doing this atm)

## Process overview and scheduling

Each tick of the simulation runs in the following steps:
 1. Increase or decrease the food on patches
 2. Grow new food patches if necessary
 3. Calculate the ratio of activities for all of the foragers.
 4. Ask the foragers to go through their activities (ideally hour-by-hour)
 5. Age foragers and kill off old foragers.
 6. Kill foragers who didn't eat enough.
 7. Update the visuals

The order that foragers are processed in is random on each hour.

### Basic Principles

## Hedonic and Eudaimonic Well Being

For an initial attempt I take a very simplistic view of hedonic/eudaimonic well being. Hedonic well being involves not being hungry, reproduction, and sharing. Succeeding at each of these activities adds to the hedonic value, failing reduces it. Each week the hedonic value is reset. Eudaimonic well being takes into account socializing, observing, moving, and the strength of a social network, as well as the *history* of hedonic well being. The eudaimonic value does not reset, but rather is a running average of the past 4 weeks.

### Adaptation

The relative proportions of different activities which 

### Objectives

### Learning

### Prediction

### Sensing and Error

### Interaction

Linking

### Stochasticity

### Collectives

### Observation

Currently 

## Initialization

Always press "reset" first, then seed the world and add foragers. The density of foragers is highly dependent on the available food, so often it takes a minimum food availability to start up a run. The auto-run function tries to minimize the difficulty of doing this (and because it is consistent, can be used for testing model behavior over time).

## Input Data

## Submodels

### Hourly Details

Each week is broken into 100 hours. Each of the models below refers to how much activity a forager can undertake in one hour. The activities are explicitly modeled for the foragers.

### Gathering Food

A forager will gather 1% of the food on a patch. If no food is available the forager will try to share instead.

### Sharing Food

This partially equalizes the food among all of the patch-neighbors who are linked. If un-linked the forager will socialize instead. This takes 1 food from all of the neighbors with >average and distributes the food to those with <average.

### Eating Food

If a forager has food they will eat 1 food. If they don't have any food they will try to gather.

### Socializing

The forager will pick a neighbor and strengthen their link (first looks for linked neighbors, then un-linked).

### Reproducing

The forager has a 1/500 chance of reproducing (once per 5 weeks), first looks for linked neighbors then un-linked.

### Observing

This is slightly more complicated, while on one patch a forager will make "trips" so to speak out and back from neighboring patches to try and find a patch with a higher value: more food and more linked neighbors. Each trip reports back a value for the neighboring patches (from a normal dist with true mean and 10% standard dev). If they collect multiple values for the same patch they will average them. They pick patches to observe randomly. Each linked forager on a patch increases its value by 5%.

### Moving

If a forager has observed less than 20 times they will observe rather than move. If they have observed more than 20 times then they will move.

# Credits and References

This model was implemented by Daniel Birman, according to the outline proposed in Edelman 2014, using NetLogo (Wilensky 1999). The model descriptions follows the ODD (Overview, Design concepts, Details) protocol (Grimm et al. 2006, 2010). The MVT concept comes from Charnov 1976, Hayden et al. 2011, and Adams et al. 2012.

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
  <experiment name="Compare Hed/Eud to None" repetitions="10" runMetricsEveryStep="true">
    <setup>reset
seed
while [ticks &lt; 50] [go]
add</setup>
    <go>go</go>
    <timeLimit steps="500"/>
    <metric>count turtles</metric>
    <metric>count patches with [pfood &gt; 0]</metric>
    <metric>mean [hed] of turtles</metric>
    <metric>mean [eud] of turtles</metric>
    <metric>helper-mean-act-ratios</metric>
    <enumeratedValueSet variable="seed-count">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="food-cutoff">
      <value value="960"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-foragers">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min-search">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="on-wellbeing">
      <value value="true"/>
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-pfood">
      <value value="2000"/>
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
