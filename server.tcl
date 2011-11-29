source httpd.tcl
source wtk.tcl

proc handler {op sock} {
    if {$op=="handle"} {
        httpd loadrequest $sock data query
        if {![info exists data(url)]} {return}
        regsub {(^http://[^/]+)?} $data(url) {} url
        puts stderr "URL: $url"
        switch -exact -- $url {
            "/"             {httpd return $sock [filecontents index.html]}
            "/wtk.js"       {httpd return $sock [filecontents wtk.js] -mimetype "text/javascript"}
            "/poll.html"    {if !{[sendany $sock]} {error "pending"}}
            "/wtkcb.html"   {wtk::handle $query(cmd)}
            default         {puts stderr "BAD URL $url"; httpd returnerror 404}
        }
    }
}


proc filecontents {fn} {set f [open $fn]; set d [read $f]; close $f; return $d}



proc sendto {cmd} {
    puts stderr "SENDTO: $cmd"
    append ::pendingcmds "$cmd"
}
set ::pendingcmds ""
proc sendany {sock} {
    if {$::pendingcmds!=""} {
        httpd return $sock $::pendingcmds -mimetype "text/javascript"
        set ::pendingcmds ""
        return 1
    } else {
        after 100 sendany $sock
        return 0
    }
}


httpd listen 9001 handler


wtk::init sendto

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


vwait forever


### http://www.williammalone.com/articles/create-html5-canvas-javascript-drawing-app/





# simple freehand drawing program
# root window
set w .proxy
# import commands into the root namespace
namespace import wtk::*
# create buttons at the top for choosing
grid [button $w.black –text Black -command “set color black”] –column 0 –row 0
grid [button $w.blue –text Blue -command “set color blue”] –column 1 –row 0
grid [button $w.red –text Red -command “set color red”] –column 2 –row 0
set color black
# canvas for drawing
grid [canvas $w.c –background white] –column 0 –columnspan 3 –row 1 -sticky nwes
bind $w.c <1> “set x %x; set y %y”
bind $w.c <B1-Motion> {
   $w.c create line $x $y %x %y –fill $color
   set x %x; set y %y
}



##############################
package require Tk

wm title . "Feet to Meters"
grid [ttk::frame .c -padding "3 3 12 12"] -column 0 -row 0 -sticky nwes
grid columnconfigure . 0 -weight 1; grid rowconfigure . 0 -weight 1

grid [ttk::entry .c.feet -width 7 -textvariable feet] -column 2 -row 1 -sticky we
grid [ttk::label .c.meters -textvariable meters] -column 2 -row 2 -sticky we
grid [ttk::button .c.calc -text "Calculate" -command calculate] -column 3 -row 3 -sticky w

grid [ttk::label .c.flbl -text "feet"] -column 3 -row 1 -sticky w
grid [ttk::label .c.islbl -text "is equivalent to"] -column 1 -row 2 -sticky e
grid [ttk::label .c.mlbl -text "meters"] -column 3 -row 2 -sticky w

foreach w [winfo children .c] {grid configure $w -padx 5 -pady 5}
focus .c.feet
bind . <Return> {calculate}

proc calculate {} {  
   if {[catch {
       set ::meters [expr {round($::feet*0.3048*10000.0)/10000.0}]
   }]!=0} {
       set ::meters ""
   }
}


