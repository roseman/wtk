set color black
wtk::grid [wtk::canvas .c -width 400 -height 400 -background #eeeeee] -column 0 -row 0
wtk::bind .c <1> "set x %x; set y %y"
wtk::bind .c <B1-Motion> { 
   .c create line $x $y %x %y -fill $color
   set x %x; set y %y
}
wtk::grid [wtk::frame .tools] -column 0 -row 1
wtk::grid [wtk::button .tools.black -text Black -command "set color black"] -column 0 -row 0
wtk::grid [wtk::button .tools.blue -text Blue -command "set color blue"] -column 1 -row 0
wtk::grid [wtk::button .tools.red -text Red -command "set color red"] -column 2 -row 0
