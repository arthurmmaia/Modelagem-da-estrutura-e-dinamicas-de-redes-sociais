extensions [CSV]
turtles-own [mr ms t] ; mr -> initials contacts - ms -> secondary contacts

to setup
  clear-all
  reset-ticks
  create-turtles InitialNodes
  layout-circle turtles 15
  set-default-shape turtles "circle"
  ask turtles
  [
    set mr 0
    set ms 0
    set t ticks
    set color red
    set size 0.5
  ]
end

to go
  if count turtles < DesiredNetworkSize [
    primary-connection
    layout
  tick
  ]

end

;;cria um vertice e inicializa seus atributos
;;verifica o numero de conexoes primarias e aplica a conexao
;;secundaria no vertice escolhido inicialmente
to primary-connection
  create-turtles 1[
    set mr 0
    set ms 0
    set t ticks
    set color red

    let node1 one-of other turtles
    let node2 one-of other turtles
    ifelse random-float 1 < 0.95 [
     create-connection self node1
     secondary-connection self node1
     set mr 1
     ask node1[
       set mr mr + 1
      ]
    ][
     create-connection self node1
     create-connection self node2
     secondary-connection self node1
      secondary-connection self node2
     set mr 2
      ask node1[
       set mr mr + 1
      ]
      ask node2[
       set mr mr + 1
      ]
    ]
    set size 0.5
    set color red
  ]
layout
end

;;tem chances iguais de fazer 1, 2 ou 3 conexoes
to secondary-connection [node1 node2]
  let numConnections random 3 ;; + 1

  let aux-ms [ms] of node1

  repeat numConnections[
    ask node2[ ;;posso pegar o mesmo vertice mais de uma vez, como tratar?
      if any? in-link-neighbors[
        let new-neighbor  one-of in-link-neighbors
        ask new-neighbor[
          if not in-link-neighbor? node1[
           create-connection self node1
           set aux-ms aux-ms + 1
            set ms ms + 1
          ]
        ]
      ]
    ]
  ]

  ask node1[
   set ms aux-ms
  ]

end


to create-connection[node1 node2]
  if node1 != node2[
    ask node1[
      create-link-with node2
    ]
  ]
end

;;;;;;;;;;;;;;
;;; Layout ;;;
;;;;;;;;;;;;;;

;; resize-nodes, change back and forth from size based on degree to a size of 1
to resize-nodes
  ifelse all? turtles [size <= 1]
  [
    ;; a node is a circle with diameter determined by
    ;; the SIZE variable; using SQRT makes the circle's
    ;; area proportional to its degree
    ask turtles [ set size sqrt count link-neighbors ]
  ]
  [
    ask turtles [ set size 0.5 ]
  ]
end

to layout
  ;; the number 3 here is arbitrary; more repetitions slows down the
  ;; model, but too few gives poor layouts
  repeat 3 [
    ;; the more turtles we have to fit into the same amount of space,
    ;; the smaller the inputs to layout-spring we'll need to use
    let factor sqrt count turtles
    ;; numbers here are arbitrarily chosen for pleasing appearance
    layout-spring turtles links (1 / factor) (7 / factor) (1 / factor)
    display  ;; for smooth animation
  ]
  ;; don't bump the edges of the world
  let x-offset max [xcor] of turtles + min [xcor] of turtles
  let y-offset max [ycor] of turtles + min [ycor] of turtles
  ;; big jumps look funny, so only adjust a little each time
  set x-offset limit-magnitude x-offset 0.1
  set y-offset limit-magnitude y-offset 0.1
  ask turtles [ setxy (xcor - x-offset / 2) (ycor - y-offset / 2) ]
end

to-report limit-magnitude [number limit]
  if number > limit [ report limit ]
  if number < (- limit) [ report (- limit) ]
  report number
end

to create.csv
  csv:to-file "RiitaNetwork.csv" [ (list end1 end2) ] of links
end


;;;;;;;;;;;;;;
;; Metricas ;;
;;;;;;;;;;;;;;
to-report alone-nodes
  let alone 0
  ask turtles[
    if count my-links = 0[
      set alone alone + 1
    ]
  ]
    report alone
end

;; Equations Riita
to-report A [node]
  report (2 * (1 + [ms] of node)) / [ms] of node ;; 2(1+ms)/ms
end

to-report B [node]
  report [mr] of node * (A node + 1 + [ms] of node) ;; mr(A + 1 + ms)
end

