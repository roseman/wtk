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
}