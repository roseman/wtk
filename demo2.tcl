
wtk::wm title . "Feet to Meters"
wtk::grid [wtk::frame .c -padding "3 3 12 12"] -column 0 -row 0 -sticky nwes
wtk::grid columnconfigure . 0 -weight 1; wtk::grid rowconfigure . 0 -weight 1

wtk::grid [wtk::entry .c.feet -width 7 -textvariable feet] -column 2 -row 1 -sticky we
#wtk::grid [wtk::entry .c.feet -textvariable feet] -column 2 -row 1 -sticky we
#.c.feet configure -width 7
wtk::grid [wtk::label .c.meters -textvariable meters] -column 2 -row 2 -sticky we
wtk::grid [wtk::button .c.calc -text "Calculate" -command calculate] -column 3 -row 3 -sticky w

wtk::grid [wtk::label .c.flbl -text "feet"] -column 3 -row 1 -sticky w
wtk::grid [wtk::label .c.islbl -text "is equivalent to"] -column 1 -row 2 -sticky e
wtk::grid [wtk::label .c.mlbl -text "meters"] -column 3 -row 2 -sticky w

foreach w [wtk::winfo children .c] {wtk::grid configure $w -padx 5 -pady 5}
wtk::focus .c.feet
wtk::bind . <Return> {calculate}

proc calculate {} {  
   if {[catch {
       set ::meters [expr {round($::feet*0.3048*10000.0)/10000.0}]
   }]!=0} {
       set ::meters ""
   }
}