to-report C [node]
  report A node * [mr] of node;; A*mr
end

to-report D [node]
  report C node * ([ms] of node - 1);; C(ms-1)
end

to-report F [node]
  report (D node * ln(B node)) + [mr] of node;; D ln B + mr
end

to rate-equation-degree-vertex ;; Equation 1
  let total 0
  ask turtles[
    let x 1 / (ticks - t)
    let y ms / (2 * (1 + ms))
    let z x * (mr + (y * (count in-link-neighbors)))
    set total total + z
  ]
  if any? turtles [plot log( total / count turtles) 10]

end

to-report rate-equation-degree-vertex-unit [node] ;; Equation 1 for only one node
  let z 0
  ask node[
    let x 1 / (ticks - t) ;; x = 1/t
    let y ms / (2 * (1 + ms)) ;; y = ms/(2(1+ms))
    set z x * (mr + (y * (count in-link-neighbors))) ;; z = 1/t * (mr + (ms/(2(1+ms)))* k1)
  ]
  report z
end

to time-evolution ;; Equation 2
  let result 0
  ask turtles[
    if ms > 0[
      set result result + (((B self) * (ticks /(ticks - t))^( 1 / A self)) - C self) ;; (B(t / ti) ^ 1/A) - C
    ]
  ]
  if any? turtles [plot log (result / count turtles) 10]

end

to-report time-evolution-node [node] ;; Equation 2
  let z 0
  ask node[
    if ms > 0[
      set z (((B self) * (ticks /(ticks - t))^( 1 / A self)) - C self) ;; (B(t / ti) ^ 1/A) - C
    ]
  ]
  report z
end

to cumulative-distribution ;; Equation 3
   let result 0
  ask turtles[
    if ms > 0[
      set result result + (1 /  ticks) * (ticks - (ticks - t)) ;; 1/t * (t - ti)
    ]
  ]
  if any? turtles [ if result != 0 [plot log (result / count turtles) 10]]


end

to probability-density-distribution ;; Equation 4
  let result 0
  ask turtles[
    if ms > 0[
      let equation (A self * ((B self)^ A self)*((count in-link-neighbors + C self)^((-2 / ms) - 3))) ;; AB^A (k + C) ^ ((-2 / ms) - 3))
      set result result + equation
    ]
  ]

  if any? turtles [ plot log( result / count turtles) 10]


end

to triangle-changes-over-time ;; Equation 5
   let result 0
  ask turtles[
   let equation (rate-equation-degree-vertex-unit self + ((mr * (ms - 1))/ ticks)) ;; (??ki / ??t) + (mr (ms - 1))/t
   set result result + equation
  ]

  if any? turtles[ plot log (result / count turtles) 10]

end


to time-evolution-of-triangles ;; Equation 6
  let result 0
  ask turtles[
    if ms > 0 [
      let equation (time-evolution-node self) + ((mr * (ms - 1)) * ln (ticks / ticks - t)) - mr
      set result result + equation
    ]
  ]

  if any? turtles[ plot log (result / count turtles) 10]


end

to clustering-coefficient ;; Equation 7
  let result 0
  ask turtles[
    if ms > 0[
      if count my-links > 1[;; maior que 1 pq se nao d?? divisao por 0
        let equation 2 * ((count my-links + (D self * ln(count my-links + C self)) - F self)/(count my-links * (count my-links - 1)))
        set result result + equation
      ]
    ]
  ]

  if any? turtles and result > 0 [ plot log (result / count turtles) 10] ;;gambiarra pra nao tentar fazer log de num negativo



end


;;An??lise / Behavior Space

to-report rate-equation-degree-vertex_ ;; Equation 1
  let total 0
  ask turtles[
    let x 1 / (ticks - t)
    let y ms / (2 * (1 + ms))
    let z x * (mr + (y * (count in-link-neighbors)))
    set total total + z
  ]

  if any? turtles [report log( total / count turtles) 10]
end


to-report time-evolution_ ;; Equation 2
  let result 0
  ask turtles[
    if ms > 0[
      set result result + (((B self) * (ticks /(ticks - t))^( 1 / A self)) - C self) ;; (B(t / ti) ^ 1/A) - C
    ]
  ]

  if any? turtles [report log (result / count turtles) 10]
end

