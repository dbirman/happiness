;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Forager Task Model (Daniel Birman, 1/25/2014) ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;FORAGERS SETUP
breed [foragers forager]
foragers-own [food energy thresh-eat cur-task ctn memory age aim hed eud]
links-own [strength]
;;OTHER SETUP
patches-own [seed? pfood]

;;RESET
to reset
  clear-all
  reset-ticks
  ask patches [set seed? false]
end

;;RUN ONE TICK
to go
  tick
  do-basics
  do-patches
  do-foragers
  do-cleanup
  ;;tick ;;Always at the end
end

;;ADD FORAGERS
to add-foragers
  create-foragers forager-count [
    setxy random-xcor random-ycor
    forager-basic-setup -1 100 ;;The -1 is for default thresholds
  ]
end

;;SEED FOOD
to seed-grass
  ask patches with [seed? = 0] [set seed? false]
  let counter init-seed-count
  while [counter > 0] [
    ask one-of patches [set seed? true]
    set counter counter - 1
  ]
  patch-color ;; We altered patch content, so check if we need to color them.
end

;;AGING, METABOLISM, DEATH
to do-basics
  ask links [
    set strength strength - 1
    if strength <= 0 [ die ] 
  ]
  ask foragers [
    set age age + 1
    set energy energy - 1
    if age >= 250 [ die ]
    if energy <= 0 [ die ]
    set hed hed - 1
    set eud eud - 1
  ]
end

;;PATCHES
to do-patches
  patch-food-increase
end

to patch-food-increase
  ask patches [
    if seed? [
      ifelse pfood <= max-pfood [
        set pfood pfood + init-food-tick + ( init-food-tick * floor (pfood / grow-rate) )
      ]
      [ set pfood max-pfood ]
    ]
  ]
end

