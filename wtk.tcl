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
        method jsobj {} {return "\$('#[$self id]')"}
        
        # text variable handling; only relevant if the main types delegate these options to us
        option -text -configuremethod _textchanged
        option -textvariable
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
    }
    
    proc getwidget {id} {return $wtk::wobj($id)}
    
    
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
        method _textchangejs {txt} {return "[$self jsobj].html('$txt');"}
        method _event {which} {if {$which eq "pressed"} {uplevel #0 $options(-command)}}
    }
    
    # Label widgets
    snit::type label {
        _textvarwidget
        method _createjs {} {return "wtk.createLabel('[$self id]','[$self cget -text]');"}
        method _textchangejs {txt} {return "[$self jsobj].html('$txt');"}
    }
    
    # Entry widgets
    snit::type entry {
        _textvarwidget
        method _createjs {} {return "wtk.createEntry('[$self id]','[$self cget -text]');"}
        method _textchangejs {txt} {return "[$self jsobj].val('$txt');"}
        method _event {which args} {if {$which eq "value"} {$self _textchanged -text $args 1}}
    }
    
    # Place a slave inside its master.  Right now this doesn't process any actual grid options.
    proc grid {w args} {
        variable widgets
        set w [namespace tail $w]
        set parent [join [lrange [split $w .] 0 end-1] .]
        if {$parent eq ""} {set parent "."}
        if {![info exists widgets($parent)]} {error "no parent widget found"}
        if {![$w _created?]} {$w _create}
        wtk::toclient "wtk.griditup('[$parent id]', '[$w id]');"
    }
    
}