to-report cumulative-distribution_ ;; Equation 3
   let result 0
  ask turtles[
    if ms > 0[
      set result result + (1 /  ticks) * (ticks - (ticks - t)) ;; 1/t * (t - ti)
    ]
  ]
  ;;if any? turtles [ if result != 0 [plot log (result / count turtles) 10]]
  if any? turtles [ if result != 0 [report log (result / count turtles) 10]]

end

to-report probability-density-distribution_ ;; Equation 4
  let result 0
  ask turtles[
    if ms > 0[
      let equation (A self * ((B self)^ A self)*((count in-link-neighbors + C self)^((-2 / ms) - 3))) ;; AB^A (k + C) ^ ((-2 / ms) - 3))
      set result result + equation
    ]
  ]

  ;;if any? turtles [ plot log( result / count turtles) 10]
  if any? turtles [ report log( result / count turtles) 10]

end

to-report triangle-changes-over-time_ ;; Equation 5
   let result 0
  ask turtles[
   let equation (rate-equation-degree-vertex-unit self + ((mr * (ms - 1))/ ticks)) ;; (??ki / ??t) + (mr (ms - 1))/t
   set result result + equation
  ]

  ;;if any? turtles[ plot log (result / count turtles) 10]
  if any? turtles[ report log (result / count turtles) 10]
end


to-report time-evolution-of-triangles_ ;; Equation 6
  let result 0
  ask turtles[
    if ms > 0 [
      let equation (time-evolution-node self) + ((mr * (ms - 1)) * ln (ticks / ticks - t)) - mr
      set result result + equation
    ]
  ]

  ;;if any? turtles[ plot log (result / count turtles) 10]
  if any? turtles[ report log (result / count turtles) 10]

end

to-report clustering-coefficient_ ;; Equation 7
  let result 0
  ask turtles[
    if ms > 0[
      if count my-links > 1[;; maior que 1 pq se nao d?? divisao por 0
        let equation 2 * ((count my-links + (D self * ln(count my-links + C self)) - F self)/(count my-links * (count my-links - 1)))
        set result result + equation
      ]
    ]
  ]

  ;;if any? turtles and result > 0 [ plot log (result / count turtles) 10] ;;gambiarra pra nao tentar fazer log de num negativo
  if any? turtles and result > 0 [ report log (result / count turtles) 10] ;;gambiarra pra nao tentar fazer log de num negativo


end
@#$#@#$#@
GRAPHICS-WINDOW
10
11
447
449
-1
-1
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
0
0
1
ticks
30.0

BUTTON
475
10
538
43
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
542
10
605
43
NIL
go\n
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
477
56
649
89
InitialNodes
InitialNodes
0
100
1.0
1
1
NIL
HORIZONTAL

SLIDER
477
103
649
136
DesiredNetworkSize
DesiredNetworkSize
0
1000
1000.0
50
1
NIL
HORIZONTAL

BUTTON
609
10
703
43
create .csv
create.csv
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
710
11
812
44
NIL
resize-nodes
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
651
95
746
140
number of nodes
count turtles
17
1
11

PLOT
831
14
1316
134
Degree Distribution
degree
num of nodes
0.0
1.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 1 -16777216 true "" "let max-degree max [count link-neighbors] of turtles\nplot-pen-reset  ;; erase what we plotted before\nset-plot-x-range 1 (max-degree + 1)  ;; + 1 to make room for the width of the last bar\nhistogram [count link-neighbors] of turtles"

MONITOR
746
95
828
140
Alone Nodes
alone-nodes
17
1
11

BUTTON
711
45
813
78
redo layout
layout
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
471
158
671
308
Rate for the degree of vertex
Time
Rate
0.0
10.0
0.0
1.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "rate-equation-degree-vertex"

PLOT
676
157
876
307
Time evolution for vertex degree
NIL
NIL
0.0
10.0
0.0
1.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "time-evolution"

PLOT
1096
157
1296
307
Probability Density Distribution
Time
Density Distribution
0.0
10.0
0.0
1.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "probability-density-distribution"

PLOT
462
329
671
480
Triangle changes over time
Time
Changes rate
0.0
10.0
0.0
1.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "triangle-changes-over-time"

PLOT
881
157
1091
307
Cumulative Distribution
Time
# vertex k <
0.0
10.0
0.0
1.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "cumulative-distribution"

PLOT
675
329
875
479
Time Evolution of Triangles
Time
# triangles
0.0
10.0
0.0
1.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "time-evolution-of-triangles"

PLOT
880
330
1088
480
Clustering Coefficient
Time
c(k)
0.0
10.0
0.0
1.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "clustering-coefficient"

