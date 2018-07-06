               ;;; ;;;;;;;;;;;;;;;;;;;;;;;;; ;;;
               ;;; ;;; Breed definitions ;;; ;;;
               ;;; ;;;;;;;;;;;;;;;;;;;;;;;;; ;;;

;;  Different breeds has to be defined at the beginning of the code

breed [ intersections intersection ]  ;; Intesections are defined to represent intersections in the transportation network
undirected-link-breed [ roads road ]  ;; Roads are defined as undirectional links connecting intersections together

breed [ pedestrians pedestrian ]  ;; pedestrians and residents is the breed of the evacuess respectively after and before they reach the transportation network
breed [ residents resident]  ;; residents evolve to pedestrians as they reach to transportation network
breed [ cars car] ;; people drive cars to escape faster but have to obey laws of the road

        
               ;;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; ;;;
               ;;; ;;; The variables of different breeds own ;;; ;;;
               ;;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; ;;;

patches-own [
  depth              ;; Patches own the tsunami inundation information and the patch-color changes based on the water depth as time goes by
  depths
]

roads-own [
  crowd              ;; The number of people on each road at a certain time
]

intersections-own [
   gate?             ;; Boolean variable indicating if the intersection is an evacuation gate or not
   gate-type         ;; Type of the gate: {'Hor': Horizontal, 'Ver': Vertical}

   temp-id           ;; System varibales for shortest path algorithm and network construction
   previous
   fscore
   gscore
   ver-path
   hor-path
   familiar-paths
   watched?
   speed
   confidence
   tourist?
   child?
   elder?
   sex
   car?
   family
   
   LTgoal
   STgoal
   ]

residents-own [      ;; The varibles owned by the residents, such as milling time, decision code, speed, origin, destination, status, etc.
  decision
  miltime
  gll
  origin
  speed
  fd-speed
  moving?
  evacuated?
  rchd?
  watched?
  confidence
  tourist?
  child?
  elder?
  sex
  car?
  family
  
  LTgoal
  STgoal
]

pedestrians-own [    ;; The varibles owned by the pedestrians, such decision code, speed, origin, destination, status, etc.
  origin
  prev-origin
  goal
  destination
  moving?
  evacuated?
  speed
  fd-speed
  path
  decision
  travel-log
  watched?
  confidence
  tourist?
  child?
  elder?
  sex
  car?
  family
  
  flockmates
  nearest-neighbor
  
  LTgoal
  STgoal
]

cars-own[
  origin
  prev-origin
  goal
  destination
  moving?
  evacuated?
  speed
  fd-speed
  path
  decision
  confidence
  tourist?
  child?
  elder?
  car?
  family
  travel-log
  flockmates
  nearest-neighbor
  
  watched?
  LTgoal
  STgoal
]


               ;;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;; ;;;  
               ;;; ;;; The global variables ;;; ;;;
               ;;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;; ;;;

globals [            ;; global variables are the ones the varibales we intend to use globally throught our code
  ev-times
  xrs
  yrs
  rsnum
;  origins
  mouse-was-down?
  vert-cap
  touristpop
  elderlypop
  childpop
  carpop
  
  ]


               ;;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; ;;;
               ;;; ;;; Helpers and Setup Functions ;;; ;;;
               ;;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; ;;;


;;;;;;;;;;;;;;; Functions to preform flocking behavior, taken from NetLogo Models library Flocking v.5.1.0;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;; Finds pedestrians nearby that are worthy of following
to find-flockmates
  if breed = cars[
    set flockmates other cars in-radius (0.0059053 * 100) with [confidence > 35]
  ]
  if breed = pedestrians[
    set flockmates other pedestrians in-radius (0.0059053 * 100) with [confidence > 35]
  ]
  if flockmates = Nobody[
    set flockmates other turtles in-radius (0.0059053 * 100) with [confidence > 35]
  ]
  
end

;; sets nearest neighbor to flockmate nearby (unused?)
to find-nearest-neighbor
  set nearest-neighbor max-one-of flockmates [confidence]
  if nearest-neighbor != Nobody[
    ;set path ([path] of nearest-neighbor)
  ]
end


;;;;;;;;;;;;;;; Function to load transportation network from the file ;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Loads in roads and intersections
to load-network [ filename ]
  if (filename = false)
    [ stop ]
  file-open filename
  let num-intersections file-read
  let num-links file-read
  let ideal-segment-length file-read

  let id-counter 0
  repeat num-intersections
  [
    create-intersections 1 [
      set temp-id id-counter
      set id-counter id-counter + 1
      set xcor file-read
      set ycor file-read
      set gate? false
      set size 0.1
      set shape "square"
      set color white
    ]
  ]
  repeat num-links
  [
    let id1 file-read
    let id2 file-read
    let primary? file-read

    ask intersections with [ temp-id = id1 ]
    [
        create-roads-with intersections with [ temp-id = id2 ]
    ]
  ]
  ask roads [
    set color black
    set thickness 0.05
  ]

  file-close
  output-print "Network Loaded"
  beep
end


;;;;;;;;;;;;;;; Function for Exporting data into usable formats ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;





;;;;;;;;;;;;;;; Funnctions to calculate, save, and load routes according to shortest path algorithm ;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Loads in astar routes
to load-routes
  load-routes-file "hor-routes"
  load-routes-file "ver-routes"
  load-routes-file "familiar-routes"

  output-print "Routes Loaded"
  beep
end

;; gives routes to intersections
to load-routes-file [file-name]
  if (file-name = false) [ stop ]
  file-open file-name
  
  let mode file-read
  let cnt file-read

  if mode = -1 [
    repeat cnt [
      let num file-read
      ask intersection num [
        set ver-path file-read
      ]
    ]
  ]
  
  if mode = 0 [
    repeat cnt [
      let num file-read
      ask intersection num [
        set hor-path file-read
      ]
    ]
  ]
  
  if mode = 1 [
    repeat cnt [
      let num file-read
      ask intersection num [
        set familiar-paths file-read
      ]
    ]
  ]
    
  file-close
