breed [foragers forager]
breed [pens pen]
patches-own [seed? seed-val penergy ps fs]
foragers-own [ntask taskn nhfval memt memv val aim e? energy age hv smem hed hmem eud emem rmem hval]
globals [dead seed-list next-seed mem-long]

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
  ;;PENS
  pens-do
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
    set val 0
    set energy energy - e-per-tick
    run ntask
    let ch calc-hed
    let ce calc-eud
    set hed (ch - helper-mean hmem) / helper-std hmem
    set eud (ce - helper-mean emem) / helper-std emem
    helper-mem ch ce
    pick-next-task
  ]
end

to foragers-die
  if energy <= 0 [
    set dead dead + 1
    die
  ]
end

;;;;;;;
;; TASKS ;;
;;;;;;;;;;

to collect
  if [penergy] of patch-here > 0 [
    let ge [penergy] of patch-here * collect-rate * max (list ((mem-short - smem) / mem-short) 0)
    ask patch-here [set penergy penergy - ge]
    set energy energy + ge
    set val ge
  ]
end

to observe
  let pev [penergy] of patch-here
  helper-uphill-ps
  set val [penergy] of patch-here - pev
end

to socialize
  ifelse any? other foragers-on patch-here [
    set smem 0
    set val soc-val
  ] [ helper-uphill-fs ]
end

to reproduce
  if random-float 1 < rep-rate [ ;; Linear increase in proability of reproducing, only reproduce if you're fully happy
    hatch-foragers 1 [
      helper-newforager [patch-here] of myself
      set energy rep-energy
    ]
    set energy energy - rep-energy
    set rmem 0
    set val rep-val
  ]
end

;;;;;;;;;;;;;;;;;;;;
;; FORAGER EXTRAS ;;
;;;;;;;;;;;;;;;;;;;;

to pick-next-task
  ifelse hed-eud = 1 [
    let eudt (eud > hval)
    let hedt (hed > 0)
    ifelse hedt [
      ifelse eudt [
        helper-st2 2
      ] [
        helper-st2 3
      ]
    ] [
      helper-st2 one-of [1 4]
    ]
  ] [
  ;;Not using Hed/Eud
    helper-st2 one-of [1 2 3 4]
  ]
end

to-report helper-std [l]
  let h ifelse-value (length l > 1) [standard-deviation l] [-1]
  report ifelse-value (h > .1) [h] [1000]
end

to-report calc-hed
  report ((- rmem) / mem-short) + helper-task-mean-value 1 true
end

to-report calc-eud
  let tval 0
  foreach [1 2 3] [
    set tval tval + helper-task-mean-value ? true - helper-task-mean-value ? false
  ]
  report tval
end

;;;;;;;;;;;;;
;; PATCHES ;;
;;;;;;;;;;;;;

;; Setup the initial patches 
to patches-seed
  ask n-of num-patches patches with [not seed?] [ helper-seedpatch ]
end

to pens-do
  ask pens [ set color 43 + 5 * [penergy] of patch-here / 1000 ]
end

;; Add energy
to patches-do
  ask patches [
    set ps ps - .05
    set fs fs - .1
    ifelse fs > 0 [set pcolor 52 + fs / 15 * 7] [
      set fs 0
      ifelse ps < 0 [set pcolor black set ps 0] [set pcolor 72 + ps / (max-seed-val * .5 / die-chance) * 8]
    ] 
    ifelse seed? [
      set penergy penergy + seed-val
      set ps ps + seed-val
      if random-float 1 < die-chance [set seed? false ask one-of patches [helper-seedpatch]]
    ] [
      ;; Wither
      if penergy > 0 [set penergy penergy - const-energ-dec]
      if penergy < 0 [set penergy 0 ask pens-here [die]]
      if seed-val > 0 [ set seed-val seed-val - (seed-val * wither-rate) - wither-rate ]
    ]
  ]
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

to-report helper-task-mean-value [n short]
  let l [] let l2 []
  ifelse short [set l sublist memt 0 (min (list (length memt - 1) (mem-short - 1))) set l2 sublist memv 0 (min (list (length memv - 1) (mem-short - 1)))] [set l memt set l2 memv]
  let m []
  (foreach l l2 [if ?1 = n [set m fput ?2 m] ])
  report helper-mean m
end

to-report helper-task-mem-count [n]
  let c 0
  foreach memt [if ? = n [set c c + 1]]
    report c
end

to-report helper-mean [l]
  if length l = 0 [report 0]
  report mean l
end