;;FORAGERS
to do-foragers
  ask foragers [ run cur-task ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; FORAGER TASKS BEGIN HERE ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; 1 GATHER
to FT-gather
  ifelse [pfood] of patch-here > 0 [
    ask patch-here [
      let cfood 0
      ifelse pfood > max-gather
      [set cfood max-gather]
      [set cfood pfood]
      set pfood pfood - cfood
      ask myself [set food food + cfood]
    ]
    set eud eud + gather-eud
    FT-new-check-energy
  ]
  [ 
    let fpatch find-max-food-patch
    ifelse not (fpatch = nobody) [
      FT-new 5
      set aim fpatch
    ]
    [ FT-new 4 ]
  ]
end

;; 2 EAT
to FT-eat
  ifelse food > 0
  [ 
    let ceat 0
    ifelse food > max-eat
    [ set ceat max-eat ]
    [ set ceat food ]
    set food food - ceat
    set energy energy + ceat
    set hed hed + eat-hed
    FT-new-check-energy
  ]
  [ FT-new 1 ]
end

;; 3 SHARE
to FT-share
  ifelse food > thresh-eat [
    let mforage find-min-food-forager
    ifelse not (mforage = nobody) [
      ifelse distance mforage > .5
      [ set aim [patch-here] of mforage
        FT-new 5
      ]
      [ set food food - share-amount
        ask mforage [set food food + share-amount] ;;TODO - an alternative is to replace the "share-amount", which is sort of silly, with averaging?
        set hed hed + share-hed
        set eud eud + share-eud
        FT-new 8
      ]
    ]
    [ FT-new 8 ]
  ]
  [ FT-new 2 ]
end

;; 4 WANDER
to FT-wander
  set aim one-of neighbors
  set cur-task task FT-walktowander ;; This is the only place I don't use FT-new, because I want them to keep "wandering" with some probability
end

to FT-walktowander
  face aim
  move-to min-one-of neighbors [aim-distance]
  set energy energy - move-cost
  set eud eud + wander-eud
  ifelse random 100 < cont-wander-perc * 100 [FT-new 4] [FT-new 8]
end

;; 5 WALK-TO
to FT-walkto
  face aim
  move-to min-one-of neighbors [aim-distance]
  set energy energy - move-cost
  set eud eud + walkto-eud
  if patch-here = aim
  [ FT-new 8 ]
end

;; 6 SOCIALIZE
to FT-socialize
  ifelse count link-neighbors > 0 [
    ;; I have at least 1 neighbor, pick one randomly
    let pneigh one-of link-neighbors
    ifelse distance pneigh < .5
    [
      ask link-with pneigh [
        ifelse strength > link-double
        [ set strength strength * 2 ]
        [ set strength link-double ] 
      ]
      set energy energy - soc-cost
      set eud eud + social-eud
    ]
    [ set aim [patch-here] of pneigh 
      FT-new 5
    ] 
  ]
  [ let pneigh one-of other foragers in-radius max-trust-dist
    ifelse not (pneigh = nobody) [
      ifelse distance pneigh < .5 
      [
        create-link-with pneigh [ set strength link-double ]
        set energy energy - soc-cost
        set eud eud + social-eud
      ]
      [
        set aim [patch-here] of pneigh
        FT-new 5
      ]
    ]
    [ FT-new 8 ]
  ]
end

;; 7 MATE
to FT-mate ;;IDENTICAL TO SOC BUT ALSO CREATES A NEW FORAGER
  ifelse count link-neighbors > 0 [
    ;; I have at least 1 neighbor, pick one randomly
    let pneigh one-of link-neighbors
    ifelse distance pneigh < .5
    [
      ask link-with pneigh [
        ifelse strength > link-double
        [ set strength strength * 2 ]
        [ set strength link-double ] 
      ]
      set energy energy - mate-cost - mate-energy-transfer
      create-new-forager
      set hed hed + mate-hed
    ]
    [ set aim [patch-here] of pneigh 
      FT-new 5
    ] 
  ]
  [ let pneigh one-of other foragers in-radius max-trust-dist 
    ifelse not (pneigh = nobody) [
      ifelse distance pneigh < .5 
      [
        create-link-with pneigh [ set strength link-double ]
        set energy energy - mate-cost - mate-energy-transfer
        create-new-forager
        set hed hed + mate-hed
      ]
      [
        set aim [patch-here] of pneigh
        FT-new 5
      ]
    ]
    [ FT-new 8 ]
  ]
end

;; 8 SIT (boredom)
to FT-sit
  let tlist [1 2 3 4 5 6 7]
  if not on-gather [set tlist remove 1 tlist]
  if not on-eat [set tlist remove 2 tlist]
  if not on-share [set tlist remove 3 tlist]
  if not on-wander [set tlist remove 4 tlist]
  if not on-walkto [set tlist remove 5 tlist]
  if not on-social [set tlist remove 6 tlist]
  if not on-mate [set tlist remove 7 tlist]
  ifelse on-hedeud
  []
  [ FT-new one-of tlist ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; JANITOR FUNCTIONS BEGIN HERE ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;RUN JANITORS
to do-cleanup
  patch-color
end

;;COLOR PATCHES
;;DEFAULT: BLACK, SEED? DARK GREEN, FOOD? LIGHT GREEN
to patch-color
  ask patches [
    if seed? = true [
      ifelse pfood < 100
      [ set pcolor 62 ]
      [ set pcolor 62 + ( pfood / max-pfood * 5 ) ]
      set plabel pfood
    ]
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; HELPER FUNCTIONS BEGIN HERE ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to create-new-forager
  hatch-foragers 1 [
    forager-basic-setup mutate-threshold mate-energy-transfer
    set color color + ( random-float 1 ) - .5
  ]
end

to-report mutate-threshold
  report random-normal [thresh-eat] of myself mutation-rate
end

to FT-new-check-energy
  ifelse energy > thresh-eat
  [ FT-new 8 ]
  [ ifelse food > 0 [FT-new 2] [FT-new 1] ]
end
;;SET NEW TASK AND DEAL WITH MEMORY
to FT-new [new-task]
  set cur-task number-to-task new-task
  set ctn new-task
  set memory lput new-task memory
  while [length memory > mem-length] [ set memory but-first memory ]
end

;;FIND THE MIN FORAGER FOOD (ERROR CONSTRAINED)
to-report find-min-food-forager
  if not any? foragers in-radius max-trust-dist with [food < [food] of myself] [report nobody]
  ifelse on-error
  [ report min-one-of foragers in-radius max-trust-dist [forager-forager-error-trust] ]
  [ report min-one-of foragers in-radius max-trust-dist [food] ]
end

;;FIND THE MAX FOOD PATCH (ERROR CONSTRAINED)
to-report find-max-food-patch
  if not any? patches in-radius max-trust-dist with [pfood > 0] [report nobody]
  ifelse on-error
  [ report max-one-of patches in-radius max-trust-dist [patch-forager-error-trust] ]
  [ report max-one-of patches in-radius max-trust-dist [pfood] ]
end

to-report number-to-task [num]
  if num = 1 [report task FT-gather]
  if num = 2 [report task FT-eat]
  if num = 3 [report task FT-share]
  if num = 4 [report task FT-wander]
  if num = 5 [report task FT-walkto]
  if num = 6 [report task FT-socialize]
  if num = 7 [report task FT-mate]
  if num = 8 [report task FT-sit]
end

to-report aim-distance
  report distance [aim] of myself
end

to forager-basic-setup [te ie]
  set food 0
  set energy ie
  ifelse te > 0 [set thresh-eat te] [set thresh-eat default-thresh-eat]
  set cur-task task FT-sit
  set memory []
  set age 0
  set aim patch-here
end

to-report forager-forager-error-trust
  report forager-error-trust food (distance myself)
end

to-report patch-forager-error-trust
  report forager-error-trust pfood (distance myself)
end
to-report forager-error-trust [ real dist ]
  ifelse dist > max-trust-dist
  [ report 0 ]
  [ report (with-error real dist) * ( 1 - (dist - 1) / max-trust-dist ) ]
end

to-report with-error [ real dist ]
  report random-normal real ( real * error-perc * dist )
end
@#$#@#$#@
GRAPHICS-WINDOW
529
21
946
459
18
18
11.0
1
10
1
1
1
0
1
1
1
-18
18
-18
18
1
1
1
ticks
30.0

BUTTON
9
8
73
41
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
15
131
121
164
Add Foragers
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
126
131
298
164
forager-count
forager-count
0
1000
69
1
1
NIL
HORIZONTAL

BUTTON
17
75
107
108
Seed Food
seed-grass
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
119
77
291
110
init-seed-count
init-seed-count
0
1000
30
10
1
NIL
HORIZONTAL

CHOOSER
303
78
395
123
max-pfood
max-pfood
100 1000 10000 25000 50000 100000
2

BUTTON
85
9
140
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

BUTTON
150
10
229
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

CHOOSER
401
78
493
123
grow-rate
grow-rate
10 100 250 500 1000 10000
1

SLIDER
307
132
479
165
default-thresh-eat
default-thresh-eat
0
250
51
1
1
NIL
HORIZONTAL

SLIDER
21
435
193
468
error-perc
error-perc
0
1
0.1
.01
1
NIL
HORIZONTAL

SLIDER
16
172
188
205
max-trust-dist
max-trust-dist
0
10
4
1
1
NIL
HORIZONTAL

SWITCH
210
437
326
470
on-hedeud
on-hedeud
1
1
-1000

SLIDER
17
210
189
243
max-gather
max-gather
0
100
50
1
1
NIL
HORIZONTAL

SLIDER
196
213
368
246
max-eat
max-eat
0
100
39
1
1
NIL
HORIZONTAL

CHOOSER
375
217
513
262
move-cost
move-cost
0.01 0.1 0.25 0.5 1 2 5 10
2

SWITCH
336
439
439
472
on-error
on-error
0
1
-1000

SLIDER
197
173
369
206
mem-length
mem-length
0
100
25
1
1
NIL
HORIZONTAL

SLIDER
18
248
190
281
share-amount
share-amount
0
25
25
1
1
NIL
HORIZONTAL

PLOT
967
10
1218
160
Energy + Food
time
count
0.0
10.0
0.0
10.0
true
true
"" "set-plot-x-range ticks - 500 ticks + 50\nif count turtles > 0 [\nset-current-plot-pen \"E-max\"\nplot max [energy] of turtles\nset-current-plot-pen \"F-max\"\nplot max [food] of turtles\nset-current-plot-pen \"E-mean\"\nplot mean [energy] of turtles\nset-current-plot-pen \"F-mean\"\nplot mean [food] of turtles\n]"
PENS
"E-max" 1.0 0 -5298144 true "" ""
"E-mean" 1.0 0 -2674135 true "" ""
"F-max" 1.0 0 -15575016 true "" ""
"F-mean" 1.0 0 -10899396 true "" ""

SLIDER
298
42
470
75
init-food-tick
init-food-tick
0
25
5
1
1
NIL
HORIZONTAL

SLIDER
19
288
191
321
link-double
link-double
0
1000
500
100
1
NIL
HORIZONTAL

CHOOSER
374
169
512
214
soc-cost
soc-cost
1 2 5 10 25
0

CHOOSER
373
265
511
310
mate-cost
mate-cost
2 5 10 25
0

CHOOSER
369
315
515
360
mate-energy-transfer
mate-energy-transfer
25 50 100 200
0

SLIDER
19
330
191
363
mutation-rate
mutation-rate
0
100
10
1
1
NIL
HORIZONTAL

PLOT
967
173
1167
323
# Foragers
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" "set-plot-x-range ticks - 500 ticks + 50"
PENS
"Forager #" 1.0 0 -16777216 true "" "plot count foragers"

SLIDER
199
251
371
284
cont-wander-perc
cont-wander-perc
0
1
0.5
.1
1
NIL
HORIZONTAL

PLOT
967
332
1167
482
Threshold Tracker
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" "set-plot-x-range ticks - 500 ticks + 50\nif count turtles > 0 [\nset-current-plot-pen \"max\"\nplot max [thresh-eat] of turtles\nset-current-plot-pen \"mean\"\nplot mean [thresh-eat] of turtles\nset-current-plot-pen \"min\"\nplot min [thresh-eat] of turtles\n\n]"
PENS
"max" 1.0 0 -16777216 true "" ""
"mean" 1.0 0 -7500403 true "" ""
"min" 1.0 0 -4539718 true "" ""

SWITCH
22
478
133
511
on-gather
on-gather
0
1
-1000

SWITCH
144
479
247
512
on-eat
on-eat
0
1
-1000

SWITCH
254
482
359
515
on-share
on-share
1
1
-1000

SWITCH
368
482
484
515
on-wander
on-wander
1
1
-1000

SWITCH
492
484
602
517
on-walkto
on-walkto
1
1
-1000

SWITCH
606
483
710
516
on-social
on-social
1
1
-1000

SWITCH
718
480
821
513
on-mate
on-mate
0
1
-1000

MONITOR
1230
11
1353
56
Seed Average Food
mean [pfood] of patches with [seed? = true]
2
1
11

PLOT
1173
174
1373
324
Age
time
NIL
0.0
10.0
0.0
10.0
true
false
"" "set-plot-x-range ticks - 500 ticks + 50\nif count foragers > 0 [\n;;set-current-plot-pen \"max\"\n;;plot max [age] of foragers\nset-current-plot-pen \"mean\"\nplot mean [age] of foragers\n]"
PENS
"max" 1.0 0 -16777216 true "" ""
"mean" 1.0 0 -7500403 true "" ""

PLOT
1174
333
1374
483
plot 1
Tasks
Count
1.0
9.0
0.0
10.0
false
false
"" "if count foragers > 0 [\nset-plot-y-range 0 ceiling ( ( count foragers ) / 2 )\nhistogram [ctn] of foragers\n]"
PENS
"default" 1.0 1 -16777216 true "" ""

PLOT
967
490
1167
640
hed / eud
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" "set-plot-x-range ticks - 500 ticks + 50\nif count foragers > 0 [\nset-current-plot-pen \"hed-eud\"\nlet z 0\nask n-of 10 foragers [set z z + hed - eud]\nplot z / 10\n]"
PENS
"hed-eud" 1.0 0 -16777216 true "" ""

CHOOSER
24
521
162
566
gather-eud
gather-eud
5
0

CHOOSER
169
524
307
569
eat-hed
eat-hed
10
0

CHOOSER
314
525
452
570
share-eud
share-eud
10 15
1

CHOOSER
315
580
453
625
share-hed
share-hed
15
0

CHOOSER
456
528
594
573
wander-eud
wander-eud
10
0

CHOOSER
599
530
737
575
walkto-eud
walkto-eud
10
0

CHOOSER
745
532
883
577
social-eud
social-eud
5 15
1

CHOOSER
742
603
880
648
mate-hed
mate-hed
5 15
1

@#$#@#$#@
# Forage Task Model

## Purpose

This model was designed to explore the happiness of _minimally social foragers_ within a variable environment. Foragers track their happiness over time as they gather food, share it, and mate with each other.

## Entities, State Variables, and Scales

### Patches

The patches make up a square, edge-wrapped, grid of 32x32 cells. Each patch can be _seeded_, in which case they produce food at a rate of __init-food-tick__ each tick of the simulation. Food growth is exponential and depends on the quantity of food on the patch, every __grow-rate__ food that accumulates increases the rate (linearly). Food on a patch cannot exceed __max-pfood__. 

### Foragers

Foragers are independent agents who have a location and a current task. You can control how foragers pick their tasks and which tasks are available using the on-off switches. Foragers can: _gather, eat, share, wander, walk-to, socialize, mate, and sit_.

### Linked Foragers

Foragers who perform the socialize or mate tasks will become _linked_ to other foragers. When choosing a partner to socialize or mate with the foragers always prefer to choose a linked partner over a random partner.

### Time

The simulation is designed so that 100 ticks reflects approximately one week. The default values of variables reflect this fact.

## Process overview and scheduling

Each tick of the simulation runs in four steps:
 1. Basics
   i. Reduce the strength of links
   ii. Age foragers
   iii. Take 1 energy from all foragers (basic metabolism)
   iiii. Kill foragers with energy <= 0
 2. Patches
   i. Increase the food on seeded patches
 3. Foragers
   i. Ask foragers to complete their current task
 4. Cleanup
   i. Deal with visuals (e.g. patch color)

Time is _asynchronous_ and moves forward in _ticks_. Dealing with the order of tasks on one tick is non-trivial, because some tasks cause interactions between foragers (energy sharing, linking) which can affect their behavior on the same tick. The model currently implements the second option:

 1. Run all tasks, then update all state variables at the end of the tick.
 2. Randomly order the foragers on each tick, then run tasks in order.

## Design Concepts

### Basic Principles

Foragers are a simplified example of an organism trying to solve the problem of _foresight_ in a complex and varying environment [1]. 

### Adaptation: Hunger

Foragers, like all organisms, rely on energy to survive and flourish. The simplest organisms imaginable use basic strategies to obtain and store energy and in this case foragers do as well. All foragers have a _hunger threshold_, below which they will try to gather food and eat their gathered food. When foragers are NOT hungry, they may still choose to engage in these activities (perhaps because they are pleasurable), but they may also choose to socialize, share, or mate, activities which they will not do when hungry.

### Objectives

NOT IMPLEMENTED

### Learning

Foragers do not learn over time. 

### Prediction

NOT IMPLEMENTED

### Sensing and Error

Foragers sense the world visually and with a certain amount of error, an attempt to replicate the difficulty of viewing the world we live in. Short of introducing full Bayesian statistics into each agent (a possibility to consider for the future), I chose to simply treat each "viewing" of the world as uniquer. Thus, on each view, agents receive a sample from a normal distribution with a true mean and a standard deviation which reflects their distance from the viewed object.

> SD = Distance * __error-perc__

Foragers existing in such a world would have eventually evolved a coping strategy, again, short of literally evolving this strategy, I chose to introduce a simplified version. Foragers simply have a _window of trust_ within which they linearly reduce the observed values for objects.

> Trust Value = Error Value * ( 1 - Distance / __max-trust-dist__ )

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

Each of the tasks which a forager can carry out is its own submodel, they are described in detail within this section.

### Sit
A sitting forager is _bored_ and will decide, on this tick, what task to do next.
#### Hedonic/Eudaimonic Model
(TODO: This isn't implemented)

To decide what to do next I imagine that foragers are guided by two kinds of joy in their simple lives. Hedonic joy is defined as immediate pleasures, these include eating food, sharing food, and mating. Eudaimonic joys are longer-term pleasures, such as gathering food, wandering, walking-to somewhere, socializing, and sharing.

Each forager has a ratio of hedonic to eudaimonic tasks, my first attempt will simply be to use 25:25. When foragers sit because they have nothing to do next, they will then choose what to do based on the balance of hedonic/eudaimonic tasks they have recently done. They only have a memory for the 50 previous tasks.

There is a "random" task mode in which, unless they are hungry, foragers will simply choose randomly between tasks.
#### Random Model
Foragers choose randomly, with equal probability, from the available tasks (those that are _on_ in the switches).
### Walk-To
When a forager has an _aim_, they will move to the patch which minimizes their distance to their aim. They will continue this task until they arrive on the patch they are aiming at, at which point they _sit_. Moving has a cost: __move-cost__.
### Wander
Foragers wander by choosing a random patch to move to next. With probability __cont-wander-perc__ a forager will continue to _wander_, or _sit_.
### Gather
If there is food available on a patch the forager will collect __max-gather__ of it. If there is no food available they will aim at a visible patch with the highest food, subject to error (see _Design Concepts: Error_). If all patches are equal they choose randomly. If they are below eating threshold they then _eat_, otherwise they _sit_.
### Eat
If the forager has food on hand they will eat __max-eat__ of it, adding an equal amount of energy. If they have no food on hand they switch to _gather_. After eating they will _eat_ again if they are below eating threshold, otherwise they _sit_.
### Share
If the forager has surplus food they will pick a visible forager with the minimum food on hand and aim at them. If they are on the same patch, they will give them __share-amount__ food. After sharing foragers _sit_.
### Socialize & Mate
Both socializing and mating occur according to the same rules. Foragers first pick a random linked neighbor, or if un-linked, stranger, and either aim and walk to them or socialize/mate with them (if on the same patch). Socializing consists of creating a new link with strength __link-double__. If a link exists and has strength > link-double / 2, the strength doubles. Mating adds that the forager who initiated contact hatches a new offspring and gives them __mate-energy-transfer__ initial energy. Their eating threshold is picked from a normal distribution with mean of their parent and standard deviation __mutation-rate__. Socializing and mating have a cost: __soc-cost__ and __mate-cost__.

# TODO List

 - Foragers have no energy or food limits at the moment
 - Add hedonic/eudaimonic stuff

# Credits and References

This model was implemented by Daniel Birman, according to the outline proposed in [1], using NetLogo [2]. The model descriptions follows the ODD (Overview, Design concepts, Details) protocol [3, 4].

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
