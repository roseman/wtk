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


    # Button widgets
    snit::type button {
        _textvarwidget
        option -command
        method _createjs {} {return "wtk.createButton('[$self id]','[$self cget -text]');"}
        method _textchangejs {txt} {return "[$self jqobj].html('$txt');"}
        method _event {which} {if {$which eq "pressed"} {uplevel #0 $options(-command)}}
    }

    # Label widgets
    snit::type label {
        _textvarwidget
        method _createjs {} {return "wtk.createLabel('[$self id]','[$self cget -text]');"}
        method _textchangejs {txt} {return "[$self jqobj].html('$txt');"}
    }

    # Checkbutton
    snit::type checkbutton {
        _textvarwidget
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

    # Entry widgets
    snit::type entry {
        _textvarwidget
        option -width -configuremethod _widthchanged
        method _createjs {} {set r "wtk.createEntry('[$self id]','[$self cget -text]');"; if {$options(-width)!=""} {append r "[$self jsobj].size=$options(-width);"};return $r}
        method _textchangejs {txt} {return "[$self jqobj].val('$txt');"}
        method _event {which args} {if {$which eq "value"} {$self _textchanged -text $args 1}}
        method _widthchanged {opt val} {set options($opt) $val; if {[$self _created?]} {wtk::toclient "[$self jsobj].size=$val;"}}
    }
    

    # Frame
    snit::type frame {
        _stdwidget
        option -padding
        method _createjs {} {return "wtk.createFrame('[$self id]');"}    
    }
}