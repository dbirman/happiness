breed [foragers forager]
patches-own [seed? seed-val penergy ps fs]
foragers-own [ntask taskn memt memv val aim e? energy age hv smem hed hmem eud emem eatmem rmem lco repc]
globals [dead seed-list next-seed mem-long wither-rate control]

extensions [profiler matrix stats];; matlab]

to example
  reset
  local-seed
  forage
  repeat example-ticks [go]
end

to reset
  clear-all
  reset-ticks
  patches-reset
  set next-seed init-si
  set mem-long mem-short * 10
  set wither-rate .05 ;; Only for visual
end

to reset-values
  ;; SET DEFAULT VALUES
  set max-seed-val 20
  set num-patches 25
  set pref .5
  set eval 5
  set h-mult .1
  set error-val .1
  set hed-eud 1
  set test-e4 false
end

to forage
  foragers-add
end

to PROFILE
  reset
  local-seed
  forage
  profiler:start
  repeat 100 [ go ]
  profiler:stop
  print profiler:report
  profiler:reset
end

to go
  ;;PATCHES
  with-local-randomness [
    if ticks = 0 [local-seed]
    cur-seed
    patches-do
  ]
  ;;FORAGERS
  foragers-do
  tick
end

;;;;;;;;;;;;;;
;; FORAGERS ;;
;;;;;;;;;;;;;;

to foragers-add
  create-foragers num-foragers [
    helper-newforager (one-of patches)
    set energy 10
  ]
end

to foragers-do
  ask foragers [
    ask patch-here [set fs fs + 1]
    foragers-die
    set age age + 1
    set rmem rmem + 1
    set smem smem + 1
    set eatmem eatmem + 1
    set val 0
    set energy energy - e-per-tick
    run ntask
    let ce calc-eud
    set hed calc-hed
    set eud ce > eval
    helper-mem (ifelse-value hed [1] [0]) ce
    pick-next-task
  ]
end

to foragers-die
  if energy <= 0 [
    set dead dead + 1
    die
  ]
end

;;;;;;;;;;;
;; TASKS ;;
;;;;;;;;;;;

to collect
  ifelse [penergy] of patch-here > 0 [
    let ge [penergy] of patch-here * collect-rate * calc-soc-multiplier
    ask patch-here [set penergy penergy - ge]
    set energy energy + ge
    set val 1
    set eatmem 0
  ] [
  set taskn 2
  observe
  ]
end

to-report calc-soc-multiplier
  report max (list ((mem-long - smem) / mem-long) 0)
end

to observe
  let pev [penergy-error] of patch-here
  helper-uphill-ps
  set val [penergy-error] of patch-here - pev
end

to socialize
  ifelse any? other foragers-on patch-here [
    set smem 0
    set val 1
  ] [ helper-uphill-fs ]
end

to wander
  let p one-of other-in-cone
  face p
  move-to p
end

to reproduce
  if random-float 1 < rep-rate [
    hatch-foragers 1 [
      helper-newforager [patch-here] of myself
      set energy rep-energy * (1 - error-val)
    ]
    set energy energy - rep-energy * (1 - error-val)
    set rmem 0
    set val 1
  ]
end

;;;;;;;;;;;;;;;;;;;;
;; FORAGER EXTRAS ;;
;;;;;;;;;;;;;;;;;;;;

to pick-next-task
  ifelse hed-eud = 1 [
    ifelse random-float 1 < pref [
      ;; HEDONIC = LESS THAN
      ifelse hed [ helper-st2 one-of [3] ] [ helper-st2 one-of [1 4] ]
    ] [
      ;; EUDAIMONIC = MORE THAN
      ifelse eud [ helper-st2 one-of [5 1 4] ] [ helper-st2 one-of [3] ]
    ]
  ] [
  ;;Not using Hed/Eud
    helper-st2 one-of [1 2 3 4 5]
  ]
end

to-report calc-hed
  report rmem < mem-short * h-mult or energy > rep-energy * h-mult * 10
end

to-report calc-eud
  ifelse test-e4
  [report helper-task-sum-value 1 false + helper-task-sum-value 4 false]
  [report helper-task-sum-value 1 false + helper-task-sum-value 4 false + helper-task-sum-value 3 false]