end

;; sets steps to shelters
to save-routes [ mode filename ]
  file-close-all
;  find-origins
  carefully [ file-delete filename ] [ ]
  if (filename = false)
    [ stop ]
  ;let id 1
  file-open filename
  file-write mode
  file-write count intersections
  
  ask intersections [
    ;show id
    file-write who
    
    ; Optimal path to nearest shelter
    ifelse (mode != 1) 
    [
      file-write Astar self (selectGoal self mode) ;; selectGoal handles hor vs ver case
    ]
  
    ; Set of first steps towards all non optimal shelters
    [
      let familiar-options []
      let other-goals selectGoal self mode

      ask other-goals [
        set familiar-options lput (Optimal-Step myself self) familiar-options 
      ]
      set familiar-options remove-duplicates familiar-options ;;!! maybe dont remove duplicates to give higher chance of picking a direction that leads to many shelters?
      file-write familiar-options
    ]
  ]
  file-close
end

;; saves routes as labelled
to routes
  save-routes 0 "hor-routes"
  save-routes -1 "ver-routes"
  save-routes 1 "familiar-routes"
end

;; Resets certain values
to finish-routes
  load-routes
  ask roads [
    set crowd 0
  ]
  set ev-times []
  reset-ticks
  tick
end

;; the goals list holds the intersections along the way to the nearest evac shelter. Populates this list. 
to-report selectGoal [ source evac-type ]
  let goals []
  ifelse evac-type != -1  [
    set goals intersections with [gate? and gate-type = "Hor"]
  ]
  [
    set goals intersections with [gate?] ;and gate-type = "Ver" ] ;;!!
  ]

  let return_goal nobody
  ask min-one-of goals [distance source] [
    ifelse evac-type = 1 [
      set return_goal other goals ;; Set of shelters that are not the closest  
    ]
    [
      set return_goal self ;; Closest shelter
    ]
  ]
  
  report return_goal
end

;; Astar
to-report Astar-smallest [ q ]
  let rep 0
  let fsc 100000000
  foreach q [
    let fscr [fscore] of intersection ?
    if fscr < fsc [
      set fsc fscr
      set rep ?
    ]
  ]
  report rep
end

to-report hce [ source gl]  ;; Heuristic for the A* search algorithm
  let euclidian 100000
  ask source [
    set euclidian distance gl
  ]
  report euclidian
end

to-report Astar [ source gl ] ;; A* shortest path algorithm, refer to https://en.wikipedia.org/wiki/A*_search_algorithm
  let reached? false
  let dstn nobody
  let closedset []
  let openset []

  ask intersections [
    set previous -1
  ]

  set openset lput [who] of source openset
  ask source [
    set gscore 0
    set fscore (gscore + hce source gl)
  ]
  while [ not empty? openset and (not reached?)] [
    let current Astar-smallest openset
    if current = [who] of gl [
      set dstn intersection current
      set reached? true
    ]
    set openset remove current openset
    set closedset lput current closedset
    ask intersection current [
      let neighbs link-neighbors
      ask neighbs [
        let tent-gscore [gscore] of myself + [link-length] of (road who [who] of myself)
        let tent-fscore tent-gscore + hce self gl
        if ( member? who closedset and ( tent-fscore >= fscore ) ) [stop];[ continue ]
        if ( not member? who closedset or ( tent-fscore >= fscore )) [
          set previous current
          set gscore tent-gscore
          set fscore tent-fscore
          if not member? who openset [
            set openset lput who openset
          ]
        ]
      ]
    ]
  ]

  let route []
  ifelse dstn != nobody [
    while [ [previous] of dstn != -1 ] [
      set route fput [who] of dstn route
      set dstn intersection ([previous] of dstn)
    ]
  ]
  [
    set route []
  ]
  report route
end


;; Same algorithm as Astar for finding optimal path, however it returns only the very first step in that path. 
;; All Intersections get a set of first-steps towards all shelters, for use by agents following the Familiar LTgoal
to-report Optimal-Step [ source gl] ;; returns the first intersection number A* would choose to path to a given shelter
  let reached? false
  let dstn nobody
  let closedset []
  let openset []

  ask intersections [
    set previous -1
  ]

  set openset lput [who] of source openset
  ask source [
    set gscore 0
    set fscore (gscore + hce source gl)
  ]
  while [ not empty? openset and (not reached?)] [
    let current Astar-smallest openset
    if current = [who] of gl [
      set dstn intersection current
      set reached? true
    ]
    set openset remove current openset
    set closedset lput current closedset
    ask intersection current [
      let neighbs link-neighbors
      ask neighbs [
        let tent-gscore [gscore] of myself + [link-length] of (road who [who] of myself)
        let tent-fscore tent-gscore + hce self gl
        if ( member? who closedset and ( tent-fscore >= fscore ) ) [stop];[ continue ]
        if ( not member? who closedset or ( tent-fscore >= fscore )) [
          set previous current
          set gscore tent-gscore
          set fscore tent-fscore
          if not member? who openset [
            set openset lput who openset
          ]
        ]
      ]
    ]
  ]

  let route []
  ifelse dstn != nobody [
    while [ [previous] of dstn != -1 ] [
      set route fput [who] of dstn route
      set dstn intersection ([previous] of dstn)
    ]
  ]
  [
    set route []
  ]
  report first route
end
  
;;;;;;;;;;;;;;; Functions to load the horizontal evacuation gates information from the file ;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Loads the evac spots from the file into the model
to load-gates
   ask intersections [
    set gate? false
    set color white
    set size 0.1
  ]

  load-gates-file "Gates"

  output-print "Gates Loaded"
  beep
