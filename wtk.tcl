package require snit
namespace eval ::wtk {
    variable widgets 
    variable wobj
    variable _nextid -1
    variable _sender ""

    proc init {sender} {
        set wtk::_sender $sender
        wtk::Widget "." ""
        return ""
    }

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
            wtk::sendto $js
            set created 1
            return ""
        }
        method id {} {return $id}
        method jsobj {} {return "\$('#[$self id]')"}
        
        # text variable handling; only relevant if the main types delegate these options to us
        option -text -configuremethod _textchanged
        option -textvariable
        method _textchanged {opt txt {fromwidget 0}} {
            set options($opt) $txt; 
            if {$created && !$fromwidget} {wtk::sendto [$wobj _textchangejs $txt]}
            if {$options(-textvariable)!=""} {uplevel #0 set $options(-textvariable) [list $txt]}
        }   
        method _textvariablechanged {args} {
            if {$options(-text) ne [uplevel #0 set $options(-textvariable)]} {
                $self _textchanged -text [uplevel #0 set $options(-textvariable)]
            }
        }
        method _setuptextvar {} {
            if {$options(-textvariable)!=""} {
                if {![uplevel #0 info exists $options(-textvariable)]} {uplevel #0 set $options(-textvariable) [list $options(-text)]} else {set options(-text) [uplevel #0 set $options(-textvariable)]}
                    uplevel #0 trace add variable $options(-textvariable) write [list [list $self _textvariablechanged]]
            }
        }
    }
    
    snit::macro _stdwidget {} {
        component W; delegate method * to W
        constructor {args} {install W using Widget %AUTO% $self; $self configurelist $args}
    }
    snit::macro _textvarwidget {} {
        component W; delegate method * to W; delegate option -textvariable to W; delegate option -text to W 
        constructor {args} {install W using Widget %AUTO% $self; $self configurelist $args; $W _setuptextvar}
    }

    snit::type button {
        _textvarwidget
        option -command
        method _createjs {} {return "wtk.createButton('[$self id]','[$self cget -text]');"}
        method _textchangejs {txt} {return "[$self jsobj].html('$txt');"}
        method _event {which} {if {$which eq "pressed"} {uplevel #0 $options(-command)}}
    }
    
    snit::type label {
        _textvarwidget
        method _createjs {} {return "wtk.createLabel('[$self id]','[$self cget -text]');"}
        method _textchangejs {txt} {return "[$self jsobj].html('$txt');"}
    }
    
    snit::type entry {
        _textvarwidget
        method _createjs {} {return "wtk.createEntry('[$self id]','[$self cget -text]');"}
        method _textchangejs {txt} {return "[$self jsobj].val('$txt');"}
        method _event {which args} {if {$which eq "value"} {$self _textchanged -text $args 1}}
    }
    
    proc grid {w args} {
        variable widgets
        set w [namespace tail $w]
        set parent [join [lrange [split $w .] 0 end-1] .]
        if {$parent eq ""} {set parent "."}
        if {![info exists widgets($parent)]} {error "no parent widget found"}
        if {![$w _created?]} {$w _create}
        wtk::sendto "wtk.griditup('[$parent id]', '[$w id]');"
    }
    
    proc sendto {cmd} {uplevel #0 $wtk::_sender [list $cmd]}
    
    proc getwidget {id} {return $wtk::wobj($id)}

    proc handle {cmd} {
            puts stderr "HANDLE $cmd"
        if {[lindex $cmd 0]=="EVENT"} {[getwidget [lindex $cmd 1]] _event {*}[lrange $cmd 2 end]}
    }
}

