# This code is loaded into each application instance interpreter.  It maintains state
# for each widget, and then actually creates and manipulates widgets on the client side 
# by sending Javascript commands.  It also receives callbacks from the client side which
# are interpreted and used to update internal widget state here, which often triggers
# callbacks or other event bindings.
#
# Communication with the client is solely via the "fromclient" and "toclient" routines
# (the latter of which is setup in the wtk::init call).


package require snit

namespace eval ::wtk {
    variable widgets 
    variable wobj
    variable _nextid -1
    variable _sender ""

    # Initialization and communication
    proc init {sender} {
        set wtk::_sender $sender
        wtk::Widget "." ""
        return ""
    }
    
    # for debugging
    proc _reset {} {
        variable wobj; variable widgets; variable _nextid; variable _sender
        foreach {id w} [array get wobj] {$w destroy}
        unset -nocomplain widgets
        unset -nocomplain wobj
        set _nextid -1
        GridState _reset
        init $_sender
        return ""
    }

    proc toclient {cmd} {uplevel #0 $wtk::_sender [list $cmd]}
   
    proc fromclient {cmd} {if {[lindex $cmd 0]=="EVENT"} {[getwidget [lindex $cmd 1]] _event {*}[lrange $cmd 2 end]}}


    # 'Generic' widget object, which handles routines common to all widgets like
    # assigning it an id, keeping track of whether or not its been created, etc.
    # Purely for convenience, we also include some code here that manages widgets
    # that use -text or -textvariable, though not every widget will do so.
    
    snit::type Widget {
        variable id; variable created; variable wobj
        constructor {_wobj} {
            if {$_wobj==""} {set _wobj $self}; # used for root window only
            set wobj $_wobj
            set id obj[incr wtk::_nextid]
            dict set wtk::widgets([namespace tail $wobj]) id $id
            set wtk::wobj($id) [namespace tail $wobj]
            set created 0
        }
        method _created? {} {return $created}
        method _create {} {
            set js [$wobj _createjs]
            wtk::toclient $js
            set created 1
            return ""
        }
        method id {} {return $id}
        method jqobj {} {return "\$('#[$self id]')"}
        method jsobj {} {return "wtk.widgets\['[$self id]'\]"}
        
        # text variable handling; only relevant if the main types delegate these options to us
        option -text -configuremethod _textchanged
        option -textvariable -configuremethod _textvarset
        method _textchanged {opt txt {fromwidget 0}} {
            set options($opt) $txt; 
            if {$created && !$fromwidget} {wtk::toclient [$wobj _textchangejs $txt]}
            if {$options(-textvariable)!=""} {uplevel #0 set $options(-textvariable) [list $txt]}
        }   
        method _textvariablechanged {args} {
            if {$options(-text) ne [uplevel #0 set $options(-textvariable)]} {
                $self _textchanged -text [uplevel #0 set $options(-textvariable)]
            }
        }
        method _setuptextvar {} {
            if {$options(-textvariable)!=""} {
                if {![uplevel #0 info exists $options(-textvariable)]} {
                    uplevel #0 set $options(-textvariable) [list $options(-text)]
                } else {
                    set options(-text) [uplevel #0 set $options(-textvariable)]
                }
                uplevel #0 trace add variable $options(-textvariable) write [list [list $self _textvariablechanged]]
            }
        }
        method _textvarset {opt var} {
            set options($opt) $var
            $self _setuptextvar
        }
    }
    
    proc getwidget {id} {return $wtk::wobj($id)}
    
    proc wm {args} {# placeholder}
    proc winfo {args} {# placeholder}
    proc focus {args} {# placeholder}
    proc bind {args} {# placeholder}
    
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
    
    # Macro that can be used to simplify the definition of any widget
    snit::macro _stdwidget {} {
        component W; delegate method * to W
        constructor {args} {install W using Widget %AUTO% $self; $self configurelist $args}
    }
    
    # Macro that can be used to simplify the creation of widgets using -text and -textvariable
    snit::macro _textvarwidget {} {
        component W; delegate method * to W; delegate option -textvariable to W; delegate option -text to W 
        constructor {args} {install W using Widget %AUTO% $self; $self configurelist $args; $W _setuptextvar}
    }

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
    
    # Place a slave inside its master.  Right now this doesn't process any actual grid options.
    proc grid {w args} {
        variable widgets
        switch -exact -- $w {
            "columnconfigure" {}        
            "rowconfigure" {}
            default {
                set w [namespace tail $w]
                set parent [join [lrange [split $w .] 0 end-1] .]
                if {$parent eq ""} {set parent "."}
                if {![info exists widgets($parent)]} {error "no parent widget found"}
                if {![$w _created?]} {$w _create}
                if {[dict keys $args -column]==""} {dict set args -column 0}
                if {[dict keys $args -row]==""} {dict set args -row 0}
                ###wtk::toclient "wtk.griditup('[$parent id]','[$w id]');"     
                [GridState for $parent] addSlave $w {*}$args
                return ""   
            }
        }
    }
    
    # internal state kept for each master
    snit::type GridState {
        typevariable states
        typemethod for {w} {
            if {![info exists states($w)]} {set states($w) [GridState %AUTO% $w]}
            return $states($w)
        }
        typemethod _reset {} {foreach i [$type info instances] {$i destroy}; unset states}
        
        variable rows {}
        variable columns {}
        variable slaves ; # array
        variable tabledata {}
        variable master
        variable id
        constructor {w} {set master $w; set id [string map "obj grid" [$w id]] }
        method jqobj {} {return "\$('#$id')"}
        method jsobj {} {return "\$('#$id')\[0\]"}
        method _debug {} {return [list master $master rows $rows columns $columns slaves [array get slaves] tabledata $tabledata]}
        method addSlave {w args} {
            # TODO - verify slave is a descendant of us, handle -in, etc.
            # NOTE: caller ensures we have a column and row
            if {[dict keys $args -column] eq "" || [dict keys $args -row] eq ""} {error "need to supply -column and -row"}
            set slaves($w) $args
            set colnum [dict get $args -column]; set rownum [dict get $args -row]
            #puts "\n        BEFORE: $tabledata  -> col=$colnum row=$rownum w=$w"
            if {$colnum ni $columns} {$self _insertColumn $colnum}
            if {$rownum ni $rows} {$self _insertRow $rownum}
            
            set colidx [lsearch $columns $colnum]; set rowidx [lsearch $rows $rownum]
            set row [lindex $tabledata $rowidx]
            #puts "             row=$row, colidx=$colidx"
            set tabledata [lreplace $tabledata $rowidx $rowidx [lreplace $row $colidx $colidx [lreplace [lindex $row $colidx] 2 2 $w]]]
            #puts "        AFTER: $tabledata\n"
            wtk::toclient "[$self jsobj].rows\[$rowidx\].cells\[$colidx\].appendChild(wtk.widgets\['[$w id]'\]);"
            return ""
        }
        method _insertColumn {colnum} {
            set columns [lsort -integer [concat $columns $colnum]]; set colidx [lsearch $columns $colnum]
            set new ""; set rowidx 0
            foreach i $tabledata {
                lappend new [linsert $i $colidx [list $colidx 1 blank]]
                wtk::toclient "[$self jsobj].rows\[$rowidx\].insertCell($colidx);"
                incr rowidx
            }
            set tabledata $new
        }
        method _insertRow {rownum} {
            if {$tabledata==""} {wtk::toclient "wtk.newGrid('[$master id]','$id');"}
            set rows [lsort -integer [concat $rows $rownum]]; set rowidx [lsearch $rows $rownum];
            wtk::toclient "[$self jsobj].insertRow($rowidx);"
            set row ""; for {set i 0} {$i<[llength $columns]} {incr i} {
                lappend row [list $i 1 blank]
                wtk::toclient "[$self jsobj].rows\[$rowidx\].insertCell($i);"
            }
            lappend tabledata $row
        }
    }
    
}