end

;;;;;;;;;;;;;
;; PATCHES ;;
;;;;;;;;;;;;;

;; Setup the initial patches 
to patches-seed
  ask n-of num-patches patches with [not seed?] [ helper-seedpatch ]
end

;; Add energy
to patches-do
  let mps max [ps] of patches + .01
  let mfs max [fs] of patches + .01
  let cp_seeded 0
  ask patches [
    if penergy > 0 [set ps ps + log (penergy + 1) 10]
    set ps ps * evap-perc - evap
    set fs fs * evap-perc - evap
    ifelse fs > 0 [set pcolor 42 + fs / mfs * 4] [
      set fs 0
      ifelse ps < 0 [set pcolor black set ps 0] [set pcolor 72 + ps / mps * 4]
    ] 
    ifelse seed? [
      set cp_seeded cp_seeded + 1
      set penergy penergy + seed-val
      if random-float 1 < die-chance [set seed? false]
    ] [
      ;; Wither
      set penergy penergy - const-energ-dec
      if seed-val > 0 [ set seed-val seed-val - (seed-val * wither-rate) - wither-rate ]
    ]
  ]
  if cp_seeded < num-patches [ask one-of patches [helper-seedpatch]]
  diffuse ps .5
  diffuse fs .5
end

;; Reset
to patches-reset
  ask patches [
    set seed? false
    set seed-val 0
    set penergy 0
    set ps 0
    set fs 0
  ]
end

;;;;;;;;;;;;;
;; HELPERS ;;
;;;;;;;;;;;;;

to-report helper-task-sum-value [n short]
  let l [] let l2 []
  ifelse short [set l sublist memt 0 (min (list (length memt - 1) (mem-short - 1))) set l2 sublist memv 0 (min (list (length memv - 1) (mem-short - 1)))] [set l memt set l2 memv]
  let m []
  (foreach l l2 [if ?1 = n [set m fput ?2 m] ])
  report sum m
end

to helper-mem [hedv eudv]
  set memv fput val memv
  if length memv > mem-long [set memv sublist memv 0 (mem-long - 1)]
  set memt fput taskn memt
  if length memt > mem-long [set memt sublist memt 0 (mem-long - 1)]
end

to helper-st2 [n]
  set ntask helper-num-to-task n
  set taskn n
end

to-report helper-num-to-task [num]
  if num = 1 [report task collect]
  if num = 2 [report task observe]
  if num = 3 [report task socialize]
  if num = 4 [report task reproduce]
  if num = 5 [report task wander]
  show num
end

to helper-newforager [p]
  face p
  move-to p
  helper-st2 (random 5) + 1
  set memt (list taskn)
  set memv [0]
  set hmem [0]
  set emem [0]
  set hed false
  set eud false
  set smem 0
  set rmem 0
  set eatmem 0
  set val 0
  set age 0
  set aim patch-here
end

to local-seed
  with-local-randomness [
    cur-seed
    patches-seed
  ]
end

to helper-seedpatch
  set seed? true
  set seed-val random-float max-seed-val
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

to cur-seed
  random-seed next-seed
  set next-seed random 100000
end

to helper-uphill-ps
  let p max-one-of (patches in-cone 1.5 180) [ps-error]
  face p
  move-to p
end
to helper-uphill-fs
  let p max-one-of (patches in-cone 1.5 180) [fs-error]
  face p
  move-to p
end
to-report other-in-cone ;; in-cone, but only other patches
  let p patches in-cone 1.5 180
  report p with [not (self = [patch-here] of myself)]
end

to-report fs-error
  report random-normal fs error-val
end
to-report ps-error
  report random-normal ps error-val
end
to-report penergy-error
  report random-normal penergy error-val
end

;;;;;;;;;;;;;;;;
;; MATLAB ;;
;;;;;;;;;;;;;

