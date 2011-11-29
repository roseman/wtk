# Main application, which runs a webserver and is responsible for creating new 
# application instances in response to client (web) connections, and acts as an ongoing
# communication middle man between each instance and the clients.
#
# Each instance is associated with a separate Tcl interpreter. Instances are 
# identified using a "sessionid".  The global array "sessions" holds information
# on each session, including the interpreter, messages queued up to send to the
# client, etc.
#
# For this demo program, communication between client and server here is via a very 
# simple two connection AJAX model (one for the client sending messages via /wtkcb.html, 
# and one for the client receiving messages via /wtkpoll.html). Importantly, it
# doesn't matter what the communication mechanism is (this one is simple but very weak),
# and could be replaced by anything, e.g. WebSockets, socket.io, procedure calls
# to another part of the same program, etc.  As far as wtk is concerned, everything
# is hidden behind the "fromclient" and "toclient" API's, whatever their implementation. 


# For demo purposes, include our variation of the minihttpd.tcl, which generates
# callbacks on every received URL.
source httpd.tcl


# webhandler -- Respond to HTTP requests we receive
#
# This is the callback from the webserver saying "please process this URL".
# The webserver expects us to synchronously respond to this request, returning the
# result by calling "httpd return" (or a variety of other similar calls).  If the
# request can't be responded to synchronously, we need to return an error "pending",
# and are responsible for responding to the request at a later point in time

proc webhandler {op sock} {
    if {$op=="handle"} {
        httpd loadrequest $sock data query
        if {![info exists data(url)]} {return}
        regsub {(^http://[^/]+)?} $data(url) {} url
        puts stderr "URL: $url"
        switch -exact -- $url {
            "/"             {httpd return $sock [filecontents index.html]}
            "/demo1.html"   {httpd return $sock [newSession demo1.tcl demo1.html]}
            "/wtk.js"       {httpd return $sock [filecontents wtk.js] -mimetype "text/javascript"}
            "/wtkpoll.html" {if !{[sendany $sock $query(sessionid)]} {error "pending"}}
            "/wtkcb.html"   {fromclient $query(sessionid) $query(cmd)}
            "/src.html"     {httpd return $sock [filecontents $query(f)] -mimetype "text/plain"}
            default         {puts stderr "BAD URL $url"; httpd returnerror 404}
        }
    }
}

proc filecontents {fn} {set f [open $fn]; set d [read $f]; close $f; return $d}; # simple utility 


# newsession -- Create a new application instance
#
# This is called when a client first loads one of our 'application' pages.  We create a new
# application instance (interpreter), load and initialize "wtk" in that interpreter, and then
# load in the Tcl script for the application we're running.  We return a HTML page that will
# load up the client side of wtk and cause the browser to initiate a connection back to the
# server. Notably, this page includes the 'sessionid' we've generated for the application
# instance, which is unique to each client.

proc newSession {script webpage} {
    set sessionid [incr ::sessioncounter] 
    set interp [interp create]
    dict set ::session($sessionid) interp $interp 
    dict set ::session($sessionid) msgq ""
    $interp eval source wtk.tcl
    $interp alias sendto toclient $sessionid
    $interp eval wtk::init sendto
    $interp eval source $script
    return [string map "%%%SESSIONID%%% $sessionid" [filecontents $webpage]]
}


# fromclient -- Receive a message from a web client and route it to the correct app instance
#
# This is called when the client wants to send its application instance a message (via 
# the /wtkcb.html callback in this case), typically an event like a button press. 
# We invoke the 'wtk::fromclient' routine in the instance's interpreter to process it.
proc fromclient {sessionid cmd} {[dict get $::session($sessionid) interp] eval wtk::fromclient [list $cmd]}


# toclient -- Send Javascript commands from an app instance to the web client
#
# This is called when the application instance wants to send its client a message,
# in the form of a Javascript command.  The message is queued and the actual 
# sending is taken care of by the next routine. 
proc toclient {sessionid cmd} {dict append ::session($sessionid) msgq $cmd}


# sendany -- Deliver messages to the client queued by 'toclient'
#
# When we receive a client poll (/wtkpoll.html) this routine is called. If we have messages
# queued up for the client we immediately send them; this completes the poll and the client
# will then initiate a new poll. If we don't have any messages queued up at the time we receive 
# the poll request, we periodically call ourselves asynchronously until we do have messages
# to send back.  Note that we don't handle timeouts, disconnects, etc. 
proc sendany {sock sessionid} {
    if {[dict get $::session($sessionid) msgq]!=""} {
        httpd return $sock [dict get $::session($sessionid) msgq] -mimetype "text/javascript"
        dict set ::session($sessionid) msgq ""
        return 1
    } else {
        after 100 sendany $sock $sessionid
        return 0
    }
}


# start everything up
httpd listen 9001 webhandler
puts stdout "Started wtk demo on http://localhost:9001"
vwait forever


