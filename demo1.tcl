
set feet 25
wtk::grid [wtk::button .b -text "My First Button" -command "buttonClicked .b"]
wtk::grid [wtk::button .c -text "My Second Button" -command "buttonClicked .c"]
wtk::grid [wtk::button .d -text "My Third Button" -textvariable btnlabel -command "buttonClicked .d"]
wtk::grid [wtk::label .l1 -text "feet"]
wtk::grid [wtk::label .l2 -text "is equivalent to"]
wtk::grid [wtk::label .l3 -text "meters"]
wtk::grid [wtk::entry .feet -textvariable feet] -column 2 -row 1 -sticky we


proc buttonClicked {w} {
    $w configure -text "Thanks for the click!"; 
    .l1 configure -text [clock format [clock seconds]]
    .l2 configure -text $::feet; puts "FEET=$::feet"
    if {$w==".d"} {set ::feet 1000; set ::btnlabel "VIA TEXTVAR"}
}