end

;; See above
to load-gates-file [ filename ]
  if (filename = false)
    [ stop ]
  file-open filename
  let mode file-read
  let num file-read
  repeat num [
    ask intersection file-read [
       st
       set gate? true
       if mode = 0 [set gate-type "Hor"]
       if mode = -1 [set gate-type "Ver"]
    ]
  ]

  file-close
  beep
end

;; sets shape and color so we know where evac spots are
to show-gates
  ask intersections with [gate? = true and gate-type = "Hor"]
  [
    set shape "circle"
    set size 2
    set color yellow
  ]

  ask intersections with [gate? = true and gate-type = "Ver"]
  [
    set shape "circle"
    set size 2
    set color violet
  ]
end



;;;;;;;;;;;;;;; Functions to load the Vertical evacuation shelters & special Agent based on user input (Mouse Click) ;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Used for mouse-functions
to-report mouse-clicked?
  report (mouse-was-down? = true and not mouse-down?)
end

;; Allows user to set vertical evacuation shelters or can instead use as "escaping the model" exit point.
to pick-verticals
  let mouse-is-down? mouse-down?
  if mouse-clicked? [
    ask min-one-of intersections [distancexy mouse-xcor mouse-ycor][
      set gate? true
      set gate-type "Ver"
      set shape "circle"
      set size 2
      set color violet
    ]
    display
  ]
  set mouse-was-down? mouse-is-down?
end

to make-vertical [id]
  ask intersection id [
    set gate? true
    set gate-type "Ver"
    set shape "circle"
    set size 2
    set color violet
  ]
  display
end

;; Used for expo, allows user to place an agent anywhere they choose with selected parameters from primary screen.
to place-agent
  let mouse-is-down? mouse-down?
  if mouse-clicked? [
    ask one-of residents [ 
      
        move-to patch mouse-xcor mouse-ycor
        set tourist? choose-tourist
        set car? choose-car
        let val choose-confidence * 10
        set confidence val
        if choose-age = "Child"[
          set child? 1
          set elder? 0
        ]
        
        if choose-age = "Adult"[
          set child? 0
          set elder? 0
        ]
        
        if choose-age = "Elderly"[
          set child? 0
          set elder? 1
        ]
        
        ifelse choose-flock [
         set LTgoal  "flock" 
        ]
        [
          set LTgoal "familiar"
        ]
        
        set color 85
        set shape "star"
        set gll min-one-of intersections [ distance myself ]
        inspect resident who
        set size 1
        set watched? 1
      
    ] 
  ]
  
    display
  
  set mouse-was-down? mouse-is-down?
end



;;;;;;;;;;;;;;; Functions to load the Tsunami inundation information  ;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;Loads in the tsunami data depending on choice
to load-Tsunami
  let file-name ""
  let rep 0
  if tsunami-case = "500yrs" [set file-name "tsunamiFiles/Seaside_500yr.dat" set rep 120]
  if tsunami-case = "1000yrs" [set file-name "tsunamiFiles/Seaside_1000yr.dat" set rep 121]
  if tsunami-case = "2500yrs" [set file-name "tsunamiFiles/Seaside_2500yr.dat" set rep 121]
  file-open file-name
  while [ not file-at-end? ]
  [
    let xd file-read
    let yd file-read
    set xd ( xd + 123.92401) / 0.00066
    set yd ( yd - 45.99305 ) / 0.00047


    let dps [0]

    repeat rep [
      set dps lput file-read dps
    ]


    ask patch xd yd [
      set depths dps
    ]
  ]

  file-close
  output-print "TsunamiData Loaded"
  beep
end



;;;;;;;;;;;;;;; Functions to load the evacuees based on the pre-created population distribution ;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Loads the population
to load-population
  setup-residents
  output-print "Population Loaded"
  beep
end

;; sets up the residents
to read-residents [ filename ]
  file-close-all
  if (filename = false)
    [ stop ]
  set xrs []
  set yrs []
  file-open filename
  set rsnum file-read
  repeat rsnum [
    set xrs lput file-read xrs
    set yrs lput file-read yrs
  ]
  file-close
  beep
end


;; creates the residents with a multitude of parameters and attributes.
to setup-residents

  ask residents [ die ]
  ask cars [ die ]
  ask intersections with [not gate?][ set size 0.01]
  let xr xrs
  let yr yrs
  
  ;setting family values
  let famsize 0
  let famprog 0
  let fam 0
  
  

  repeat rsnum [
    
    ;;random number between 1 and population
    let tourand random rsnum
    let elderand random rsnum
    let childrand random rsnum
    let carand random rsnum

      
    create-residents 1 [
      
      ;;initialize all agents to be not tourists
      set tourist? 0
      
      set xcor item 0 xr
      set ycor item 0 yr
      set xr remove-item 0 xr
      set yr remove-item 0 yr
      set color brown
      set shape "dot"
      set size 1
      set moving? true
      set gll min-one-of intersections [ distance myself ]
      set speed random-normal Ped-Speed Ped-Sigma
      
      ;; 1 ft = 0.0059043 patch
      ;; 1 patch = 169.37 ft
      ;; 1 mph = 31.175 patch
      ;; 1 ft/s = 0.0059043 fd
      ;; 1 mph = 0.008659637 fd
      
      set speed speed * 0.0059043
      if speed < 0.001 [set speed 0.001]

      set evacuated? false
      set rchd? false
      let rnd random 100
      ifelse (rnd < R1-HorEvac-Foot ) [
        set decision 1
        set miltime ((Rayleigh-random Rsig1) + Rtau1 ) * 60
      ]
      [
        set decision 3
        set miltime ((Rayleigh-random Rsig3) + Rtau3 ) * 60
      ]

      if immediate-evacuation [
        set miltime 0
      ]
      st
    ]
    
  ]
  
  