to send-to-matlab
  ;matlab:eval "cd('C:\\Users\\Dan\\Documents\\NetLogo Models')"
  ;matlab:send-string-list (word "variablenames_" behaviorspace-run-number) (list "soc-mult" "obs-mult" "error-std" "eat-mult" "num-patches" "collect-rate" "e-per-tick" "wan-val" "mem-short" "pref" "nhf-dropoff" "num-foragers" "max-nhf" "view-radius" "hed-eud" "max-seed-val" "init-si" "mem-long" "example-ticks" "const-energ-dec" "wither-rate" "die-chance" "ticks" )
  ;matlab:send-double-list (word "variablepacket_" behaviorspace-run-number) (list behaviorspace-run-number soc-mult obs-mult error-std  eat-mult  num-patches  collect-rate  e-per-tick  wan-val  mem-short  pref  nhf-dropoff  num-foragers  max-nhf  view-radius  hed-eud  max-seed-val  init-si  mem-long  example-ticks  const-energ-dec  wither-rate  die-chance ticks)
  ;matlab:send-string-list (word "groupnames_" behaviorspace-run-number) (list "mean energy" "count)
  ;matlab:send-double-list (word "datagroup_0_" behaviorspace-run-number) sentence behaviorspace-run-number ([energy] of foragers)
  ;matlab:send-double (word "datagroup_1_" behaviorspace-run-number) mean [energy] of foragers
  ;matlab:send-double (word "datagroup_2_" behaviorspace-run-number) count foragers
end
@#$#@#$#@
GRAPHICS-WINDOW
219
10
649
461
40
40
5.19
1
10
1
1
1
0
1
1
1
-40
40
-40
40
1
1
1
ticks
30.0

BUTTON
6
8
70
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
71
10
134
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

CHOOSER
98
43
190
88
max-seed-val
max-seed-val
1 2 3 4 5 6 7 8 9 10 15 20 25 30
12

CHOOSER
6
43
98
88
die-chance
die-chance
0.05
0

BUTTON
5
146
98
179
Add Foragers
forage
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
97
179
189
224
collect-rate
collect-rate
0.01 0.05 0.1
0

CHOOSER
5
224
97
269
e-per-tick
e-per-tick
0.1 0.5 1
0

PLOT
658
12
929
162
Energy
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" "if count foragers > 1 [\nlet m mean [energy] of foragers\nlet s standard-deviation [energy] of foragers\nset-current-plot-pen \"mean\"\nplot m\nset-current-plot-pen \"95\"\nplot m + 1.96 * s\nset-current-plot-pen \"0\"\nplot 0\n]"
PENS
"mean" 1.0 0 -955883 true "" ""
"95" 1.0 0 -6995700 true "" ""
"0" 1.0 0 -612749 true "" ""

PLOT
659
166
859
316
Co -- Obs -- Soc -- Rep
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

CHOOSER
6
88
98
133
const-energ-dec
const-energ-dec
0.1 0.5 1
1

CHOOSER
96
269
188
314
mem-short
mem-short
20
0

BUTTON
137
10
200
43
Tick
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
999
64
1056
109
Age
mean [age] of foragers
0
1
11

BUTTON
1151
141
1328
174
PRESS FOR EXAMPLE RUN
example
NIL
1
T
OBSERVER
NIL
J
NIL
NIL
1

INPUTBOX
1147
179
1223
239
example-ticks
500
1
0
Number

MONITOR
932
16
995
61
Seed? %
count patches with [seed?] / count patches
3
1
11

MONITOR
999
14
1056
59
Patch E
mean [penergy] of patches with [penergy > 0]
0
1
11

SLIDER
1226
180
1318
213
init-si
init-si
0
1000
2
1
1
NIL
HORIZONTAL

MONITOR
1064
13
1145
58
Penergy? %
count patches with [penergy > 0] / count patches
3
1
11

SLIDER
24
395
196
428
num-foragers
num-foragers
0
200
100
1
1
NIL
HORIZONTAL

CHOOSER
1171
95
1309
140
hed-eud
hed-eud
0 1
1

CHOOSER
96
224
188
269
rep-energy
rep-energy
5
0

MONITOR
935
66
992
111
#
count foragers
0
1
11

CHOOSER
5
179
97
224
rep-rate
rep-rate
0.05
0

SLIDER
23
357
195
390
num-patches
num-patches
15
30
20
5
1
NIL
HORIZONTAL

SLIDER
1146
242
1318
275
pref
pref
0
1
0.7
.01
1
NIL
HORIZONTAL

SLIDER
1146
279
1318
312
error-val
error-val
0
1
0.25
.01
1
NIL
HORIZONTAL

CHOOSER
97
87
189
132
evap
evap
0.1 0.05 0.01
2

CHOOSER
98
131
190
176
evap-perc
evap-perc
0.9 0.95 0.99
0

SLIDER
1167
14
1339
47
eval
eval
0
100
100
.25
1
NIL
HORIZONTAL

MONITOR
661
326
718
371
Hed %
count foragers with [hed] / count foragers
2
1
11

MONITOR
725
328
782
373
Eud %
count foragers with [eud] / count foragers
2
1
11

SLIDER
1169
52
1341
85
h-mult
h-mult
0
.6
0.4
.025
1
NIL
HORIZONTAL

SWITCH
870
417
973
450
test-e4
test-e4
1
1
-1000

BUTTON
922
344
1025
377
Reset Values
reset-values
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

@#$#@#$#@
# Using Well-Being to Influence Decision Making: a Model of Minimally Social Foragers in a Dynamic Environment

## Purpose

Agent-based modeling provides an exploratory experimental approach to understanding concepts in psychology. Here we investigate how foragers in a patchy environment respond to outside pressures by tracking internal signals designed to emulate well-being. We approach this problem with several major questions in mind (Edelman, 2014):

E1: Compare the effect of a preference for hedonic or eudaimonic life-evaluation on survival following catastrophic environmental changes.

E2: Investigating the effect of characteristic up/down swings in happiness on evolutionary performance. (i) Time constants, (ii) Ratio of peak to troughs, (iii) temporal spacing.

E3: Investigate the characteristics of life-evaluation (eudaimonic) happiness on evolutionary performance. (i) Susceptibility to positive/negative events, (ii) Dynamics of coupling with hedonic states.

## Entities, State Variables, and Scales

### Patches

Patches simulate an environment of ~1 km x 1 km which can contain food and foragers. Patches that are _seeded_ gain energy each tick at a rate of _seed-val_, assigned randomly when the patch becomes _seeded_ up to _max-seed-val_. On each tick patches have a probability of _die-chance_ of becoming _un-seeded_. All un-seeded patches lose 10% of their energy on each tick.

### Foragers

Foragers are agents who survive on _energy_. Foragers obtain _energy_ from patches by _collecting_ and discover new patches to collect from by _observing_. Foragers can also _socialize_ and _reproduce_. On each tick foragers can do only one of these actions and they decide which action to do next based on their _preference_ and well-being, indexed as _hedonic_ and _eudaimonic_

## Process overview and scheduling

### Basic Principles

### Adaptation

### Objectives

### Learning

### Prediction

### Sensing and Error

### Interaction

### Stochasticity

### Collectives

### Observation

## Initialization

## Input Data

## Submodels

###

### Patch-Leaving:

From Adams et al. we know that patch leaving occurs according to a linear algorithm: foragers accumulate information about their environment on each tick. They track the average return of the environment and change patches whenever their current return drops below the average return, with a penalty for the distance required to get to the next patch. Foragers use the same algorithm to track social value and maintain both social value and food value (summed) in one spatiotopic map.

From Leventhal et al. affective habituation is (1) linear decreasing, (2) slowed by the presence of novel items, (3) concept-dependent (i.e. food for food, social for social). Consistent anhedonia does not lead to an inability to habituate or see novelty. 

# Credits and References

This model was implemented by Daniel Birman, according to the outline proposed in Edelman 2014, using NetLogo (Wilensky 1999).

The patch-leaving algorithm follows the constraints outlined in Adams et al. (Adams et al., 2012). The MVT is originally outlined in Charnov 1976 (Charnov, 1976). See also, Haydens et al.

The model descriptions follows the ODD (Overview, Design concepts, Details) protocol (Grimm et al. 2006, 2010).

## References

Adams, G. K., Watson, K. K., Pearson, J., & Platt, M. L. (2012). Neuroethology of decision-making. Current opinion in neurobiology, 22(6), 982–9. doi:10.1016/j.conb.2012.07.009

Charnov, E. L. (1976). Optimal foraging, the marginal value theorem. Theoretical population biology, 9(2), 129-136.

Edelman, S. (2014). Explorations of happiness: proposed research. Personal Communication.

Grimm, V., Berger, U., Bastiansen, F., Eliassen, S., Ginot, V., Giske, J., ... & DeAngelis, D. L. (2006). A standard protocol for describing individual-based and agent-based models. Ecological modelling, 198(1), 115-126.

Grimm, V., Berger, U., DeAngelis, D. L., Polhill, J. G., Giske, J., & Railsback, S. F. (2010). The ODD protocol: a review and first update. Ecological Modelling, 221(23), 2760-2768.

Hayden, B. Y., Pearson, J. M., & Platt, M. L. (2011). Neuronal basis of sequential foraging decisions in a patchy environment. Nature neuroscience, 14(7), 933–9. doi:10.1038/nn.2856

Leventhal, A. M., Martin, R. L., Seals, R. W., Tapia, E., & Rehm, L. P. (2007). Investigating the dynamics of affect: Psychological mechanisms of affective habituation to pleasurable stimuli. Motivation and Emotion, 31(2), 145–157. doi:10.1007/s11031-007-9059-8

Leventhal?999). NetLogo. http://ccl.northwestern.edu/netlogo/. Center for Connected Learning and Computer-Based Modeling, Northwestern Institute on Complex Systems, Northwestern University.
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
  <experiment name="E3-Difficult500" repetitions="1" runMetricsEveryStep="false">
    <setup>reset
forage
repeat 500 [go]
set control sum [energy] of foragers
set num-patches 10
set error-val .25</setup>
    <go>go</go>
    <timeLimit steps="250"/>
    <metric>control</metric>
    <metric>sum [energy] of foragers</metric>
    <enumeratedValueSet variable="num-patches">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-seed-val">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="error-val">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="eval">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="h-mult">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init-si">
      <value value="1"/>
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pref">
      <value value="0.3"/>
      <value value="0.4"/>
      <value value="0.5"/>
      <value value="0.6"/>
      <value value="0.7"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="E2-Initial_Vals" repetitions="3" runMetricsEveryStep="false">
    <setup>reset
forage</setup>
    <go>go</go>
    <exitCondition>ticks &gt; 500 or count foragers &lt; 50</exitCondition>
    <metric>sum [energy] of foragers</metric>
    <metric>median [age] of foragers</metric>
    <enumeratedValueSet variable="hed-eud">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-patches">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-seed-val">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init-si">
      <value value="1"/>
      <value value="2"/>
      <value value="3"/>
      <value value="4"/>
      <value value="5"/>
      <value value="6"/>
      <value value="7"/>
      <value value="8"/>
      <value value="9"/>
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="eval">
      <value value="10"/>
      <value value="20"/>
      <value value="30"/>
      <value value="40"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="h-mult">
      <value value="0.05"/>
      <value value="0.1"/>
      <value value="0.15"/>
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pref">
      <value value="0.3"/>
      <value value="0.5"/>
      <value value="0.7"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="E1-Survival" repetitions="3" runMetricsEveryStep="false">
    <setup>reset
forage</setup>
    <go>go</go>
    <exitCondition>ticks &gt; 500 or count foragers &lt; 50</exitCondition>
    <metric>sum [energy] of foragers</metric>
    <enumeratedValueSet variable="max-seed-val">
      <value value="5"/>
      <value value="10"/>
      <value value="15"/>
      <value value="20"/>
      <value value="25"/>
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-patches">
      <value value="5"/>
      <value value="10"/>
      <value value="15"/>
      <value value="20"/>
      <value value="25"/>
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="hed-eud">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init-si">
      <value value="1"/>
      <value value="2"/>
      <value value="3"/>
      <value value="4"/>
      <value value="5"/>
      <value value="6"/>
      <value value="7"/>
      <value value="8"/>
      <value value="9"/>
      <value value="10"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="E4-Difficult500" repetitions="1" runMetricsEveryStep="false">
    <setup>reset
forage
repeat 500 [go]
set control sum [energy] of foragers
set num-patches 10
set error-val .25</setup>
    <go>go</go>
    <timeLimit steps="250"/>
    <metric>control</metric>
    <metric>sum [energy] of foragers</metric>
    <enumeratedValueSet variable="num-patches">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-seed-val">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="error-val">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="eval">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="h-mult">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init-si">
      <value value="1"/>
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pref">
      <value value="0.3"/>
      <value value="0.4"/>
      <value value="0.5"/>
      <value value="0.6"/>
      <value value="0.7"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="E5-WellBeing_Report--EASY" repetitions="2" runMetricsEveryStep="true">
    <setup>reset
forage
repeat 250 [go]</setup>
    <go>go</go>
    <exitCondition>ticks = 350 or count foragers &lt; 20</exitCondition>
    <metric>map [[who] of ?] (sort foragers)</metric>
    <metric>map [[energy] of ?] (sort foragers)</metric>
    <metric>map [[hed] of ?] (sort foragers)</metric>
    <metric>map [[eud] of ?] (sort foragers)</metric>
    <enumeratedValueSet variable="num-patches">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-seed-val">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="error-val">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init-si">
      <value value="1"/>
      <value value="2"/>
      <value value="3"/>
      <value value="4"/>
      <value value="5"/>
      <value value="6"/>
      <value value="7"/>
      <value value="8"/>
      <value value="9"/>
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="eval">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="h-mult">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pref">
      <value value="0.5"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="E5-WellBeing_Report--HARD" repetitions="2" runMetricsEveryStep="true">
    <setup>reset
forage
repeat 250 [go]</setup>
    <go>go</go>
    <exitCondition>ticks = 350 or count foragers &lt; 20</exitCondition>
    <metric>map [[who] of ?] (sort foragers)</metric>
    <metric>map [[energy] of ?] (sort foragers)</metric>
    <metric>map [[hed] of ?] (sort foragers)</metric>
    <metric>map [[eud] of ?] (sort foragers)</metric>
    <enumeratedValueSet variable="num-patches">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-seed-val">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="error-val">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init-si">
      <value value="1"/>
      <value value="2"/>
      <value value="3"/>
      <value value="4"/>
      <value value="5"/>
      <value value="6"/>
      <value value="7"/>
      <value value="8"/>
      <value value="9"/>
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="eval">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="h-mult">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pref">
      <value value="0.5"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="E5-WellBeing_Report--IMPOSSIBLE" repetitions="2" runMetricsEveryStep="true">
    <setup>reset
forage
repeat 250 [go]</setup>
    <go>go</go>
    <exitCondition>ticks = 350 or count foragers &lt; 20</exitCondition>
    <metric>map [[who] of ?] (sort foragers)</metric>
    <metric>map [[energy] of ?] (sort foragers)</metric>
    <metric>map [[hed] of ?] (sort foragers)</metric>
    <metric>map [[eud] of ?] (sort foragers)</metric>
    <enumeratedValueSet variable="num-patches">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-seed-val">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="error-val">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init-si">
      <value value="1"/>
      <value value="2"/>
      <value value="3"/>
      <value value="4"/>
      <value value="5"/>
      <value value="6"/>
      <value value="7"/>
      <value value="8"/>
      <value value="9"/>
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="eval">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="h-mult">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pref">
      <value value="0.5"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="E2b-Initial_Vals" repetitions="1" runMetricsEveryStep="false">
    <setup>reset
forage</setup>
    <go>go</go>
    <exitCondition>ticks &gt; 500 or count foragers &lt; 50</exitCondition>
    <metric>sum [energy] of foragers</metric>
    <metric>median [age] of foragers</metric>
    <enumeratedValueSet variable="hed-eud">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-patches">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-seed-val">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init-si">
      <value value="1"/>
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="eval">
      <value value="2"/>
      <value value="10"/>
      <value value="40"/>
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="h-mult">
      <value value="0.05"/>
      <value value="0.2"/>
      <value value="0.4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pref">
      <value value="0.3"/>
      <value value="0.5"/>
      <value value="0.7"/>
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