to helper-mem [hedv eudv]
  set memv fput val memv
  if length memv > mem-long [set memv sublist memv 0 (mem-long - 1)]
  set memt fput taskn memt
  if length memt > mem-long [set memt sublist memt 0 (mem-long - 1)]
  set hmem fput hedv hmem
  if length hmem > mem-long [set hmem sublist hmem 0 (mem-long - 1)]
  set emem fput eudv emem
  if length emem > mem-long [set emem sublist emem 0 (mem-long - 1)]
end

to helper-st2 [n]
  set ntask helper-num-to-task n
  set taskn n
end

to-report helper-energyerror
  if energy < 0 [report 0]
  report random-normal energy energy * error-std
end

to-report helper-num-to-task [num]
  if num = 1 [report task collect]
  if num = 2 [report task observe]
  if num = 3 [report task socialize]
  if num = 4 [report task reproduce]
  show num
end

to helper-newforager [p]
  move-to p
  helper-st2 (random 4) + 1
  set memt (list taskn)
  set memv [0]
  set hmem [0]
  set emem [0]
  set smem 0
  set rmem 0
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
  sprout-pens 1 [set color 43 set shape "square" set size .5]
end

to-report mean-hedeud [group]
  report [0 0]
  ;;let alist [matrix:get-row calc-hedeud 0] of group
  ;;report reduce helper-comb-lists alist
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
  let p max-one-of (patches in-cone 1.5 180) [ps]
  face p
  move-to p
end
to helper-uphill-fs
  let p max-one-of (patches in-cone 1.5 180) [fs]
  face p
  move-to p
end
to-report other-in-cone ;; in-cone, but only other patches
  let p patches in-cone 1.5 180
  report p with [not (self = [patch-here] of myself)]
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
210
10
653
474
20
20
10.561
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
6
43
98
88
num-patches
num-patches
3 9
0

CHOOSER
98
43
190
88
max-seed-val
max-seed-val
5 10 25
0

CHOOSER
98
88
190
133
wither-rate
wither-rate
0.01 0.025 0.05
2

CHOOSER
6
88
98
133
die-chance
die-chance
0.1 0.01
0

BUTTON
6
179
99
212
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
98
212
190
257
collect-rate
collect-rate
0.02 0.05 0.1
1

CHOOSER
6
257
98
302
e-per-tick
e-per-tick
0.1 0.5 1
0

CHOOSER
97
257
189
302
view-radius
view-radius
1 3 5 7 9
4

CHOOSER
5
302
97
347
error-std
error-std
0.1 0.2 0.5
0

PLOT
656
12
927
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
"" "if count foragers > 0 [\nlet m mean [energy] of foragers\nlet s standard-deviation [energy] of foragers\nset-current-plot-pen \"mean\"\nplot m\nset-current-plot-pen \"95\"\nplot m + 1.96 * s\nset-current-plot-pen \"5\"\nplot m - 1.96 * s\n]"
PENS
"mean" 1.0 0 -955883 true "" ""
"95" 1.0 0 -6995700 true "" ""
"5" 1.0 0 -612749 true "" ""

PLOT
657
166
857
316
Co -- Obs -- Soc -- Rep
NIL
NIL
1.0
5.0
0.0
1.0
true
false
"" "if count foragers > 0 [\nclear-plot\nforeach [1 2 3 4] [\nplotxy ? count foragers with [taskn = ?] / count foragers\n]\n]"
PENS
"default" 1.0 1 -16777216 true "" ""

CHOOSER
6
133
98
178
const-energ-dec
const-energ-dec
0.1 0.5 1
0

CHOOSER
97
302
189
347
mem-short
mem-short
50 100
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
977
72
1034
117
Age
mean [age] of foragers
0
1
11

BUTTON
1007
164
1184
197
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
1003
202
1079
262
example-ticks
500
1
0
Number

MONITOR
930
16
993
61
Seed? %
count patches with [seed?] / count patches
3
1
11

MONITOR
997
14
1054
59
Patch E
mean [penergy] of patches
0
1
11

SLIDER
1084
203
1176
236
init-si
init-si
0
1000
1
1
1
NIL
HORIZONTAL

CHOOSER
6
437
98
482
max-nhf
max-nhf
1.5
0

MONITOR
1062
13
1143
58
Penergy? %
count patches with [penergy > 0] / count patches
3
1
11

CHOOSER
98
437
190
482
nhf-dropoff
nhf-dropoff
0.1 0.25
0

CHOOSER
988
362
1126
407
obs-mult
obs-mult
1
0

CHOOSER
988
418
1126
463
soc-val
soc-val
1
0

CHOOSER
987
466
1125
511
rep-val
rep-val
1
0

SLIDER
990
274
1162
307
pref
pref
0
1
0.5
.01
1
NIL
HORIZONTAL

SLIDER
16
396
188
429
num-foragers
num-foragers
0
200
51
1
1
NIL
HORIZONTAL