;;;;;;;;;;;;;; DEMOGRAPHICS ;;;;;;;;;;;;;;
  
  ;;takes population * tourist percent = #oftourists
  set touristpop (rsnum * tourist-population)
  
  ;;takes population * elderly percent = #ofelderly
  set elderlypop (rsnum * elderly-population)
  
  ;;takes population * children percent = #ofchildren
  set childpop (rsnum * children-population)
  
  ;;takes population * percent of people that own vehicle = #ofcars that start with people in them
  set carpop (rsnum * car-population)
  
  ;; sets touristpop # of residents to be a tourist
  ask n-of touristpop residents [
      set tourist? 1
    ]
  
  ;; sets elderlypop # of residents to be elderly
  ask n-of elderlypop residents [
      set elder? 1
      set child? 0
    ]
  
  ;; sets carpop # of cars starting in map
  ask n-of carpop residents [
      set car? 1
  ]
  
  ;; sets childpop # of residents to be children
  let children residents with [elder? = 0]
  if any? children[
    ask n-of childpop children[
      set child? 1
      set elder? 0
      set car? 0
    ]
  ]
    
  ;; assigns sex, no impact on model
  ask residents [
      ifelse random 2 = 0 [set sex "male"] [set sex "female"]    
    ]

  ;;;;;; CONFIDENCE ;;;;;;
  ;;gets the demographics of each resident and adjusts their confidence based on type
  ask residents [
    
    ifelse tourist? = 1[
      set confidence random 30
    ][
    set confidence random 50
    ]
    
    if child? = 1 [
      set confidence (confidence + random 5)
      set speed (0.75 * speed)
      set miltime (miltime * 1.25)
    ]
    
    if elder? = 1[
      set confidence (confidence + random 15)
      set speed (0.75 * speed)
      set miltime (miltime * 1.15)
    ]
    
    if elder? = 0 and child? = 0[
      set confidence (confidence + random 30)
    ]
           
    ;;assign families
    if (famprog >= famsize) [
      set famsize random 10 
      set famprog 0
      set fam fam + 1
    ]
    set family fam
    set famprog famprog + 1
  
   ;;;;;;;;;;;;;; GOALS ;;;;;;;;;;;;;;
    
    
                 ;; LONG TERM
    ;; long term goals will stick for most of/all of the simulation 
    ;; they can be set here and used as default pathing for agents when no immediate short term goals have their attention
    
    ;; possible long term goals:
    ;; hor - shelter
    ;; ver - leave town
    ;; flock - wander until encountering other agents then follow them
    ;; familiar - non-optimal path using a random path in the right general direction of one of the shelters from current intersection
    
    let roll random 100
    ifelse confidence > roll 
    [
      set LTgoal "hor"                 ;;ped knows how to get to a shelter
    ]
    [                              
      set LTgoal "ver"                 ;;ped attempts to leave town
    ] 
                                    
    if confidence < 35 
    [   
      set LTgoal "flock"                ;;ped follows others
    ]
    
    if confidence < 80 and confidence >= 35 
    [   
      set LTgoal "familiar"                      ;;ped non-optimally paths towards shelter direction
    ]
        
        
                   ;; SHORT TERM
    ;; short term goals are set and evaluated within ped decision making logic, as they change often and rely on immediate surroundings    
    set STgoal "none"
    beep   
  ]
  
end

to-report rayleigh-random [sigma] ;; Rayleigh distribtion to replicate the milling time of the evacuees, Refer to https://en.wikipedia.org/wiki/Rayleigh_distribution

  report (sqrt( ( - ln ( 1 - random-float 1 )) * ( 2 * ( sigma ^ 2 ))))

end



;;;;;;;;;;;;;;; Function to initialize the input values ;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; sets up inital values for model
to setup-init-val
  set R1-HorEvac-Foot 50
  set R3-VerEvac-Foot 50

  set Hc 0.5

  set immediate-evacuation False
  set tsunami-case "500yrs"

  set Ped-Speed 3
  set Ped-Sigma 0.65

  set Rtau1 5
  set Rsig1 1.5
  set Rtau3 5
  set Rsig3 1.5
  set tourist-population 0.15
  
end

;; Used for randomly setting initial values, used for multi-iterative testing only. Not used in Expo model
to init-random
  random-seed new-seed
  let testyrs random 3
  if testyrs = 0[
    set tsunami-case "500yrs"
  ]
  if testyrs = 1[
    set tsunami-case "1000yrs"
  ]
  if testyrs = 2[
    set tsunami-case "2500yrs"
  ]
  
  let testimed random 2
  ifelse testimed = 0 [
    set immediate-evacuation true
  ][
  set immediate-evacuation false
  ]
  set R1-HorEvac-Foot 50
  set R3-VerEvac-Foot 50

  set Hc 0.5

  ;set immediate-evacuation False
  ;set tsunami-case "500yrs"

  set Ped-Speed 3
  set Ped-Sigma 0.65

  set Rtau1 5
  set Rsig1 1.5
  set Rtau3 5
  set Rsig3 1.5
  set tourist-population ((random 15 + 1) / 100)
  set car-population ((random 15 + 1) / 100)
  set children-population ((random 15 + 1) / 100)
  set elderly-population ((random 15 + 1) / 100)
  reset-ticks
  
end

;;;;;;;;;;;;;;; Functions to read the data files and load the model ;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; reset the model
to pre-read
  file-close-all
  ca
  ask patches [set pcolor white]
  ask residents [die]
  ask pedestrians [die]
  ask cars [die]
  ;;ask cars [die]
  set ev-times []
  set vert-cap 0
  load-network "Map"
  load-Tsunami
  load-gates
  show-gates

