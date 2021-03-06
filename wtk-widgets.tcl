namespace eval ::wtk {

    # Stuff for defining different widget types here
    #
    # Note that all widgets are expected to implement the "_createjs" method.  This is called by
    # the generic widget code, and should return a Javascript command that can be used to create
    # the widget on the web side of things (i.e. calls routines in wtk.js).
    #
    # Widgets that support -text and -textvariable are expected to implement the "_textchangejs"
    # method, which is called by the text handling pieces of the generic widget code, and should
    # return a Javascript command that will change the text of the widget on the web side to match
    # the current internal state of the widget here.
    #   
    # Widgets that receive events from the Javascript side are expected to implement the "_event"
    # method, which is passed the widget-specific type of event and any parameters.


    # Frame
    snit::type frame {
        _wtkwidget
        option -padding
        method _createjs {} {return "wtk.createFrame('[$self id]');"}    
    }


    # Entry widgets
    snit::type entry {
        _wtkwidget -usetextvar
        _wtkoption -width "" {$JS.size=$V;}
        method _createjs {} {return "wtk.createEntry('[$self id]','[$self cget -text]');"}
        method _textchangejs {txt} {return "[$self jqobj].val('$txt');"}
        method _event {which args} {if {$which eq "value"} {$self _textchanged -text $args 1}}
    }


    # Button widgets
    snit::type button {
        _wtkwidget -usetextvar
        option -command
        method _createjs {} {return "wtk.createButton('[$self id]','[$self cget -text]');"}
        method _textchangejs {txt} {return "[$self jqobj].html('$txt');"}
        method _event {which} {if {$which eq "pressed"} {uplevel #0 $options(-command)}}
    }


    # Label widgets
    snit::type label {
       _wtkwidget -usetextvar
        method _createjs {} {return "wtk.createLabel('[$self id]','[$self cget -text]');"}
        method _textchangejs {txt} {return "[$self jqobj].html('$txt');"}
    }


    # Checkbutton
    snit::type checkbutton {
        _wtkwidget -usetextvar
        variable currentvalue 0
        option -command
        option -onvalue -default 1 -configuremethod _onoffchanged
        option -offvalue -default 0 -configuremethod _onoffchanged
        option -variable -configuremethod _varnameset
        
        # TODO : move -variable handling into generic widget base
        method _createjs {} {set r "wtk.createCheckButton('[$self id]','[$self cget -text]');"; if {$currentvalue==$options(-onvalue)} {append r "[$self jsobj].childNodes\[0\].checked=true;"}; return $r}
        method _textchangejs {txt} {return "[$self jqobj].children(':last').html('$txt');"}
        method _event {which} {
            if {$which in "checked unchecked"} {
                if {$which=="checked"} {set val $options(-onvalue)} else {set val $options(-offvalue)}
                $self _changevalue $val 1; uplevel #0 $options(-command)
            }
        }
        method _varnameset {opt var} {set options($opt) $var;
            if {$var!=""} {
                if {![uplevel #0 info exists $var]} {uplevel #0 set $var $currentvalue} else {set currentvalue [uplevel #0 set $var]}
                uplevel #0 trace add variable $var write [list [list $self _varchanged]]
            }
        }
        method _onoffchanged {opt val} {if {$currentvalue==$options($opt)} {set options($opt) $val; $self _changevalue $val} else {set options($opt) $val}}
        method _varchanged {args} {if {$currentvalue ne [uplevel #0 set $options(-variable)]} {$self _changevalue [uplevel #0 set $options(-variable)]}}; # trace callback
        method _changevalue {newval {fromwidget 0}} {
            if {[$self _created?] && !$fromwidget} {
                if {$newval eq $options(-onvalue) && $options(-onvalue) ne $currentvalue} {
                    wtk::toclient "[$self jsobj].childNodes\[0\].checked=true;"
                } elseif {$newval ne $options(-onvalue) && $options(-onvalue) eq $currentvalue} {
                    wtk::toclient "[$self jsobj].childNodes\[0\].checked=false;"
                }
            }
            set currentvalue $newval
            if {$options(-variable) ne ""} {uplevel #0 set $options(-variable) [list $newval]}
        }
        
    }
    
    
    # Canvas
    snit::type canvas {
        typevariable itemtypes "line rectangle"
        typevariable opts.line {-fill strokeStyle -width lineWidth}
        typevariable opts.rectangle {-fill fillStyle -width lineWidth -outline strokeStyle}
        _wtkwidget
        _wtkoption -width 100 {$JS.width=$V;$JS.style.width='${V}px';}
        _wtkoption -height 100 {$JS.height=$V;$JS.style.height='${V}px';}
        _wtkoption -background "#ffffff" {$JS.style.background='$V';}

        variable mousedown 0
        variable nextid 1
        variable items
        method _createjs {} {return "wtk.createCanvas('[$self id]');"}
        method create {itemtype args} {
            if {$itemtype ni $itemtypes} {error "bad item type"}
            lassign [_parseCoordsAndOptions $args [set opts.$itemtype]] coords opts
            set cid $nextid; incr nextid
            set items($cid) [list type $itemtype coords $coords]
            wtk::toclient "wtk.objs\['[$self id]'\].createItem($cid,'$itemtype',\[[join $coords ,]\],$opts);"
            return $cid
        }
        method _event {which args} {; # todo - make generic
            if {$which=="mousedown"} {set mousedown 1; set subs [list %x [lindex $args 0] %y [lindex $args 1]]; $W _fireevent "<1>" $subs; if {[lindex $args 3]!=""} {[$self _fireevent [lindex $args 3] "<1>" $subs]}}
            if {$which=="mousemove"} {if {$mousedown} {set ev "<B1-Motion>"} else {set ev "<Motion>"}; $W _fireevent $ev [list %x [lindex $args 0] %y [lindex $args 1]]}
            if {$which=="mouseup"} {set mousedown 0; $W _fireevent "<B1-Release>" [list %x [lindex $args 0] %y [lindex $args 1]]}
        }
        proc _parseCoordsAndOptions {s optmap} {
            set coords ""; set inopts 0; set opts ""
            foreach {x y} [split $s] {
                if {!$inopts && [string is integer $x]} {
                    if {![string is integer $y]} {error "odd number of coordinates"}
                    lappend coords $x $y
                } else {
                    set inopts 1
                    if {![dict exists $optmap $x]} {error "bad option"}
                    lappend opts "[dict get $optmap $x]:\"$y\""
                }
            }
            return [list $coords "\{[join $opts ,]\}"]
        }
        
        variable bindings
        method bind {id ev script} {set bindings(${id},$ev) $script}
        method _fireevent {id ev subs} {if {[info exists bindings(${id},$ev)]} {uplevel #0 [string map $subs $bindings(${id},$ev)]}}
        
        
    }
    
}
