set color black
wtk::grid [wtk::canvas .c -width 400 -height 400 -background #eeeeee] -column 0 -row 0
wtk::bind .c <1> "set x %x; set y %y"
wtk::bind .c <B1-Motion> { 
   .c create line $x $y %x %y -fill $color
   set x %x; set y %y
}

set colors "black blue red green yellow orange brown"
wtk::grid [wtk::canvas .palette -background #cccccc -width 400 -height 30] -column 0 -row 2
set x 10
foreach i $colors {
    .palette bind [.palette create rectangle $x 5 [expr {$x+7}] 25 -fill $i] <1> "set color $i"
    incr x 10
}