end

to read-all
  
  ;;This section is so that you can reset by just pressing (2) as long as the tsunami hasn't hit yet.
  ;;Much faster to debug this way!
  ask residents [ die ] 
  ask pedestrians [ die ]
  ask cars [ die ]
  
  
  read-residents "Pop"
  load-population
end


;;;;;;;;;;;;;;; Aditional Helper Functions ;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to XYs [filename]
  carefully [ file-delete filename ] [ ]
  if (filename = false)
    [ stop ]
  file-open filename
  let id 1
  ask intersections [
    show id
    set id id + 1
    file-write -123.92401 + (xcor / 1515.1515)
    file-write 45.99305 + (ycor / 2127.6595)

    file-print ""
  ]
  file-close
end


to plot-centroids
  file-close-all
  file-open "centroid_cords.txt"
  while [not file-at-end?] [
    crt 1 [
      set xcor (file-read + 123.92401) / 0.00066
      set ycor (file-read - 45.99305 ) / 0.00047
      set size 2
      set shape "circle"
      set color red
    ]
  ]

  file-close
end




               ;;; ;;;;;;;;;;;;;;;;;;;;;;;;; ;;;
               ;;; ;;; MAIN GO PROCEDURE ;;; ;;;
               ;;; ;;;;;;;;;;;;;;;;;;;;;;;;; ;;;                                               

to go
  
  
  ;;Road dynamic coloration
  
  ifelse RoadColor[
  ask roads [
    if crowd <= 10 [set color black set thickness .05]
    if crowd > 20 [set color 35 set thickness .25]
    if crowd > 30 [set color 55 set thickness .45]
    if crowd > 50 [set color 65 set thickness .65]
    if crowd > 80 [set color 75 set thickness .80]
    if crowd > 100 [set color 85 set thickness .85]
    if crowd > 120 [set color 95 set thickness .90] 
    if crowd > 140 [set color 125 set thickness .95]
    if crowd > 160 [set color 45 set thickness 1]
    if crowd > 180 [set color 25 set thickness 1.05]
    if crowd > 200 [set color 15 set thickness 1.1]
    ]
  ]
  [ ask roads [
      set color black set thickness .05]
  ]
  
  if ticks >= 3600 [  ;; Stop the simulation after one hour
    ask pedestrians with [color != red][
      set color green
    ]
    ask residents with [color != red][
      set color green
    ]
    stop
  ]

  if ticks mod 30 = 0 [
    ask patches with [depths != 0][
      set depth item int(ticks / 30) depths
    ]

    ask patches [
      let cl 99.9 - depth
      if cl < 90 [set cl 90]
      if cl > 99.9 [set cl 99.9]
      set pcolor cl
    ]
  ]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; ASK RESIDENTS ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    ;; AGENT COLORS:
          ;; red - dead
          ;; dark green - evacuated
          ;; brown - not on road network, seeking it
          ;; yellow - seeking tsunami shelter (hor) A*
          ;; violet - seeking to leave town (ver)
          ;; pink - flock behavior, following other agents
          ;; orange - seeking tsunami shelter direction with non-optimal path 
          ;; blue - cars
          
    ;; This section allows residents to path to the nearest road before turning into a pedestrian ;;
  ask residents with [(moving? = true) and (miltime <= ticks)]
  [
    set heading towards gll
    ifelse (distance gll < (speed) ) 
    [set fd-speed distance gll]
    [set fd-speed speed]
    
    fd fd-speed
    if (distance gll < 0.0005 )
    [
      move-to gll
      set moving? false
      set rchd? true
      set origin gll
      if [gate?] of origin
      [
        set color green
        set moving? 0
        set evacuated? true
      ]
      if [depth] of patch-here >= Hc and evacuated? = false
      [
        set color red
        set moving? 0
        set evacuated? true
      ]
    ]
  ]

      ;; This section checks if the resident has drowned  ;;
  ask residents with [ rchd? = false and evacuated? = false]
  [
    if [depth] of patch-here > Hc 
    [
      set color red
      set moving? 0
      set evacuated? true
    ]
  ]

    ;; RESIDENT HATCHES PEDESTRIAN, sets LTgoal behavior ;;
  ask residents with [ rchd? = true ]
  [
    
    ;; PATHING BASED ON GOALS
    ask origin
    [
      ;;;;; Carry values from residence to pedestrians/cars ;;;;;
      set speed [speed] of myself
      set tourist? [tourist?] of myself
      set elder? [elder?] of myself
      set child? [child?] of myself
      set confidence [confidence] of myself
      set sex [sex] of myself
      set car? [car?] of myself
      set LTgoal [LTgoal] of myself
      set STgoal [STgoal] of myself
      set family [family] of myself
      set watched? [watched?] of myself
      set shape [shape] of myself
      ;set path [path] of myself
       
            
      ;;;;; Car Spawn ;;;;;
      ifelse (car? = 1 or car? = True)
      [
        hatch-cars 1
        [
          set color blue
          set size 1
          set shape "car"
          set speed 0.1
          if (elder? = 1)[set speed 0.05]
          
          set LTgoal [LTgoal] of myself
          set STgoal [STgoal] of myself
          set origin myself
          set watched? [watched?] of myself
          set travel-log []
          set travel-log lput ([who] of origin) travel-log
          
          if watched? = 1[
            set color 85 
            set size 1
            inspect car who
             
          ]
          
          ifelse (LTgoal = "ver") ;; if driving to a vertical structure, otherwise default to shelter
          [set path [ver-path] of myself]
          [set path [hor-path] of myself]
          
          set prev-origin origin
          set evacuated? false
          set moving? false
          ifelse (path != 0 and (empty? path) )
          [set goal -1]
          [set goal last path]
          st
        ]
      ]
      
      ;;;;; Pedestrian spawn ;;;;;
      [
        hatch-pedestrians 1
        [
          ;; SET COMMON VARS
          set LTgoal [LTgoal] of myself
          
          set size 1 
          set shape "dot"
          set shape [shape] of myself
          set path []
          set origin myself
          set prev-origin origin
          set evacuated? false
          set moving? false
          set watched? [watched?] of myself
          if shape = "star"[
            set color 85
            set size 1
            inspect pedestrian who
          ]
          
          ;; array that tracks path of agent through simulation
          set travel-log []
          set travel-log lput ([who] of origin) travel-log
          
          ;; SET PATH BASED ON LTgoals
          
          ;; shelter
          if LTgoal = "hor"
          [
            set color yellow
            if shape = "star"[
              set color 85
            ]
            set path [hor-path] of myself
          ]
          
          ;; high-rise or leave town
          if LTgoal = "ver"
          [
            set color violet
            if shape = "star"[
              set color 85
            ]
            set path [ver-path] of myself
          ]
          
          ;; follow others
          if LTgoal = "flock"
          [
            set color pink
            if shape = "star"[
              set color 85
            ]
            set path [ver-path] of myself ;; this is just to prevent bugs flockers will use flocking logic
          ]
          
          
          ;; path check for non-familiars          
          ifelse (path = 0) or (empty? path)
          [set goal -1]
          [set goal last path]
                    
          ;; imperfect knowledge pathing
          if LTgoal = "familiar"
          [
            set color orange
            if shape = "star"[
              set color 85
            ]
            set goal -2 ;; familair agents have a different way to detect a goal
            
            let optimal -1
            if (not ([hor-path] of myself = 0) and not empty? [hor-path] of myself)
            [ 
              set optimal first [hor-path] of myself 
            ]                         

            ifelse ( optimal != -1 and 80 + confidence / 5 > random 100 + 1 )
            ;; choose the optimal next step from current intersection to closest shelter
            [
              set path fput optimal path
            ]
            
            ;; equal chance of picking a suboptimal option
            [            
              let suboptimal [familiar-paths] of myself
              ifelse (suboptimal != 0 and length suboptimal > 1)
              [
                set suboptimal remove optimal suboptimal
                set path fput (one-of suboptimal) path  
              ]
              [
                set path fput optimal path ;; default to optimum if only choice
              ]                                                
            ]
          ]
          
          st
        ]
      ]
    ]
    die
  ]

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; ASK PEDESTRIANS ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  let allset (turtle-set pedestrians cars)
  
      ;; PEDESTRIAN SAFETY CHECK ;;
  ask allset with [evacuated? = false]
  [
    if [who] of origin = goal or goal = -1 or [gate?] of origin = true ;;!!
    [
      set color green
      set moving? 0
      set evacuated? true
      set ev-times lput ( ticks / 60 ) ev-times
    ]
    if [depth] of patch-here >= Hc [
        set color red
        set moving? 0
        set evacuated? true
    ]
  ]

  ;;;;; INTERSECTION DECISIONS ;;;;; 


  

  ;; standard pathfinding
