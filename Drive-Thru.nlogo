; drive-thru_simulator.nlogo
;
; a model which represents the flow of a drive-thru
;
; Liam Whitenack
; 02/22/2021
; CDS 492
; Spring 2022

globals
[
  x-coordinates ; the x-coordinate of a chosen car
  y-coordinates
  car-num ; total number of cars
  order_item ; placeholder for item
  waiting-to-join-line
  dto-1-switch
  dto-2-switch
  dto-3-switch
  lane

  a

  cars-lost

  product-id

  bagged-orders

  new-car-at-window?
  started-at-window
  cars-served
  avg-window-time

  started-bagging
  bagging-time

  started-distributing
  distributing-time

  food-waiting-on
  drinks-waiting-on
  shakes-waiting-on
  num-employees

  worked-#s ; the list of products queued and chosen as a task
  finished-#s ; the list of completed products

  seed

  important-xcor
  important-ycor

  food-queued
  drinks-queued
  shakes-queued
]

breed [cars car]
breed [products product]
breed [employees employee]
breed [bags bag]

cars-own
[
  species ; can be a car or an item

  switch

  ; item attributes
  ready?
  bagged?

  ; car attributes
  carid
  food
  drinks
  shakes
  full_order
  num-food
  num-drinks
  num-shakes

  ordered?
  started-to-order
  order-time
  finished-ordering
  started-to-pay
  pay-time
  finished-paying

  paid?
  finished?
]

products-own
[
  ;how long the product takes to prepare
  food-prep-time
  drinks-prep-time
  shakes-prep-time

  ;the tick number that the product starts to be prepared on
  food-prep-start-time
  drinks-prep-start-time
  shakes-prep-start-time

  ;product's id
  item-id
]