TEXTBOX
555
141
705
159
Eq 1
11
0.0
1

TEXTBOX
769
142
919
160
Eq 2
11
0.0
1

TEXTBOX
966
142
1116
160
Eq 3
11
0.0
1

TEXTBOX
1183
142
1333
160
Eq 4
11
0.0
1

TEXTBOX
550
314
700
332
Eq 5
11
0.0
1

TEXTBOX
762
314
912
332
Eq 6
11
0.0
1

TEXTBOX
978
315
1128
333
Eq 7
11
0.0
1

PLOT
1094
331
1294
481
Average degrees
Time
Degree
0.0
10.0
0.0
1.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "if count turtles > 0[ plot log(count turtles) 10]"

@#$#@#$#@
## WHAT IS IT?

Este trabalho ?? uma replica????o do modelo proposto em [1].
//
This work is a replication of the model proposed in [1]

## HOW IT WORKS

(1) Come??a com uma rede de N0 vertices;
(2) Escolhe em media mr>= 1 vertices aleatorios como contatos iniciais;
(3) Escolhe em media ms>= 0 vizinhos de cada contato inicial como contato secund??rio;
(4) Conecta o novo vertecia ao contato inicial e aos secund??rios;
(5) Repere os passos 2 a 4 at?? que a rede cres??a para o tamanho desejado.

(Esse trecho foi retirado de [1])
//
(1) start with a seed network of N0 vertices;
(2) pick on average mrX1 random vertices as initial contacts;
(3) pick on average msX0 neighbours of each initial contact as secondary contacts;
(4) connect the new vertex to the initial and secondary contacts;
(5) repeat steps 2???4 until the network has grown to desired size.

(This excerpt was taken from [1])
## HOW TO USE IT

Bot??es
setup - organiza a simula????o para o seu estado inicial.
go - come??a a simula????o.
crete .csv - cria um arquivo do tipo .csv com todos os links existentes na simula????o naquele momento.

Deslizadores
InitialNodes - define o n??mero inicial de agentes na simula????o.
DesiredNetworkSize - define o tamanho desejado da rede, quando a rede atinge esse tamanho a simula????o para.

Monitores
number of nodes - mostra o numero de vertices existentes na rede.
Alone Nodes - mostra o numero de vertices com 0 cone????es com outros v??rtices.

Graficos
Degree Distribution - histograma que apresenta a quantidade de n??s com determinado grau.
Rate for the degree vertice -
Time evolution for vertex degree -
Cumulative distribution -
Probability Density Distribution
Triangle changes over time -
Time Evolution of Triangles -
Clusterig coefficient - mostra a mudan??a do coeficiente de agrupamento com o passar do tempo.
Avarege degrees - mostra o grau m??dio de toda a rede.
//
Buttons
setup - arranges the simulation to its initial state.
go - starts the simulation.
crete .csv - creates a .csv file with all links existing in the simulation at that moment.

Slippers
InitialNodes - defines the initial number of agents in the simulation.
DesiredNetworkSize - sets the desired size of the network, when the network reaches this size the simulation stops.

Monitors 
number of nodes - shows the number of vertices in the network.
Alone Nodes - shows the number of vertices with 0 connections with other vertices.

Graphics
Degree Distribution - histogram that shows the number of nodes with a certain degree.
Rate for the degree vertex -
Time evolution for vertex degree -
Cumulative distribution -
Probability Density Distribution
Triangle changes over time -
Time Evolution of Triangles -
Clusterig coefficient - shows the change in the clustering coefficient over time.
Avarege degrees - shows the average degree for the entire network.
## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

Esse trabalho ainda n??o est?? finalizado e sofrer?? altera????es.
//
This work is not fineshed yet and will undergo changes.

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

[ 1 ] R. Toivonen, J. Onnela, J. Sarama?? ki, J. Hyvonen, K. Kaski: A model for social networks. 2006, Elsevier. DOI:10.1016/j.physa.2006.03.050;
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
NetLogo 6.1.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="experiment" repetitions="20" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>rate-equation-degree-vertex_</metric>
    <metric>time-evolution_</metric>
    <metric>cumulative-distribution_</metric>
    <metric>probability-density-distribution_</metric>
    <metric>triangle-changes-over-time_</metric>
    <metric>time-evolution-of-triangles_</metric>
    <metric>clustering-coefficient_</metric>
    <enumeratedValueSet variable="DesiredNetworkSize">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="InitialNodes">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