ask allset with [moving? = false and LTgoal != "flock" and path != [] and evacuated? = false]
  [
    
    let dest item 0 path
    set path remove dest path
    
    set travel-log lput dest travel-log 
    
    set destination intersection dest
    set heading towards destination
    ;face destination
    set moving? true
    ;; flocking behavior not handled by roads so not allowed in crowd check
    if LTgoal != "flock" [
      ask road ([who] of destination) ([who] of origin)
      [
        set crowd crowd + 1
      ]
     ]
    
  ]

  ;; flocking pathfinding.
  ask allset with [moving? = false and LTgoal = "flock"][

    find-flockmates
    find-nearest-neighbor
    ifelse nearest-neighbor != Nobody[
      if [destination] of nearest-neighbor != 0[
       set destination [destination] of nearest-neighbor
      
    ]
    ][
    
    let interset min-one-of intersections [distance myself]
    let gopath [familiar-paths] of interset
    let mindest one-of gopath
;    ifelse (length gopath) = 1[
;      
      set destination intersection mindest
;    ][
;    while [member? mindest travel-log][
;      set gopath remove mindest gopath
;      set mindest one-of gopath
;      set destination intersection mindest
;    ]]
;;    if member? destination travel-log [
;;      set gopath remove mindest gopath
;;      set mindest one-of gopath
;;      set destination intersection mindest
;;    ]
;    
    
    ]
    
;    ifelse destination != 0[ 
;      set travel-log lput destination travel-log
;    face destination
;       set moving? true 
;    ][
;    set destination intersection item 0 path
;    set path remove destination path
    
    set travel-log lput destination travel-log
    face destination
       set moving? true 
    
    
  ]
  
  ;;;;; MOVING ;;;;; 
  
  ask allset with [moving? = true and evacuated? = false]
  [
    ifelse (speed > (distance destination)) 
    [set fd-speed distance destination]
    [set fd-speed speed]
    
    fd fd-speed
    
    if car? = 1[
     if (speed <= 0.001) 
    [set speed 0.005]
    if (distance destination < 1 ) 
    [
      if (speed > 0.005)
      [set speed speed / 1.15]
    ]
    if (distance origin < 1 ) 
    [
      if (speed < 0.1)
      [set speed speed * 1.2]
    ]
     
     ;;slowdown for cars
     if (speed <= 0.001) 
     [set speed 0.005]
     let cars-ahead one-of cars-on patch-ahead 0.7
     ifelse (cars-ahead != nobody) 
     [
       if (speed > 0.005)
       [set speed speed / 1.15]
     ]
     [
      if (speed < 0.1)
      [set speed speed * 1.2] 
     ] 
    ]
  
    if (distance destination < 0.005 )
    [
      set moving? false
;      ask road ([who] of destination) ([who] of origin)[
;        set crowd crowd - 1
;      ]
      set prev-origin origin
      set origin destination
      
      ;; check if at shelter
      if [who] of origin = goal or goal = -1 or [gate?] of origin = true
      [
        set color green
        set moving? 0
        set evacuated? true
        set ev-times lput ( ticks / 60 ) ev-times
      ]
      
      ;; check if in water
      if [depth] of patch-here >= Hc and evacuated? = false 
      [
        set color red
        set moving? 0
        set evacuated? true
      ]
      
      ; FAMILIAR goal pick next path
      if LTgoal = "familiar" 
      [  
        ifelse ([gate?] of destination = true)
        [
         set goal -1 
        ]
        [
          let closeEnough min-one-of intersections with [gate? = true] [distance myself]
          
          ;; check for nearby shelter and path to it directly
          ifelse distance closeEnough < 600 * 0.0059043               ;; arbitrary distance of 600 feet before pathing directly
          [ set path [hor-path] of destination ]                                
          
          ;; if not close enough to a shelter
          [
            let optimal -1
            if (not ([hor-path] of destination = 0) and not empty? [hor-path] of destination)
            [ 
              set optimal first [hor-path] of destination 
            ]                         

            ifelse ( optimal != -1 and 80 + confidence / 5 > random 100 + 1 )
            
            ;; choose the optimal next step from current intersection to closest shelter
            [              
              set path fput optimal path
            ]
            
            ;; equal chance of picking a suboptimal option
            [            
              let suboptimal [familiar-paths] of destination
              ifelse (suboptimal != 0 and length suboptimal > 1)
              [
                set suboptimal remove optimal suboptimal
                set path fput (one-of suboptimal) path  
              ]
              [
                set path fput optimal path ;; default to optimum if only choice
              ]                                                
            ]            
          ]                  
        ]
      ]
    ]    
  ]
  
  ask turtles with [watched? = 1][
    let close-turtles other turtles in-radius 1 with [watched? !=  1]
   ask close-turtles[
    hide-turtle
     
   ] 
;   ask turtles with [not member? self close-turtles][
;   show-turtle
;   ]
  ]

 ;; halt dead or safe pedestrians
  ask allset with [color = green or color = red]
  [stop]
  
  
   ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; CAR A* LOGIC ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
   

;   ask cars with [evacuated? = false]
;  [
;    if [who] of origin = goal or goal = -1 or [gate?] of origin = true ;;!!
;    [
;      set color green
;      set moving? 0
;      set evacuated? true
;      set ev-times lput ( ticks / 60 ) ev-times
;    ]
;    if [depth] of patch-here >= Hc [
;      set color red
;      set moving? 0
;      set evacuated? true
;    ]
;  ]
;   
;  ask cars with [( moving? = false) and path != []]
;  [
;    let dest item 0 path
;    set path remove dest path
;    set destination intersection dest
;    set heading towards destination
;    set moving? true
;    ask road ([who] of destination) ([who] of origin)
;    [
;      set crowd crowd + 5
;    ]
;    
;  ]
;
;
;  ask cars with [moving? = true]
;  [
;    ifelse speed > distance destination 
;    [set fd-speed distance destination]
;    [set fd-speed speed]
;    
;    fd fd-speed
;   
;    ;;slowdown for intersections
;    
;    if (speed <= 0.001) 
;    [set speed 0.005]
;    if (distance destination < 1 ) 
;    [
;      if (speed > 0.005)
;      [set speed speed / 1.15]
;    ]
;    if (distance origin < 1 ) 
;    [
;      if (speed < 0.1)
;      [set speed speed * 1.2]
;    ]
;     
;     ;;slowdown for cars
;     if (speed <= 0.001) 
;     [set speed 0.005]
;     let cars-ahead one-of cars-on patch-ahead 0.7
;     ifelse (cars-ahead != nobody) 
;     [
;       if (speed > 0.005)
;       [set speed speed / 1.15]
;     ]
;     [
;      if (speed < 0.1)
;      [set speed speed * 1.2] 
;     ]
;     
;    if (distance destination < 0.0005 )
;    [
;      set moving? false
;      ask road ([who] of destination) ([who] of origin)
;      [set crowd crowd - 5]
;      
;      set prev-origin origin
;      set origin destination
;      if [who] of origin = goal or goal = -1
;      [
;        set color green
;        set moving? 0
;        set evacuated? true
;        set ev-times lput ( ticks / 60 ) ev-times
;      ]
;      if [depth] of patch-here >= Hc and evacuated? = false 
;      [
;        set color red
;        set moving? 0
;        set evacuated? true
;      ]
;    ]
;  ]

 
  
  
  tick
end
@#$#@#$#@
GRAPHICS-WINDOW
347
10
1095
779
50
50
7.31
1
10
1
1
1
0
0
0
1
-50
50
-50
50
1
1
1
ticks
30.0

PLOT
1103
289
1407
457
Number of Evacuated
Min
#
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Evac" 1.0 0 -10899396 true "" "plotxy (ticks / 60) (count pedestrians with [color = green])"

SWITCH
9
218
162
251
immediate-evacuation
immediate-evacuation
0
1
-1000

BUTTON
157
10
335
115
GO
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

TEXTBOX
1202
666
1356
694
Residents' Decision \nMaking Probabalisties(%)
11
0.0
1

INPUTBOX
1262
710
1338
770
R1-HorEvac-Foot
50
1
0
Number

INPUTBOX
1176
710
1253
770
R3-VerEvac-Foot
50
1
0
Number

MONITOR
1102
15
1184
60
Time (min)
ticks / 60
1
1
11

INPUTBOX
1156
508
1221
568
Hc
0.5
1
0
Number

PLOT
1103
126
1407
287
Number of Casualties
Min
#
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Dead" 1.0 0 -2674135 true "" "plotxy (ticks / 60) (count turtles with [color = red])"

BUTTON
1
10
152
43
READ (1/2)
pre-read
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

INPUTBOX
1156
598
1206
658
Rtau1
5
1
0
Number

INPUTBOX
1206
598
1256
658
Rsig1
1.5
1
0
Number

INPUTBOX
1255
598
1305
658
Rtau3
5
1
0
Number

INPUTBOX
1304
598
1354
658
Rsig3
1.5
1
0
Number

TEXTBOX
1171
572
1360
600
Evacuation Decision Making Times:
11
0.0
1

INPUTBOX
1220
508
1290
568
Ped-Speed
3
1
0
Number

INPUTBOX
1289
508
1355
568
Ped-Sigma
0.65
1
0
Number

MONITOR
1103
74
1185
119
Evacuated
count turtles with [ color = green ]
17
1
11

MONITOR
1215
15
1292
60
Casualty
count turtles with [ color = red ]
17
1
11

MONITOR
1215
72
1293
117
Mortality (%)
count turtles with [color = red] / (count residents + count pedestrians + count cars) * 100
2
1
11

CHOOSER
9
136
161
181
tsunami-case
tsunami-case
"500yrs" "1000yrs" "2500yrs"
2

BUTTON
1
82
151
115
Read (2/2)
read-all\nroutes\nfinish-routes
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
1
46
151
79
Place Verticals (optional)
pick-verticals
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
1327
15
1406
60
Vertical Cap
count turtles with [color = green and distance min-one-of intersections with [gate? and gate-type = \"Ver\"][distance myself] < 0.01]
17
1
11

BUTTON
11
251
162
284
Reset Vals
setup-init-val
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

TEXTBOX
8
17
26
35
1
12
0.0
1

TEXTBOX
9
56
24
74
2
12
0.0
1

TEXTBOX
9
90
24
108
3
12
0.0
1

TEXTBOX
1163
469
1219
497
Critical\nHeight (m)
11
0.0
1

TEXTBOX
1255
468
1335
496
Pedestrian Vars\n        (feet)
11
0.0
1

TEXTBOX
221
126
302
146
Demographics
11
0.0
1

SLIDER
181
150
339
183
Tourist-Population
Tourist-Population
0
1
0.18
0.01
1
%
HORIZONTAL

SLIDER
181
184
339
217
Elderly-Population
Elderly-Population
0
1
0.2
0.01
1
%
HORIZONTAL

SLIDER
181
217
338
250
Children-Population
Children-Population
0
1
0.2
0.01
1
%
HORIZONTAL

SLIDER
181
250
338
283
car-population
car-population
0
1
0.21
.01
1
%
HORIZONTAL

SWITCH
10
183
161
216
RoadColor
RoadColor
1
1
-1000

TEXTBOX
93
322
243
342
Would you escape?
16
0.0
1

CHOOSER
5
379
168
424
choose-age
choose-age
"Child" "Adult" "Elderly"
1

SWITCH
7
433
169
466
choose-tourist
choose-tourist
1
1
-1000

SWITCH
8
476
170
509
choose-car
choose-car
0
1
-1000

SLIDER
8
522
171
555
choose-confidence
choose-confidence
0
10
6
1
1
NIL
HORIZONTAL

TEXTBOX
184
391
334
409
How old are you?
11
0.0
1

TEXTBOX
182
443
332
461
Do you live in Seaside?
11
0.0
1

TEXTBOX
183
484
333
502
Do you take your car or run?
11
0.0
1

TEXTBOX
182
524
332
552
On scale 0-10, how well do you know Seaside?
11
0.0
1

SWITCH
7
574
171
607
choose-flock
choose-flock
1
1
-1000

TEXTBOX
183
577
333
605
Make your own escape or follow crowd?
11
0.0
1

BUTTON
25
641
292
747
Place-Agent
place-agent
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

@#$#@#$#@
## WHAT IS IT?



## HOW IT WORKS


## HOW TO USE IT



## EXTENDING THE MODEL


## NETLOGO FEATURES



## RELATED MODELS


## CREDITS AND REFERENCES
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

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270

@#$#@#$#@
NetLogo 5.1.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="" repetitions="10" runMetricsEveryStep="false">
    <setup>Reset</setup>
    <go>go</go>
    <metric>N_000</metric>
    <metric>N_001</metric>
    <metric>N_010</metric>
    <metric>N_011</metric>
    <metric>N_020</metric>
    <metric>N_021</metric>
    <metric>N_030</metric>
    <metric>N_031</metric>
    <metric>N_100</metric>
    <metric>N_101</metric>
    <metric>N_110</metric>
    <metric>N_111</metric>
    <metric>N_120</metric>
    <metric>N_121</metric>
    <metric>N_130</metric>
    <metric>N_131</metric>
    <enumeratedValueSet variable="Alternative-Plan-Mode">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="acceleration">
      <value value="0.0099"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="deceleration">
      <value value="0.0010"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="immediate-evacuation">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="data collection" repetitions="10" runMetricsEveryStep="false">
    <setup>pre-read
read-all
routes
finish-routes
init-random
reset-ticks</setup>
    <go>reset-ticks
go</go>
    <final>create-file
export-data</final>
    <enumeratedValueSet variable="tsunami-case">
      <value value="&quot;500yrs&quot;"/>
      <value value="&quot;1500yrs&quot;"/>
      <value value="&quot;2500yrs&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment" repetitions="3" runMetricsEveryStep="false">
    <setup>pre-read
read-all
routes
finish-routes
init-random
reset-ticks</setup>
    <go>go</go>
    <final>create-file
export-data
reset-ticks</final>
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
