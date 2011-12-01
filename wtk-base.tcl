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
        method _focus {} {toclient "[$self jsobj].focus();"}
    
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

    proc wm {args} {if {[lindex $args 0]=="title" && [lindex $args 1]=="."} {toclient "document.title='[lindex $args 2]';"}; return ""; # placeholder}
    proc winfo {args} {; # placeholder}
    proc focus {w} {$w _focus; return ""}
    proc bind {args} {; # placeholder}

}