bags-own [bag# bag-label]

employees-own
[
  task-time
  task-start
  product-#
]

to-report id-products [x y]
  let product-list [self] of products-on patch x y
  let product-id-list []
  foreach product-list [product-in-agentset -> set product-id-list lput [who] of product-in-agentset product-id-list]
  report product-id-list
end

to-report product-types [product-ids]
  let products# []
  foreach product-ids
  [
    id ->
    set products# lput [item-id] of turtle id products#
  ]
  report products#
end

to-report remove-first [element alist]
  let in? false
  let i 0
  foreach alist
  [
    x ->
    if x = element [
      set in? true
    ]
    if not in? [set i i + 1]
  ]
  set alist remove-item i alist
  report alist
end

to-report remove-list [list2 list1]
  let result filter [ x -> not member? x list2 ] list1
  report result
end

to-report everything-ready? [food-needed drinks-needed shakes-needed food-ready drinks-ready shakes-ready]
  let continue? false

  let num-prepared 0

  foreach food-needed
  [
    needed ->
    if member? needed food-ready [set num-prepared num-prepared + 1  set food-ready remove-first needed food-ready]

    set continue? (num-prepared = length food-needed)
  ]
  if length food-needed = 0 [set continue? true]

  if continue?
  [
    set num-prepared 0
    foreach drinks-needed
    [
      needed ->
      if member? needed drinks-ready [set num-prepared num-prepared + 1  set drinks-ready remove-first needed drinks-ready]

      set continue? (num-prepared = length drinks-needed)
    ]
    if length drinks-needed = 0 [set continue? true]
  ]

  if continue?
  [
    set num-prepared 0
    foreach shakes-needed
    [
      needed ->
      if member? needed shakes-ready [set num-prepared num-prepared + 1  set shakes-ready remove-first needed shakes-ready]

      set continue? (num-prepared = length shakes-needed)
    ]
    if length shakes-needed = 0 [set continue? true]
  ]


  report continue?
end

to-report product-with-id [id products-ready]
  let product-who []
  foreach products-ready
  [
    product-ready ->
    ;[who] of products with [item-id = 1 and pxcor = 8]
  ]
end

to setup
  ifelse set-seed
  [
    set seed 42
  ]
  [
    set seed random 1024
  ]
  random-seed seed
  set new-car-at-window? true
  set started-bagging 0
  set started-distributing 0
  clear-all
  setup-patches
  setup-employees
  reset-ticks
  monitor
  add-car
end

to go
  step
  ;if turtle 66 != nobody [inspect turtle 66  stop]
end

to test
  repeat n [step]
end

to step
  spawn-cars
  drive
  tick
  order
  pay-for-order
  prep
  bag-products
  hand-out
  monitor

end

to monitor
  ifelse any? turtles-on patch 13 12
  [
    ifelse not member? (one-of [who] of turtles-on patch 13 12) ([bag#] of turtles-on patch 6 12)
    [
      set food-waiting-on (remove-list [item-id] of turtles-on patch -5 4 one-of [food] of turtles-on patch 13 12)
      set drinks-waiting-on (remove-list [item-id] of turtles-on patch 0 4 one-of [drinks] of turtles-on patch 13 12)
      set shakes-waiting-on (remove-list [item-id] of turtles-on patch 5 4 one-of [shakes] of turtles-on patch 13 12)
      if food-waiting-on = [] and drinks-waiting-on = [] and shakes-waiting-on = []
      [
        set food-waiting-on "food must be bagged"
        set drinks-waiting-on "drinks must be bagged"
        set shakes-waiting-on "shakes must be bagged"
      ]
    ]
    [
      set food-waiting-on "order must be distributed"
      set drinks-waiting-on "order must be distributed"
      set shakes-waiting-on "order must be distributed"
    ]
  ]
  [
    set food-waiting-on []
    set drinks-waiting-on []
    set shakes-waiting-on []
  ]
  if ticks = 0 [set num-employees count employees]
  if not pw and any? turtles-on patch 9 -5 [ask one-of turtles-on patch 9 -5 [die]]
  if pw and not any? turtles-on patch 9 -5 [set num-employees 0]
  ifelse pw [set a 1] [set a 0]
  if count employees != num-dto + a + num-food-prep-employees + num-drinks-prep-employees + num-shakes-prep-employees + 2
  [
    setup-employees
    setup-patches
    set num-employees count employees
  ]

  if not any? turtles with [who = 299] [stop]

end

to order
  set dto-1-switch false
  set dto-2-switch false
  set dto-3-switch false
  ifelse not outdoor-dto [
    ask cars with [pycor = -8 and (pxcor < 0) and not ordered?]
    [
      if order-time = 0 [set order-time random-normal avg-order-time (avg-order-time / 2)]
      if started-to-order = 0 [set started-to-order ticks]
      if ticks > order-time + started-to-order
      [
        if not ordered?
        [
          if pxcor = -10 [set dto-1-switch true]
          if pxcor = -14 [set dto-2-switch true]
          set finished-ordering ticks
          set ordered? true
          set color green - 2
        ]

      ]
    ]
  ]
  [
    let cars-in-line-list [who] of cars with [pxcor < -9 and pycor > -9 and not ordered?]
    ask cars with [not ordered? and (pxcor < -9 and pycor > -9) and (who = min cars-in-line-list)]
    [
      if order-time = 0 [set order-time random-normal avg-order-time (avg-order-time / 2)]
      ;if order-time-2 = 0 and num-dto = 2 [set order-time-2 random-normal avg-order-time (avg-order-time / 2)]
      if started-to-order = 0 [set started-to-order ticks]
      ;if started-to-order-2 = 0 and num-dto = 2 [set started-to-order-2 ticks]
      if ticks > order-time + started-to-order ;or (ticks > order-time-2 + started-to-order-2 and num-dto = 2)
      [
        if not ordered?
        [
          ;if pxcor = -10 [set dto-1-switch true]
          ;if pxcor = -14 [set dto-2-switch true]
          set dto-3-switch true
          set finished-ordering ticks
          set ordered? true
          set color green - 2
          set important-xcor xcor
          set important-ycor ycor
        ]

      ]
      if num-dto = 2
      [
        set cars-in-line-list remove min cars-in-line-list cars-in-line-list
        if order-time = 0 [set order-time random-normal avg-order-time (avg-order-time / 2)]
        ;if order-time-2 = 0 and num-dto = 2 [set order-time-2 random-normal avg-order-time (avg-order-time / 2)]
        if started-to-order = 0 [set started-to-order ticks]
        ;if started-to-order-2 = 0 and num-dto = 2 [set started-to-order-2 ticks]
        if ticks > order-time + started-to-order ;or (ticks > order-time-2 + started-to-order-2 and num-dto = 2)
        [
          if not ordered?
          [
            ;if pxcor = -10 [set dto-1-switch true]
            ;if pxcor = -14 [set dto-2-switch true]
            set dto-3-switch true
            set finished-ordering ticks
            set ordered? true
            set color green - 2
            set important-xcor xcor
            set important-ycor ycor

          ]

        ]
      ]
    ]
  ]



  if dto-1-switch [
    set lane 1
    queue-items
    set dto-1-switch false
  ]
  if dto-2-switch [
    set lane 2
    queue-items
    set dto-2-switch false
  ]
  if dto-3-switch [
    set dto-3-switch false
    queue-items
  ]

end

to queue-items

  ifelse outdoor-dto
  [
    set food-queued one-of [food] of cars with [ycor = important-ycor and xcor = important-xcor]
    set drinks-queued one-of [drinks] of cars with [ycor = important-ycor and xcor = important-xcor]
    set shakes-queued one-of [shakes] of cars with [ycor = important-ycor and xcor = important-xcor]
  ]
  [
    set food-queued one-of [food] of cars with [pycor = -8 and ((pxcor = -10 and lane = 1) or (pxcor = -14 and lane = 2))]
    set drinks-queued one-of [drinks] of cars with [pycor = -8 and ((pxcor = -10 and lane = 1) or (pxcor = -14 and lane = 2))]
    set shakes-queued one-of [shakes] of cars with [pycor = -8 and ((pxcor = -10 and lane = 1) or (pxcor = -14 and lane = 2))]
  ]


  foreach food-queued
  [
    food-item ->
    set product-id food-item
    add-food-to-queue
  ]

  foreach drinks-queued
  [
    drinks-item ->
    set product-id drinks-item
    add-drinks-to-queue
  ]

  foreach shakes-queued
  [
    shakes-item ->
    set product-id shakes-item
    add-shakes-to-queue
  ]
end

to add-food-to-queue
  create-products 1 [
    set food-prep-time random-normal avg-food-prep-time (avg-food-prep-time / 2)
    set food-prep-start-time 0
    set item-id product-id
    set size 2.5
    set color yellow
    set shape "square"
    setxy -5 -6
  ]
end

to add-drinks-to-queue
  create-products 1 [
    set drinks-prep-time random-normal avg-drinks-prep-time (avg-drinks-prep-time / 2)
    set drinks-prep-start-time 0
    set item-id product-id
    set size 2.5
    set color yellow
    set shape "circle"
    setxy 0 -6
  ]
end

to add-shakes-to-queue
  create-products 1 [
    set shakes-prep-time random-normal avg-shakes-prep-time (avg-shakes-prep-time / 2)
    set shakes-prep-start-time 0
    set item-id product-id
    set size 2.5
    set color yellow
    set shape "triangle"
    setxy 5 -6
  ]
end

to prep
  if any? turtles-on patch -5 -6 ;and false
  [prepare-products turtles-on patch -5 -6 turtles-on patch -5 -1 avg-food-prep-time]
  if any? turtles-on patch 0 -6 ;and false
  [prepare-products turtles-on patch 0 -6 turtles-on patch 0 -1 avg-drinks-prep-time]
  if any? turtles-on patch 5 -6 ;and false
  [prepare-products turtles-on patch 5 -6 turtles-on patch 5 -1 avg-shakes-prep-time]
end

to prepare-products [products-set employees-set avg-task-time]


  let product-list sort [self] of products-set
  let product-list-ids []
  foreach product-list [product-agent -> set product-list-ids lput [who] of product-agent product-list-ids]
  let product-list-unstarted-ids sort product-list-ids
  set product-list-ids sort product-list-ids
  let started-#s []

  ;create a list of employees
  let employee-list sort [self] of employees-set
  ; remove every product being worked on
  foreach employee-list
  [
    employee-agent ->
    set started-#s lput ([product-#] of employee-agent) started-#s
  ]

  set product-list-unstarted-ids remove-list started-#s product-list-unstarted-ids


  ; if any employees have a task
  ;if length product-list-unstarted-ids > 0
  ;[
  ; set the task start time of each employee and the predetermined preparation time
  foreach employee-list
  [
    employee-agent ->
    if length product-list-unstarted-ids > 0
    [
      if ([product-#] of employee-agent) = 0; if they haven't started a task yet
      [
        if length product-list-unstarted-ids != 0
        [
          ask employee-agent
          [
            set task-start ticks
            set task-time abs random-normal avg-task-time avg-task-time / 2
            set product-# min product-list-unstarted-ids
          ]
          set product-list-unstarted-ids remove (min product-list-unstarted-ids) product-list-unstarted-ids
        ]
      ]
    ]

    if (([task-start] of employee-agent) + ([task-time] of employee-agent)) < ticks and ([product-#] of employee-agent != 0)
    [
      ask turtle [product-#] of employee-agent
      [
        set heading 0
        forward 10
        set color orange
      ]

      ask employee-agent
      [
        set task-start 0
        set product-# 0
        set task-time 0
      ]
    ]
  ]
end

to bag-products

  ; identify the numbers of the cars in line and put them into a list
  let cars-agentset [self] of cars with [ordered?]
  let cars-list []
  if not (cars-agentset = []) and count products > 0
  [
    if started-bagging = 0
    [
      set started-bagging ticks
      set bagging-time random-normal avg-bagging-time (avg-bagging-time / 4)
    ]
    if ticks - started-bagging > bagging-time
    [
      foreach cars-agentset [car-in-line -> set cars-list lput [who] of car-in-line cars-list]
      if not (cars-list = [])
      [

        let food-ready 0
        let drinks-ready 0
        let shakes-ready 0

        let waiting-to-be-bagged length cars-list

        set cars-list remove-list bagged-orders cars-list

        while [not (cars-list = []) and ticks - started-bagging > bagging-time + (((waiting-to-be-bagged - length cars-list) / 4) * avg-order-time)]
        [
          set food-ready product-types id-products -5 4
          set drinks-ready product-types id-products 0 4
          set shakes-ready product-types id-products 5 4

          let food-needed [food] of turtle min cars-list
          let drinks-needed [drinks] of turtle min cars-list
          let shakes-needed [shakes] of turtle min cars-list



          ; check to make sure that everything needed in the order is prepared
          ifelse everything-ready? food-needed drinks-needed shakes-needed food-ready drinks-ready shakes-ready
          [
            ;remove all items being prepared from the ready spots


            if length food-needed > 0
            [
              foreach food-needed
              [
                needed ->
                ask turtle one-of [who] of products with [item-id = needed and pxcor = -5 and pycor > 0] [die]
              ]
            ]

            if length drinks-needed > 0
            [
              foreach drinks-needed
              [
                needed ->
                ask turtle one-of [who] of products with [item-id = needed and pxcor = 0 and pycor > 0] [die]
              ]
            ]

            if length shakes-needed > 0
            [
              foreach shakes-needed
              [
                needed ->
                ask turtle one-of [who] of products with [item-id = needed and pxcor = 5 and pycor > 0] [die]
              ]
            ]



            ; add a new bag to be handed out
            create-bags 1 [
              set shape "box"
              set color brown
              set size 2.5
              setxy 6 12
              set bag# min cars-list
              set bag-label [label] of turtle min cars-list
              ;set label-color black
            ]


            set bagged-orders lput min cars-list bagged-orders

            set cars-list []
            set started-bagging 0
          ]
          [
            set cars-list remove-item 0 cars-list
          ]
        ]
      ]
    ]
  ]



end

to pay-for-order
  ask cars with [(pxcor = 13 and pycor = -4 and pw) or (pxcor = 13 and pycor = 12 and not pw)]
  [
    if pay-time = 0 [set pay-time random-normal avg-pay-time (avg-pay-time / 2)]
    if pay-time < 0 [set pay-time (-1 * pay-time)]
    if started-to-pay = 0 [set started-to-pay ticks]
    if ticks > pay-time + started-to-pay
    [
      if not paid?
      [
        set paid? true
        set color red
      ]
    ]
  ]
end

to hand-out
  if any? turtles-on patch 13 12 and any? turtles-on patch 6 12
  [

    let id 0
    if [paid?] of one-of turtles-on patch 13 12
    [
      ;create a list of the bagged orders
      let bagged-list [self] of turtles-on patch 6 12
      ;identify the car at the window
      let car-at-window one-of [who] of turtles-on patch 13 12
      ;check every bag to make sure we have the correct bag
      foreach bagged-list
      [
        bagged-turtle ->
        ;if the bag matches the car
        if [bag#] of bagged-turtle = car-at-window
        [
          if started-distributing = 0
          [
            set started-distributing ticks
            set distributing-time random-normal avg-distributing-time (avg-distributing-time / 2)
            if distributing-time < 10 [set distributing-time 10]
          ]

          if ticks - started-distributing > distributing-time
          [
            ;kill the car at the window
            ask turtles-on patch 13 12 [die]
            ;identify the bag that needs to die
            set id [who] of bagged-turtle
          ]
        ]

        if not (id = 0)
        [
          ask turtle id [die]
          set id 0
          set new-car-at-window? true
          set cars-served cars-served + 1
          set avg-window-time avg-window-time + ((ticks - started-at-window) - avg-window-time) / cars-served
          set started-distributing 0
        ]
      ]
    ]
  ]
end

to setup-patches
  set worked-#s []
  set finished-#s []
  set bagged-orders []
  ; make grass
  ask patches[
    set pcolor (random 3 + 61)
  ]
  repeat 20 [ diffuse pcolor 0.25 ]
  ; make the road
  ask patches with [pxcor > -16 and pxcor < 16 and pycor > -14] [set pcolor black]
  ask patches with [pxcor < 16 and pycor > 12] [set pcolor black]
  ;   make the building
  ask patches with [pxcor > -8 and pxcor < 12 and pycor > -10] [set pcolor gray]
  ; create DTO spots
  ifelse num-dto = 1 ; if there is one DTO
  [ ;                 left limit      right limit     upper limit   lower limit
    ask patches with [pxcor > -9 and pxcor < -7 and pycor < -5 and pycor > -10] [set pcolor blue]
  ] ; if there is more than one DTO
  [ ;                 left limit      right limit     upper limit   lower limit
    ask patches with [pxcor > -9 and pxcor < -7 and pycor < -5 and pycor > -10] [set pcolor blue]
    ask patches with [pxcor > -13 and pxcor < -11 and pycor < -5 and pycor > -10] [set pcolor blue]
  ]
  ; add a payment window if turned on
  if pw [ask patches with [pxcor > 10 and pxcor < 12 and pycor < -2 and pycor > -7] [set pcolor green - 2]]

  ; add a window for handing out food
  ask patches with [pxcor > 10 and pxcor < 12 and pycor < 14 and pycor > 9] [set pcolor red]
end

to setup-employees


  ask employees [die]

  if pw [
    create-employees 1
    [
      set color green - 2
      setxy 9 -5
      set shape "person"
      set size 4
    ]
  ]

  create-employees 1 ; window employee
    [
      set color red
      setxy 9 11
      set shape "person"
      set size 4
    ]

  create-employees 1 ; bagging employee
    [
      set color brown
      setxy 0 9
      set shape "person"
      set size 4
    ]

  create-employees 1 ; dto lane 1 employee
    [
      set color blue
      setxy -1 16
      set shape "person"
      set size 4
    ]

  if num-dto = 2
  [
    create-employees 1 ; dto lane 2 employee
    [
      set color blue
      setxy -5 16
      set shape "person"
      set size 4
    ]
  ]

  repeat num-food-prep-employees
  [
    create-employees 1 ; food prep employee
    [
      set color yellow
      setxy -5 -1
      set shape "person"
      set size 4
      set label num-food-prep-employees
    ]
  ]

  repeat num-drinks-prep-employees
  [
    create-employees 1 ; food prep employee
    [
      set color yellow
      setxy 0 -1
      set shape "person"
      set size 4
      set label num-drinks-prep-employees
    ]
  ]

  repeat num-shakes-prep-employees
  [
    create-employees 1 ; food prep employee
    [
      set color yellow
      setxy 5 -1
      set shape "person"
      set size 4
      set label num-shakes-prep-employees
    ]
  ]

  ask employees [set task-start 0]

  ;repeat num-positionless-prep-employees
  ;[
  ;  ifelse not any? employees-on patch -5 -1
  ;  [
  ;    create-employees 1 ; food prep employee
  ;    [
  ;      set color yellow + 2
  ;      setxy -5 -1
  ;      set shape "person"
  ;      set size 4
  ;      set label num-positionless-prep-employees
  ;    ]
  ;  ]
  ;  [
  ;    ifelse not any? employees-on patch -5 -1
  ;    [
  ;      create-employees 1 ; shakes prep employee
  ;      [
  ;        set color yellow + 2
  ;        setxy 0 -1
  ;        set shape "person"
  ;        set size 4
  ;        set label num-positionless-prep-employees
 ;       ]
 ;     ]
  ;    [
  ;      create-employees 1 ; positionless prep employee
  ;      [
  ;        set color yellow + 4
  ;        setxy 5 -1
  ;        set shape "person"
  ;        set size 4
  ;      ]
  ;    ]
  ;  ]
  ;]

end

to spawn-cars
  ; if the number of ticks is divisible by 10
  if ticks - (floor (ticks)) = 0
  [
    let join? (random 10000) / 10000 <= CARS_PER_TICK
    if join? [
      if not (((cars-fit - waiting-to-join-line) / cars-fit) > (random 1000) / 1000)
      [
        set cars-lost cars-lost + 1
        set join? false
      ]
    ]
    ; if the number generated is lower than or equal to the car join rate, spawn a car
    if join? or waiting-to-join-line > 0
    [
      ; if there's not someone blocking the spot to join
      ifelse not any? cars-on patch -19 15
      [
        add-car ; [set cars-lost cars-lost + 1]
        ; if there's more cars waiting, spawn them
        if waiting-to-join-line > 0 and not join?
        [
          ; there's one less car waiting
          set waiting-to-join-line waiting-to-join-line - 1
        ]
      ]
      [
        if join? [
          ; if there's no spot to join, add them up
          set waiting-to-join-line waiting-to-join-line + 1
        ]
      ]
    ]
  ]


end

to add-car
  create-cars 1 [
          set car-num car-num + 1
          set label car-num
          set breed cars
          set size 2.5
          set shape "car"
          set color blue
          setxy -19 15
          set paid? false
          set ordered? false
          set started-to-order 0
          set order-time 0
          set pay-time 0
          set started-to-pay 0
          set switch false
          set food []
          set drinks []
          set shakes []
          set num-food 0
          set num-drinks 0
          set num-shakes 0
          while [num-food < 1 and num-drinks < 1 and num-shakes < 1]
          [
            set num-food random-normal avg-food 2
            ;while [num-food < 0] [set num-food random-normal avg-food 2]
            set num-drinks random-normal avg-drinks 2
            ;while [num-food < 0] [set num-food random-normal avg-food 2]
            set num-shakes random-normal avg-shakes 2
            ;while [num-food < 0] [set num-food random-normal avg-food 2]
          ]
          repeat num-food [set food lput random 10 food]
          repeat num-drinks [set drinks lput random 10 drinks]
          repeat num-shakes [set shakes lput random 10 shakes]
        ]
end

to drive
  if true
  [
    ask cars with [shape = "car"]
    [
      ; cars start to advance in line
      if pycor = 15 and pxcor < -10.9 [
        set heading 90 ; set the starting heading
        if not any? cars-on patch-ahead 5 and not any? cars-on patch-ahead 4 and not any? cars-on patch-ahead 3 and not any? cars-on patch-ahead 2 and not any? cars-on patch-ahead 1
        [

          ; if there's room for you ahead, move forward.
          if not (count cars-on patches with [pxcor = -10] > 5) or pxcor != -14 [forward 1]
        ]
      ]

      ; cars continue to advance in line, switching lanes if one is shorter than the other
      if pycor > -10.9
      [
        if (pxcor = -10) or (pycor < 15 and pxcor = -14)
        [
          set heading 180 ; start moving downwards

          ; if there are no cars ahead
          if not any? cars-on patch-ahead 5 and not any? cars-on patch-ahead 4 and not any? cars-on patch-ahead 3 and not any? cars-on patch-ahead 2 and not any? cars-on patch-ahead 1
          [
            ; if there are less than 4 cars in the line on pycor = -11, don't join it. Otherwise, move forward.
            if ((count cars-on patches with [pycor = -11] < 4) and ordered?) or pycor != -8 [forward 1]

            ; if there are two drive-thru lanes, consider switching
            if num-dto = 2
            [
              if count cars-on patches with [pxcor = -10 and pycor < 14] > count cars-on patches with [pxcor = -14 and pycor < 14] + 1 and pxcor = -10
              [
                if pycor > 7
                [
                  set heading 270
                  if not any? cars-on patch-ahead 4 [forward 4]
                  set heading 180
                ]
              ]
            ]
          ]
        ]
      ]

      ; cars, once they are finished ordering, begin advancing to the payment window
      if pycor = -11 and pxcor < 12.1 [

        ; start moving to the right
        set heading 90

        ; if there are no cars ahead
        if not any? cars-on patch-ahead 5 and not any? cars-on patch-ahead 4 and not any? cars-on patch-ahead 3 and not any? cars-on patch-ahead 2 and not any? cars-on patch-ahead 1
        [
          ; if there is not a car ahead, you can move forward (accounting for the potential change of direction ahead)
          if (not any? cars-on patches with [pxcor = 13 and pycor > -12 and pycor < -7]) or pxcor != 10 [forward 1]
        ]
      ]

      ; start moving towards the window and payment area
      if pxcor = 13 and pycor < 12 [
        if not any? cars-on patch-ahead 5 and not any? cars-on patch-ahead 4 and not any? cars-on patch-ahead 3 and not any? cars-on patch-ahead 2 and not any? cars-on patch-ahead 1
        [
          set heading 0
          if paid? or (pycor < -4 or (pycor < 12 and not pw)) [forward 1]
          ;if (pycor = -4 and pw) or (pycor = 12 and not pw) [pay-for-order]
        ]
      ]

      if any? turtles-on patch 13 12 and new-car-at-window? = true
      [
        set started-at-window ticks
        set new-car-at-window? false
      ]


      ; this is mostly for testing, uncomment the below line to make the cars dissapear after they leave the window
      ;if pxcor > 12 and pycor > 12 [die]
    ]
  ]
  if not any? turtles-on patch 13 12
      [
        set started-at-window ticks + 1
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
1056
10
1537
426
-1
-1
11.0
1
10
1
1
1
0
0
0
1
-21
21
-18
18
1
1
1
seconds
30.0

BUTTON
1058
438
1165
483
NIL
setup
NIL
1
T
OBSERVER
NIL
S
NIL
NIL
1

SLIDER
11
392
153
425
CARS_PER_TICK
CARS_PER_TICK
0
0.1
0.02
0.001
1
NIL
HORIZONTAL

BUTTON
1171
438
1278
483
NIL
go
T
1
T
OBSERVER
NIL
G
NIL
NIL
1

BUTTON
1283
438
1390
483
 go n times
setup\ntest
NIL
1
T
OBSERVER
NIL
O
NIL
NIL
1

MONITOR
887
402
1039
447
num cars waiting to join line
waiting-to-join-line
0
1
11

SLIDER
7
76
157
109
num-dto
num-dto
1
2
1.0
1
1
NIL
HORIZONTAL

SWITCH
7
39
157
72
pw
pw
0
1
-1000

SLIDER
7
151
157
184
cars-fit
cars-fit
1
5
5.0
1
1
NIL
HORIZONTAL

SLIDER
9
272
136
305
avg-order-time
avg-order-time
0
200
58.0
2
1
NIL
HORIZONTAL

SLIDER
11
431
153
464
avg-food
avg-food
0
5
1.0
1
1
NIL
HORIZONTAL

SLIDER
11
472
155
505
avg-drinks
avg-drinks
0
5
1.0
1
1
NIL
HORIZONTAL

SLIDER
11
511
155
544
avg-shakes
avg-shakes
0
5
1.0
1
1
NIL
HORIZONTAL

MONITOR
529
39
618
84
food in queue
count turtles with [pxcor = -5 and pycor = -6]
17
1
11

MONITOR
624
38
720
83
drinks in queue
count turtles with [pxcor = 0 and pycor = -6]
17
1
11

MONITOR
726
38
825
83
shakes in queue
count turtles with [pxcor = 5 and pycor = -6]
17
1
11

SLIDER
11
314
137
347
avg-pay-time
avg-pay-time
0
200
30.0
1
1
NIL
HORIZONTAL

SLIDER
304
210
440
243
avg-food-prep-time
avg-food-prep-time
0
200
60.0
2
1
NIL
HORIZONTAL

MONITOR
529
87
618
132
food ready
count turtles-on patch -5 4
0
1
11

MONITOR
624
87
721
132
drinks ready
count turtles-on patch 0 4
17
1
11

MONITOR
726
87
826
132
shakes ready
count turtles-on patch 5 4
17
1
11

SLIDER
303
316
438
349
avg-drinks-prep-time
avg-drinks-prep-time
0
200
30.0
2
1
NIL
HORIZONTAL

SLIDER
305
428
438
461
avg-shakes-prep-time
avg-shakes-prep-time
0
200
120.0
2
1
NIL
HORIZONTAL

MONITOR
887
84
1039
129
Window time (current)
ticks - started-at-window
17
1
11

MONITOR
886
145
1038
190
Window time (average)
round avg-window-time
17
1
11

MONITOR
528
431
678
476
bagged orders
sort [bag-label] of turtles-on patch 6 12
17
1
11

MONITOR
527
208
688
253
food waiting on
food-waiting-on
17
1
11

MONITOR
527
258
688
303
drinks waiting on
drinks-waiting-on
17
1
11

MONITOR
527
308
688
353
shakes waiting on
shakes-waiting-on
17
1
11

SLIDER
302
88
436
121
avg-bagging-time
avg-bagging-time
0
200
24.0
2
1
NIL
HORIZONTAL

SLIDER
9
228
134
261
avg-distributing-time
avg-distributing-time
0
200
40.0
2
1
NIL
HORIZONTAL

MONITOR
887
272
1039
317
number of employees
num-employees
17
1
11

SLIDER
304
172
439
205
num-food-prep-employees
num-food-prep-employees
1
10
1.0
1
1
NIL
HORIZONTAL

SLIDER
303
278
438
311
num-drinks-prep-employees
num-drinks-prep-employees
1
10
1.0
1
1
NIL
HORIZONTAL

SLIDER
305
393
439
426
num-shakes-prep-employees
num-shakes-prep-employees
1
10
6.0
1
1
NIL
HORIZONTAL

CHOOSER
1395
438
1503
483
n
n
1 60 600 1800 3600 5000 86400
4

SWITCH
1059
489
1166
522
set-seed
set-seed
1
1
-1000

MONITOR
887
334
1039
379
NIL
cars-lost
17
1
11

TEXTBOX
532
10
738
35
Order Progress:
20
0.0
1

TEXTBOX
310
150
460
168
Food:
12
0.0
1

TEXTBOX
308
256
458
274
Drinks:
12
0.0
1

TEXTBOX
311
370
461
388
Shakes:
12
0.0
1

TEXTBOX
305
68
455
86
Bagging:
12
0.0
1

TEXTBOX
11
197
212
220
Customer Interaction:
20
0.0
1

TEXTBOX
13
363
209
391
Customer Properties:
20
0.0
1

SWITCH
7
113
157
146
outdoor-dto
outdoor-dto
0
1
-1000

MONITOR
887
209
1039
254
NIL
cars-served
17
1
11

TEXTBOX
527
146
815
221
What is the car in front waiting on?
20
0.0
1

TEXTBOX
530
368
823
443
What orders have already been prepared?
20
0.0
1

TEXTBOX
303
12
491
62
Order Preparation Employees:
20
0.0
1

TEXTBOX
8
10
225
60
Drive-Thru Properties:
20
0.0
1

TEXTBOX
887
17
1037
79
Performance Statistics:
25
0.0
1

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
NetLogo 6.2.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="data-collection4" repetitions="3" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="21600"/>
    <metric>count employees</metric>
    <metric>count cars + waiting-to-join-line</metric>
    <metric>count products</metric>
    <metric>count bags</metric>
    <metric>avg-window-time</metric>
    <metric>cars-served</metric>
    <metric>cars-lost</metric>
    <metric>seed</metric>
    <enumeratedValueSet variable="CARS_PER_TICK">
      <value value="0.01"/>
      <value value="0.012"/>
      <value value="0.014"/>
      <value value="0.016"/>
      <value value="0.018"/>
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-food-prep-employees">
      <value value="1"/>
      <value value="2"/>
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="avg-distributing-time">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="avg-shakes">
      <value value="0"/>
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="avg-drinks">
      <value value="0"/>
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="avg-food-prep-time">
      <value value="60"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="avg-pay-time">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-drinks-prep-employees">
      <value value="1"/>
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="avg-food">
      <value value="0"/>
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pw">
      <value value="false"/>
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="set-seed">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="avg-bagging-time">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-dto">
      <value value="1"/>
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="avg-drinks-prep-time">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="avg-order-time">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="outdoor-dto">
      <value value="false"/>
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="avg-shakes-prep-time">
      <value value="120"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-shakes-prep-employees">
      <value value="1"/>
      <value value="2"/>
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="avg_order_size">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cars-fit">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="n">
      <value value="3600"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="does-distributing-speed-make-a-difference?" repetitions="3" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="21600"/>
    <metric>count turtles</metric>
    <enumeratedValueSet variable="CARS_PER_TICK">
      <value value="0.01"/>
      <value value="0.012"/>
      <value value="0.014"/>
      <value value="0.016"/>
      <value value="0.018"/>
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="avg-distributing-time">
      <value value="0"/>
      <value value="10"/>
      <value value="20"/>
      <value value="30"/>
      <value value="40"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-food-prep-employees">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="avg-shakes">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="avg-drinks">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="avg-food-prep-time">
      <value value="60"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="avg-pay-time">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-drinks-prep-employees">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="avg-food">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pw">
      <value value="false"/>
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="set-seed">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="avg-bagging-time">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-dto">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="avg-drinks-prep-time">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="avg-order-time">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="avg-shakes-prep-time">
      <value value="120"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="outdoor-dto">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-shakes-prep-employees">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="avg_order_size">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cars-fit">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="n">
      <value value="3600"/>
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