CHOOSER
1057
90
1195
135
hed-eud
hed-eud
0 1
0

CHOOSER
8
351
146
396
rep-energy
rep-energy
5
0

MONITOR
889
202
946
247
#
count foragers
0
1
11

PLOT
657
324
958
474
Hed/Eud
NIL
NIL
0.0
10.0
0.0
1.0
true
true
"" "if count foragers > 0 [\nset-current-plot-pen \"Eud\"\nplot count foragers with [(eud > 0) and not (hed > 0)] / count foragers\nset-current-plot-pen \"Hed\"\nplot (count foragers with [(hed > 0) and not (eud > 0)] + count foragers with [(eud > 0) and not (hed > 0)]) / count foragers\nset-current-plot-pen \"Hed + Eud\"\nplot (count foragers with [(hed > 0) and (eud > 0)] + count foragers with [(hed > 0) and not (eud > 0)] + count foragers with [(eud > 0) and not (hed > 0)]) / count foragers\n]"
PENS
"Eud" 1.0 0 -16777216 true "" ""
"Hed" 1.0 0 -7500403 true "" ""
"Hed + Eud" 1.0 0 -2674135 true "" ""

CHOOSER
6
212
98
257
rep-rate
rep-rate
0.05
0

PLOT
1132
326
1332
476
plot 1
NIL
NIL
0.0
10.0
-1.0
1.0
true
false
"" "if count foragers > 0 [\nset-current-plot-pen \"default\"\nplot mean [hed] of foragers\nset-current-plot-pen \"pen-1\"\nplot mean [eud] of foragers\n]"
PENS
"default" 1.0 0 -16777216 true "" ""
"pen-1" 1.0 0 -955883 true "" ""

@#$#@#$#@
FINAL IDEA:

(1) Foragers maintain a memory of average social and collecting returns.
(2) Based on their return they calculate two factors: (A) well-being indexes, which are based on (B) habituation
   (A) Well Being Indexes: Short-term, calculated as the food return against mean food return and social return against mean social return. 
   (B) Habituation: A task worth 100 hedonic points would be overstimated and linearly drop off over time (i.e. 1 = 110, 10 = 100, 20 = 90).
(3) Foragers will repeat the same task indefinitely until a new task is chosen.
(4) When deciding whether to choose a new task foragers check their well being and habituation indexes.

Food Return: This tick's food value (energy gained on this tick)
Social Return: This tick's social value (reproduction which occurred in the last ten ticks)


Rules:

Environment:
_num-patches_ of randomly placed, sparse, patches, with a production rate of 1 to _max-seed-val_ energy per tick. 

Foragers can:

 - Wander: pick a random patch to move-to within _view-radius_ patches
Value = Value of 1 per tick
 - Observe: pick the highest _penergy_ patch within _view-radius_, move there
Value = Difference between current patch energy and new patch energy divided by distance, split across the distance to get there
 - Collect: take 1% of the energy on this patch
Value = Last take
 - Socialize: choose an agent within _view-radius_ and move to them
Value = Current social value / distance, split across distance to get there


Well-Being:

Well being is calculated as: NHF * Task Value - Mean Task Value

NHF = Novelty/Habituation Factor, ranging from 0 to _max-nhf_, dropping linearly with _nhf-dropoff_
Task Value = Return from doing this task on the last tick
Mean Task Value = Average value for task from memory

Short term well being (hedonic) only takes into account food value and observe value. 

NHF resets when you change tasks.

Choosing a new Task:

As well-being drops the likelihood of choosing a new task increases. Low short term leads to collecting and reproducing, low long term leads to wandering, observing, socializing.

Death: <= 0 energy or randomly due to age (chance 1 in _for-death-rate)

# Constraints

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
  <experiment name="experiment" repetitions="5" runMetricsEveryStep="false">
    <setup>reset
local-seed
forage</setup>
    <go>go</go>
    <timeLimit steps="250"/>
    <metric>count foragers</metric>
    <metric>mean [energy] of foragers</metric>
    <metric>sum [energy] of foragers</metric>
    <enumeratedValueSet variable="nhf-dropoff">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="error-std">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="collect-rate">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="const-energ-dec">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rep-energy">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-foragers">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="hed-eud">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rep-mult">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="e-per-tick">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-patches">
      <value value="3"/>
      <value value="9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="die-chance">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pref">
      <value value="0.05"/>
      <value value="0.95"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="example-ticks">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init-si">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wither-rate">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="soc-mult">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-nhf">
      <value value="1.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="view-radius">
      <value value="9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mem-short">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="eat-mult">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-seed-val">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="obs-mult">
      <value value="1"/>
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
