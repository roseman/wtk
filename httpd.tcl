# httpd.tcl --
#
#        Core HTTP server, which dispatches all handling of requests
#        to a synchronous, application specific response handler.  
#
#        This code was derived from Stephen Uhler's simple httpd server,
#        distributed as part of TclHttpd 3.3.  Its copyright is below:
#            Simple Sample httpd/1.[01] server
#            Stephen Uhler (c) 1996-1997 Sun Microsystems
#
# Copyright (c) 2002-2011 Mark Roseman.  All rights reserved.
#
# $Id: httpd.tcl 7535 2011-02-01 18:20:33Z roseman $


# httpd --
#
#       Public interface to HTTP server facilities.
#       The following commands are available:
#
#             httpd listen port handler ?address? ?protocol?
#             httpd stop
#             httpd return sock body ?-mimetype mimetype? ?-static seconds?
#             httpd outputheader sock attr val
#             httpd outputheaders sock
#             httpd returnredirect sock url
#             httpd returnnotmodified sock ?modtime?
#             httpd error sock code params
#             httpd returnfile sock file filename mimetype timestamp ?view? ?flag?
#             httpd loadrequest sock varname ?queryvar?
#             httpd decode str
#             httpd getuploadticket
#             httpd uploadprogress ticket
#             httpd contenttype pathname
#
# Arguments:
#       command         Specifies the particular command to invoke.
#       args		Options required by the command.
# Results:
#       Depends on command.

proc httpd {command args} {
    global Httpd
    set argc [llength $args]
    switch -exact $command {
	"listen" {
	    if {$argc==4} {
		Httpd_Server [lindex $args 0] [lindex $args 1] \
		    [lindex $args 2] [lindex $args 3]
	    } elseif {$argc==3} {
		Httpd_Server [lindex $args 0] [lindex $args 1] \
		    [lindex $args 2]
	    } elseif {$argc==2} {
		Httpd_Server [lindex $args 0] [lindex $args 1]
	    } else {
		error "wrong # args, should be: httpd listen port handler ?address? ?protocol?"
	    }
	}
	"stop" {
	    if {$argc==1 && [lindex $args 0]=="-ssl"} {
		catch {close $Httpd(listenssl); unset Httpd(listenssl)}
		return ""
	    } elseif {$argc==0} {
		catch {close $Httpd(listen); unset Httpd(listen)}
		catch {close $Httpd(listenssl); unset Httpd(listenssl)}
		return ""
	    } else {
		error "wrong # args, should be: httpd stop ?-ssl?"
	    }
	}
	"return" {
	    if {$argc>=2} {
		set sock [lindex $args 0]
		set body [lindex $args 1]
		set mimetype "text/html"
		set static ""
		for {set i 2} {$i<[llength $args]} {incr i} {
		    switch -exact -- [lindex $args $i] {
			"-mimetype" {set mimetype [lindex $args [incr i]]}
			"-static"   {set static [lindex $args [incr i]]}
			default {error "bad option"}
		    }
		}
		HttpdReturn $sock $body $mimetype $static
		return
	    } 
	    error "wrong # args, should be \"httpd return sock body ?-mimetype mimetype? ?-static seconds?\""
	}
	"outputheader" {
	    if {$argc==3} {
		set sock [lindex $args 0]
		upvar #0 Httpd$sock data
		append data(outputheaders) "[lindex $args 1]: [lindex $args 2]\n"
	    } else {
		error "wrong # args, should be: httpd outputheader sock attr val"
	    }
	}
	"outputheaders" {
	    if {$argc==1} {
		set sock [lindex $args 0]
		upvar #0 Httpd$sock data
		if {![info exists data(outputheaders)]} {return ""}
		return $data(outputheaders)
	    } else {
		error "wrong # args, should be: httpd outputheaders sock"
	    }
	}
	"returnredirect" {
	    if {$argc==2} {
		HttpdReturnRedirect [lindex $args 0] [lindex $args 1]
	    } else {
		error "wrong # args, should be: httpd returnredirect sock url"
	    }
	}
	"returnnotmodified" {
	    if {$argc==2} {
		HttpdReturnNotModified [lindex $args 0] [lindex $args 1]
	    } elseif {$argc==1} {
		HttpdReturnNotModified [lindex $args 0]
	    } else {
		error "wrong # args, should be: httpd returnnotmodified sock ?modtime?"
	    }
	}
	"error" {
	    if {$argc==3} {
		HttpdError [lindex $args 0] [lindex $args 1] [lindex $args 2]
	    } else {
		error "wrong # args, should be: httpd error sock code params"
	    }
	}
	"returnfile" {
    	    if {$argc==7} {
    		HttpdReturnFile [lindex $args 0] [lindex $args 1] \
    			[lindex $args 2] [lindex $args 3] [lindex $args 4] [lindex $args 5] [lindex $args 6]
	    } elseif {$argc==6} {
                HttpdReturnFile [lindex $args 0] [lindex $args 1] \
                	[lindex $args 2] [lindex $args 3] [lindex $args 4] [lindex $args 5]
	    } elseif {$argc==5} {
		HttpdReturnFile [lindex $args 0] [lindex $args 1] \
			[lindex $args 2] [lindex $args 3] [lindex $args 4] 
	    } else {
		error "wrong # args, should be httpd returnfile sock file\
			filename mimetype timestamp ?view? ?flag?"
	    }
	}
	"loadrequest" {
	    if {$argc==3} {
		uplevel 1 upvar #0 Httpd[lindex $args 0] [lindex $args 1]

		# parse query or postdata into [lindex $args 2]
		upvar #0 Httpd[lindex $args 0] data
		catch {uplevel 1 unset [lindex $args 2]}
		set query ""; catch {set query $data(query)}
		if {[info exists data(proto)] && $data(proto)=="POST" \
			&& [info exists data(postdata)]} {
		    set query $data(postdata)
		}
                #parray data
                #puts "QUERY is $query"
		foreach {x} [split [string trim $query] &] {
		    # suprisingly, a regexp here is hugely slow - PR#142
		    set posn [string first "=" $x]
		    if {$posn!=-1 && $posn==[string last "=" $x]} {
			set varname [string range $x 0 [expr $posn-1]]
			set val [string range $x [expr $posn+1] end]
			catch {
			    uplevel 1 set [lindex $args 2]($varname) [list [HttpdDecode $val]]
			}
		    }
		}
	    } elseif {$argc==2} {
		uplevel 1 upvar #0 Httpd[lindex $args 0] [lindex $args 1]
	    } else {
		error "wrong # args, should be: httpd loadrequest sock varname ?queryvar?"
	    }
	}
	"decode" {
	    if {$argc==1} {
		return [HttpdDecode [lindex $args 0]]
	    } else {
		error "wrong # args, should be: httpd decode str"
	    }
	}

	"getuploadticket" {
	    if {$argc==0} {
		if {![info exists Httpd(uploadticketcounter)]} {
		    set Httpd(uploadticketcounter) 0
		}
		incr Httpd(uploadticketcounter)
		set tail [string range [expr int(rand()*100000+100000)] end-4 end]
		return "up${Httpd(uploadticketcounter)}${tail}"
	    } else {
		error "wrong # args, should be: httpd getuploadticket"
	    }
	}

	"uploadprogress" {
	    if {$argc==1} {
		set t [lindex $args 0]
		if {[info exists Httpd(uploadticket-sock-$t)]} {
		    set sock $Httpd(uploadticket-sock-$t)
		    upvar #0 Httpd$sock data
		    if {[info exists data(upload-totallength)] \
			  && [info exists data(upload-currentlength)]} {
			return [list $data(upload-currentlength) \
				  $data(upload-totallength)]
		    }
		}
		return ""

	    } else {
		error "wrong # args, should be: httpd uploadprogress ticket"
	    }
	}
	"contenttype" {
	    if {$argc==1} {
	        return [HttpdContentType [lindex $args 0]]
	    } else {
	        error "wrong # args, should be: httpd contenttype pathname"    
	    }
	}
    }
}



# Httpd is a global array containing the global server state
#  port:	The port this server is serving
#  responsehandler: The application-specific handler to deal with http requests
#  listen:	the main listening socket id
#  accepts:	a count of accepted connections so far
#  maxtime:     The max time (msec) allowed to complete an http request (1h)
#  uploadmaxtime: The max time (msec) allowed to complete an upload (12h)
#  maxused:     The max # of requests for a socket
#  uploadticket-sock-<ticket>:  Socket associated with an upload ticket

# HTTP/1.[01] error codes (the ones we use)

array set HttpdErrors {
    204 {No Content}
    400 {Bad Request}
    404 {Not Found}
    408 {Request Timeout}
    411 {Length Required}
    419 {Expectation Failed}
    500 {Internal Server Error}
    503 {Service Unavailable}
    504 {Service Temporarily Unavailable}
    }

array set Httpd {
    bufsize	  32768
    maxtime	  3600000
    uploadmaxtime 43200000
    maxused	  25
}

# Start the server by listening for connections on the desired port.

proc Httpd_Server {port responsehandler {address {}} {protocol {}}} {
    global Httpd

    if {$protocol!="ssl" && $protocol!=""} {
	error "bad protocol"
    }
    if {$protocol=="ssl"} {
	if {[info commands tls::socket]==""} {
	    catch {bgerror "ssl not available (tls::socket)"}
	    error "ssl not available"
	}
	if {![info exists Httpd(tlsinitialized)]} {
	    if {[catch {
		tls::init -request 0 -require 0 -ssl2 1 -ssl3 1 \
		    -tls1 0 -certfile public.pem -keyfile private.pem
	    } errmsg]!=0} {
		catch {bgerror "could not initialize tls: $errmsg"}
		error "could not initialize tls: $errmsg"
	    }
	    set Httpd(tlsinitialized) 1
	}
	catch {close $Httpd(listenssl)};# it might already be running
	array set Httpd [list sslport $port responsehandler $responsehandler]
	array set Httpd [list accepts 0 requests 0 errors 0]
	if {$address!=""} {
	    set Httpd(listenssl) [tls::socket -server [list HttpdAccept https] -myaddr $address $port]
	} else {
	    set Httpd(listenssl) [tls::socket -server [list HttpdAccept https] $port]
	}
	return $Httpd(sslport)
    } else {
	catch {close $Httpd(listen)};# it might already be running
	array set Httpd [list port $port responsehandler $responsehandler]
	array set Httpd [list accepts 0 requests 0 errors 0]
	if {$address!=""} {
	    set Httpd(listen) [socket -server [list HttpdAccept http] -myaddr $address $port]
	} else {
	    set Httpd(listen) [socket -server [list HttpdAccept http] $port]
	}
     ###  HttpdWatchdog $Httpd(listen) 
	return $Httpd(port)
    }
}

proc HttpdWatchdog {sock} {
    global Httpd
    after 5000 "HttpdWatchdog $sock"
    set l "ERROR"; catch {set l $Httpd(listen)}
    set e "ERROR"; catch {set e [eof $sock]}
    set f "ERROR"; catch {set f [fconfigure $sock]}
    ##logger bgerror "[clock format [clock seconds]] sock=$sock l=$l e=$e f=$f"
}

# Accept a new connection from the server and set up a handler
# to read the request from the client.

proc HttpdAccept {protocol sock ipaddr {port {}} {protocol {}}} {
    global Httpd
    upvar #0 Httpd$sock data
    incr Httpd(accepts)
    if {$protocol=="https"} {
	fconfigure $sock -blocking 0
	fileevent $sock readable [list HttpdHandshake $sock]
    } else {
	HttpdReset $sock http $Httpd(maxused) $ipaddr
	Httpd_Log $sock Connect $ipaddr $port
    }
}

# Complete the SSL handshake.
proc HttpdHandshake {sock} {
    global Httpd errorCode
    if {[catch {tls::handshake $sock} complete]} {
	if {[lindex $errorCode 1]=="EAGAIN"} {
	    return
	}
	HttpdSockDone $sock 1
    } elseif {$complete} {
	HttpdReset $sock https $Httpd(maxused)
    }
}

# Initialize or reset the socket state

proc HttpdReset {sock protocol left {ipaddr ""}} {
    global Httpd
    upvar #0 Httpd$sock data

    array set data [list state start linemode 1 version 0 left $left protocol $protocol]
    if {$ipaddr!=""} {set data(ipaddr) $ipaddr}
    set data(cancel) [after $Httpd(maxtime) [list HttpdTimeout $sock]]
    fconfigure $sock -blocking 0 -buffersize $Httpd(bufsize) \
	-translation {auto crlf}
    fileevent $sock readable [list HttpdRead $sock]
}

# Read data from a client request
# 1) read the request line
# 2) read the mime headers
# 3) read the additional data (if post && content-length not satisfied)

proc HttpdRead {sock} {
    global Httpd
    upvar #0 Httpd$sock data

    if {![info exists data(linemode)]} {
	Httpd_Log $sock Error "Missing socket data on read."
	HttpdSockDone $sock 1
	return
    }

    # Use line mode to read the request and the mime headers

    if {$data(linemode)} {
	if {[catch {gets $sock line} readCount]} {
            Httpd_Log $sock Error "error on read: $readCount"
            HttpdSockDone $sock 1
            return
       }
        
	set state [string compare $readCount 0],$data(state)
	switch -glob -- $state {
	    1,start {
		if {[regexp {(HEAD|POST|GET) ([^?]+)\??([^ ]*) HTTP/1.([01])} $line \
			x data(proto) data(url) data(query) data(version)]} {
		    set data(state) mime
		    incr Httpd(requests)
		    Httpd_Log $sock Request $data(left) $line
		} else {
		    HttpdError $sock 400 $line
		}
	    }
	    0,start {
		Httpd_Log $sock Warning "Initial blank line fetching request"
	    }
	    1,mime {
		if {[regexp {([^:]+):[ 	]*(.*)}  $line {} key value]} {
		    set key [string tolower $key]
		    set data(key) $key
		    if {[info exists data(mime,$key)]} {
			append data(mime,$key) ", $value"
		    } else {
			set data(mime,$key) $value
		    }
		} elseif {[regexp {^[ 	]+(.+)} $line {} value] && \
			[info exists data(key)]} {
		    append data(mime,$data($key)) " " $value
		} else {
		    HttpdError $sock 400 $line
		}
	    }
	    0,mime {
	        if {$data(proto) == "POST" && \
	        	[info exists data(mime,content-length)]} {
		    if {[info exists data(mime,content-type)] \
			    && [string match -nocase "multipart/form-data;*" \
			    $data(mime,content-type)]} {
			# switch to upload file mode
			HttpdUploadInit $sock
		    } else {
			set data(linemode) 0
			set data(count) $data(mime,content-length)
			if {$data(version) && [info exists data(mime,expect]} {
			    if {$data(mime,expect) == "100-continue"} {
				puts $sock "100 Continue HTTP/1.1\n"
				flush $sock
			    } else {
				HttpdError $sock 419 $data(mime,expect)
			    }
			}
			fconfigure $sock -translation {binary crlf}
		    }
	        } elseif {$data(proto) != "POST"}  {
		    HttpdRespond $sock
	        } else {
		    HttpdError $sock 411 "Confusing mime headers"
	        }
	    }
	    -1,* {
	    	if {[eof $sock]} {
		    Httpd_Log $sock Error "Broken connection fetching request"
		    HttpdSockDone $sock 1
	    	} else {
	    	    # puts stderr "Partial read, retrying"
	    	}
	    }
	    default {
		HttpdError $sock 404 "Invalid http state: $state,[eof $sock]"
	    }
	}

    # Use counted mode to get the post data

    } elseif {![eof $sock]} {
        append data(postdata) [read $sock $data(count)]
        set data(count) [expr {$data(mime,content-length) - \
        	[string length $data(postdata)]}]
        if {$data(count) == 0} {
	    HttpdRespond $sock
	}
    } else {
	Httpd_Log $sock Error "Broken connection reading POST data"
	HttpdSockDone $sock 1
    }
}

# Done with the socket, either close it, or set up for next fetch
#  sock:  The socket I'm done with
#  close: If true, close the socket, otherwise set up for reuse

proc HttpdSockDone {sock close} {
    Httpd_Log $sock SockDone start $close
    global Httpd
    upvar #0 Httpd$sock data
    if {[info exists data(cancel)] && $data(cancel)!=""} {
	after cancel $data(cancel)
    }
    if {[info exists data(fcopy-fd)]} {
        catch {close $data(fcopy-fd)} msg   
        if {$msg!=""} { 
            Httpd_Log $sock Error "aborting download on $data(fcopy-fd) $msg"
        } 
    }
    
    set left 0; catch {set left [incr data(left) -1]}
    set protocol http; catch {set protocol $data(protocol)}

    unset -nocomplain data
    if {$close} {
	# read any extra data off the socket; otherwise the close
	# can generate a RST rather than a FIN packet; see PR#181
	catch { 
	    fconfigure $sock -blocking 0
	    read $sock
	}; # PR#539
	catch {close $sock}
    } else {
	HttpdReset $sock $protocol $left
    }
    if {[info exists Httpd(responsehandler)]} {
          Httpd_Log $sock SockDone calling response handler
	if {[catch {
	    uplevel #0 $Httpd(responsehandler) done $sock
	} errmsg]!=0} {
	    catch {bgerror "Error doing http done callback on $sock"}
	}
    }
    return ""
}

# A timeout happened

proc HttpdTimeout {sock} {
    global Httpd
    upvar #0 Httpd$sock data
    HttpdError $sock 408
}

# Handle file system queries.  This is a place holder for a more
# generic dispatch mechanism.

proc HttpdRespond {sock} {
    global Httpd HttpdUrlCache

    if {[info exists Httpd(responsehandler)]} {
	upvar #0 Httpd$sock data
	# The 'inprogress' stuff is used to prevent reentry to a handler that
	# is part-way through progress; this is different but related to the
	# 'pending' error condition we also handle below.
	#
	# Some routines (includemgr, centralauth) need to make http::geturl
	# calls which can reenter the event loop.  By doing the inprogress
	# check, we can prevent calling the handler again while the first part
	# of the http::geturl is running.  When that first part completes, but
	# before the async http call as a whole completes, the routine may well
	# generate a "pending" error.
	if {[info exists data(inprogress)] && $data(inprogress)==1} {return}
	if {[info exists data(sendingfile)] && $data(sendingfile)==1} {return}
        Httpd_Log $sock Respond start
	set data(outputheaders) {}
	set data(inprogress) 1
        
#	set url $data(url)
	if {[catch {
#	    set timer [time {
		uplevel #0 $Httpd(responsehandler) handle $sock
#	    }]; puts stderr "-->$timer $url"
	} errmsg]!=0} {
	    Httpd_Log $sock Respond completed error $errmsg
	    unset -nocomplain data(inprogress)
	    if {$errmsg=="pending"} {
		Httpd_Log $sock Respond pending
		# we're waiting on something else to complete, so no sense having our
		# own HttpdRead keep getting called asking us to do something with this
		# socket
		fileevent $sock readable {}
	    } else {
		upvar #0 Httpd$sock data
		set url ""
		if {[info exists data(url)]} {
		    set url $data(url)
		}
		HttpdError $sock 500 "Error processing request"
		catch {bgerror "Error processing handler for $url:\n$::errorInfo"}
	    } 
	} else {
	    Httpd_Log $sock Respond completed ok
            if {[info exists data] && (![info exists data(sendingfile)] || $data(sendingfile)!=1)} {
                Httpd_Log $sock "Return had not been called during request processing; closing connection.  data=[array names data]"
                HttpdSockDone $sock 1
            }
	}
	return
    }
    error "no responsehandler defined"
}

# Callback when file is done being output to client
# in:  The fd for the file being copied
# sock: The client socket
# close: close the socket if true
# bytes: The # of bytes copied
# error:  The error message (if any)

proc HttpdCopyDone {in sock close bytes {error {}}} {
    global Httpd

    upvar #0 Httpd$sock data
    close $in
    unset -nocomplain data(fcopy-fd)
    unset -nocomplain data(sendingfile)
    Httpd_Log $sock Done $bytes bytes
    HttpdSockDone $sock $close
}

# convert the file suffix into a mime type
# add your own types as needed

array set HttpdMimeType {
    {}		text/plain
    .txt	text/plain
    .html	text/html
    .css        text/css
    .js         text/javascript
    .gif	image/gif
    .jpg	image/jpeg
    .png        image/png
    .swf        application/swf
    .ico        image/x-icon
}

proc HttpdContentType {path} {
    global HttpdMimeType

    set type text/html
    catch {set type $HttpdMimeType([file extension $path])}
    return $type
}

# Generic error response.

set HttpdErrorFormat {
    <title>Error: %1$s</title>
    Got the error: <b>%2$s</b><br>
    while trying to obtain <b>%3$s</b>
}

# Respond with an error reply
# sock:  The socket handle to the client
# code:  The httpd error code
# args:  Additional information for error logging

proc HttpdError {sock code args} {
    upvar #0 Httpd$sock data
    global Httpd HttpdErrors HttpdErrorFormat

    append data(url) ""
    set version "1"; if {[info exists data(version)] && $data(version)!=""} {set version $data(version)}
    incr Httpd(errors)
    
    set message [format $HttpdErrorFormat $code $HttpdErrors($code) $data(url)]
    append head "HTTP/1.$version $code $HttpdErrors($code)"  \n
    append head "Date: [HttpdDate [clock seconds]]"  \n
    append head "Connection: close"  \n
    append head "Content-Length: [string length $message]"  \n

    # Because there is an error condition, the socket may be "dead"
    catch {
	fconfigure $sock  -translation crlf
	puts -nonewline $sock $head\n$message
	flush $sock
    } reason
    HttpdSockDone $sock 1
    Httpd_Log $sock Error $code $HttpdErrors($code) $args $reason
}

# Generate a date string in HTTP format.

proc HttpdDate {seconds {gmt ""}} {
    if {$gmt==1} {
	return [clock format $seconds -format {%a, %d %b %Y %T %Z} -gmt 1]
    } else {
	return [clock format $seconds -format {%a, %d %b %Y %T %Z}]
    }
}

# Log an Httpd transaction.
# This should be replaced as needed.

proc Httpd_Log {sock args} {
    catch {
        logger httpd "        httpd $sock $args"
    }
    ##puts stderr "LOG: $sock $args"
}

# Decode url-encoded strings.

proc HttpdCgiMap {data} {
    regsub -all {([][$\\])} $data {\\\1} data
    regsub -all {%([0-9a-fA-F][0-9a-fA-F])} $data  {[format %c 0x\1]} data
    return [subst $data]
}


# from ncgi::encode
for {set i 1} {$i <= 256} {incr i} {
	set c [format %c $i]
	if {![string match \[a-zA-Z0-9\] $c]} {
	    set HttpdMap($c) %[format %.2X $i]
	}
}
# These are handled specially
array set HttpdMap {
	" " +   \n %0D%0A
}
set HttpdCharmap [array get HttpdMap]


proc HttpdCgiEncode {string} {
    return [string map $::HttpdCharmap $string]
}



# HttpdReturn --
#
#       Return a HTML page to a client, and close the connection.
#
# Arguments:
#       sock            The socket to write to.
#       body            HTML body of page.
#       mimetype        If specified, MIME type to use instead of text/html.
#       staticseconds   If specified, this is static content, last modified
#                       at the 'clock seconds' time given by this parameter.
# Results:
#       None.

proc HttpdReturn {sock body {mimetype "text/html"} {staticseconds ""}} {
    puts $sock "HTTP/1.0 200 OK"
    if {$mimetype=="text/html"} {
	puts $sock "Content-Type: text/html; charset=utf-8"
    } else {
	puts $sock "Content-Type: $mimetype"
    }
    puts $sock "Date: [HttpdDate [clock seconds]]"
    puts $sock "Connection: close"
    if {$staticseconds==""} {
	puts $sock "Expires: now"
	puts $sock "Cache-Control: no-cache, must-revalidate"
	puts $sock "Pragma: no-cache"
    } else {
	puts $sock "ETag: \"$staticseconds\""
	puts $sock "Last-Modified: [HttpdDate $staticseconds 1]"
	puts $sock "Expires: [HttpdDate [expr $staticseconds+86400] 1]"
	puts $sock "Cache-Control: max-age=86400, must-revalidate"
    }
    upvar #0 Httpd$sock data
    if {[info exists data(outputheaders)] && $data(outputheaders)!=""} {
	puts -nonewline $sock $data(outputheaders)
    }
    puts $sock ""
    if {$mimetype=="text/html"} {
	fconfigure $sock -encoding utf-8
    } else {
	fconfigure $sock -translation binary
    }
    puts $sock $body
    Httpd_Log $sock HttpdReturn
    HttpdSockDone $sock 1
}


# HttpdReturnRedirect --
#
#       Redirect the browser to another page.
#
# Arguments:
#       sock            The socket to write to.
#       url             URL to redirect user to.
# Results:
#       None.

proc HttpdReturnRedirect {sock url} {
    puts $sock "HTTP/1.0 302 Redirection"
    puts $sock "Location: $url"
    puts $sock "Connection: close"
    upvar #0 Httpd$sock data
    if {[info exists data(outputheaders)] && $data(outputheaders)!=""} {
	puts -nonewline $sock $data(outputheaders)
    }
    puts $sock ""
    puts $sock "Redirect to <a href=\"$url\">$url</a>"
    Httpd_Log $sock HttpdReturnRedirect
    HttpdSockDone $sock 1
}

# HttpdReturnNotModified --
#
#       Return a not modified result.
#
# Arguments:
#       sock            The socket to write to.
#       modtime         If specified, modified time of resource.
# Results:
#       None.

proc HttpdReturnNotModified {sock {modtime ""}} {
    puts $sock "HTTP/1.0 304 Not Modified"
    puts $sock "Connection: close"
    if {$modtime!=""} {
	puts $sock "ETag: \"$modtime\""
	puts $sock "Last-Modified: [HttpdDate $modtime 1]"
    }
    upvar #0 Httpd$sock data
    if {[info exists data(outputheaders)] && $data(outputheaders)!=""} {
	puts -nonewline $sock $data(outputheaders)
    }
    puts $sock ""
    puts $sock ""
    Httpd_Log $sock HttpdReturnNotModified
    HttpdSockDone $sock 1
}

# HttpdReturnFile --
#
#       Return a file to a client, and close the connection.
#
# Arguments:
#       sock            The socket to write to.
#       file            File on disk.
#       filename        Name to return.
#       mimetype        MIME content type of file.
#       timestamp       File modification date.
#       view            If specified as "1", don't return as attachment.
#       flag            If specified as "-static" emit ETag etc. headers.
# Results:
#       None.

proc HttpdReturnFile {sock file filename mimetype timestamp {view ""} {flag ""}} {
    upvar #0 Httpd$sock data
    set version "1"; if {[info exists data(version)] && $data(version)!=""} {set version $data(version)}
    puts $sock "HTTP/1.$version 200 Data follows"
    puts $sock "Date: [HttpdDate [clock seconds]]"
    if {$view!="1"} {
        puts $sock "Content-Disposition: attachment; filename=\"$filename\""
    } else {
        puts $sock "Content-Disposition: inline"
    }
    puts $sock "Last-Modified: [HttpdDate $timestamp]"
    if {$flag=="-static"} {
    	puts $sock "ETag: \"$timestamp\""
	puts $sock "Expires: [HttpdDate [expr $timestamp+86400]]"
	puts $sock "Cache-Control: max-age=86400, must-revalidate"
    }
    puts $sock "Content-Type: $mimetype"
    
    set size [file size $file]
    puts $sock "Content-Length: $size"
    set close 1
    if {$close} {
	puts $sock "Connection: close"
    }
    puts $sock ""
    flush $sock

    if {$data(proto)!="HEAD"} {
        set data(sendingfile) 1
	fconfigure $sock -translation binary
	set in [open $file]
	fconfigure $in -translation binary
	set data(fcopy-fd) $in
	if {$size<0 || $size>4294967295} {set size -1}
	fcopy $in $sock -size $size \
	        -command [list HttpdCopyDone $in $sock $close]
    } else {
	HttpdSockDone $sock $close
    }
}


proc HttpdDecode {str} {
    # rewrite "+" back to space
    # protect \ from quoting another '\'
    set str [string map [list + { } "\\" "\\\\"] $str]
    
    # prepare to process all %-escapes
    regsub -all -- {%([A-Fa-f0-9][A-Fa-f0-9])} $str {\\u00\1} str
    
    # process \u unicode mapped chars
    set str [subst -novar -nocommand $str]
    set str [encoding convertfrom utf-8 $str]
    regsub -all {\r} $str {} str
    return $str
}



# Stuff from here on originally based on TclHttpd3.4.1 lib/upload.tcl,
# but now substantially modified


proc HttpdUploadInit {sock} {
    global Httpd
    upvar #0 Httpd$sock data
    
    if {![regexp {boundary=(.*)$} $data(mime,content-type) dummy boundary]} {
	HttpdError $sock 400 "Could not find boundary"
    }

    # PR#441.. make sure we don't time out after the default 10 minutes
    if {[info exists data(cancel)] && $data(cancel)!=""} {
	after cancel $data(cancel)
    }
    set data(cancel) [after $Httpd(uploadmaxtime) [list HttpdTimeout $sock]]

    set data(formvars) ""
    set data(upload-boundary) $boundary
    set data(upload-formname) ""
    set data(upload-filename) ""
    if {[info exists data(mime,content-length)]} {
	set data(upload-totallength) $data(mime,content-length)
    }
    set data(upload-currentlength) 0
    fileevent $sock readable [list HttpdUploadFindBoundary $sock]
}

proc HttpdUploadFindBoundary {sock} {
    upvar #0 Httpd$sock data
    if {[eof $sock]} {
	HttpdSockDone $sock 1
	return
    }
    if {[gets $sock line]>0} {
	# NOTE: don't use regexp here, as the boundary can include characters like
	#   '+' which will be interpreted by regexp T#468
	if {[string first "--$data(upload-boundary)" $line]==0} {
	    fileevent $sock readable [list HttpdUploadReadHeader $sock]
	}
    }
}

proc HttpdUploadReadHeader {sock} {
    global Httpd
    upvar #0 Httpd$sock data
    if {[eof $sock]} {
	HttpdSockDone $sock 1
	return
    }

    while {[gets $sock line]>=0} {
	### puts $line
	if {[string length [string trim $line]]==0} {
	    # end of headers
	    fconfigure $sock -translation binary -encoding binary
	    set varname $data(upload-formname)
	    lappend data(formvars) $varname
	    if {[info exists data(upload-contenttype)]} {
		set data(formvar-${varname}-contenttype) [string trim $data(upload-contenttype)]
	    }
	    if {[info exists data(upload-filename)] && $data(upload-filename)!=""} {
		set data(formvar-${varname}-filename) \
		    [HttpdDecode $data(upload-filename)]
	    }
	    if {![info exists data(upload-filename)] || $data(upload-filename)==""} {
		fileevent $sock readable [list HttpdUploadReadPart $sock]
	    } else {
		set data(upload-lastLineExists) 0
		if {![info exists Httpd(uploadcounter)]} {
		    set Httpd(uploadcounter) 0
		}
		set fn "upload[incr Httpd(uploadcounter)]"
		set data(upload-fd) [open $fn w]
		set data(formvar-${varname}-uploadfilename) $fn
		if {[info exists data(formvar-uploadticket-value)]} {
		    set t $data(formvar-uploadticket-value)
		    set data(upload-ticket) $t
		    set Httpd(uploadticket-sock-$t) $sock
		}
		fconfigure $data(upload-fd) -translation binary -encoding binary
		fileevent $sock readable [list HttpdUploadReadFile $sock]
	    }
	    return
	}
	if {[regexp {([^:	 ]+):(.*)$} $line x hdrname value]} {
	    set hdrname [string tolower $hdrname]
	    if {[string equal $hdrname "content-disposition"]} {
		foreach {x} [split [string trim $value] ";"] {
		    if {[regexp -- {(.*)=\"*([^\"]*)\"*\;*} [string trim $x] dummy var val]} {
			if {[string tolower $var]=="name"} {
			    set data(upload-formname) $val
			} elseif {[string tolower $var]=="filename"} {
			    set data(upload-filename) $val
			}
		    }
		}
	    } elseif {[string equal $hdrname "content-type"]} {
		set data(upload-contenttype) $value
	    } else {
		# ignore other headers for now
	    }
	}
    }
}


proc HttpdUploadReadPart {sock} {
    upvar #0 Httpd$sock data
    if {[eof $sock]} {
	HttpdSockDone $sock 1
	return
    }
    if {[gets $sock line] > 0} {
	### puts $line
	if {[string first "--$data(upload-boundary)" $line]==0} {
            set l [string length $data(upload-boundary)]
	    set end [string range $line [expr $l+2] [expr $l+3]]
	    if {$end == "--"} {
		catch {
		    # Trim the string to remove carriage returns.
		    set var $data(upload-formname)
		    if {[info exists data(formvar-${var}-value)]} {
			set data(formvar-${var}-value) \
			    [string trim $data(formvar-${var}-value)]
		    }
		}
		HttpdUploadDone $sock
	    } else {
		set var $data(upload-formname)
		catch {
		    # Trim the string to remove carriage returns.
		    if {[info exists data(formvar-${var}-value)]} {
			set data(formvar-${var}-value) \
			    [string trim $data(formvar-${var}-value)]
		    }
		}
		set data(upload-formname) ""
		unset -nocomplain data(upload-contenttype)
		unset -nocomplain data(upload-filename)
		fileevent $sock readable [list HttpdUploadReadHeader $sock]
	    }
	} else {
	    set var $data(upload-formname)
	    append data(formvar-${var}-value) $line
	}
    }
} 

proc HttpdUploadReadFile {sock} {
    upvar #0 Httpd$sock data
    if {[eof $sock]} {
	HttpdSockDone $sock 1
	return
    } 
    set maxbuffersize 1000
    set buffersize 0
    while {[set readcount [gets $sock line]] >= 0} {
	### puts $line
	if {[info exists data(upload-currentlength)]} {
	    incr data(upload-currentlength) $readcount
	}
	if {[string first "--$data(upload-boundary)" $line]==0} {
            set l [string length $data(upload-boundary)]
	    set end [string range $line [expr $l+2] [expr $l+3]]
            if {$data(upload-lastLineExists)} {
                # At least 1 line was read.  Write the last line to the
                # file without the trailing newline character.
                puts -nonewline $data(upload-fd) [string range $data(upload-lastLine) 0 end-1]
            }
	    set buffersize 0
	    close $data(upload-fd)
	    unset data(upload-fd)
	    if {$end == "--"} {
		HttpdUploadDone $sock
	    } else {
		set data(upload-formName) ""
		unset -nocomplain data(upload-contenttype)
		unset -nocomplain data(upload-filename)
		fileevent $sock readable [list HttpdUploadReadHeader $sock]
	    }
	    return
	} else {
            # Delay the writing of each line to make sure we don't add an
            # extra trailing newline to the last line.
            if {$data(upload-lastLineExists)} {
                puts $data(upload-fd) $data(upload-lastLine)
            } else {
                set data(upload-lastLineExists) 1
            }
            set data(upload-lastLine) $line
	}
	incr buffersize [string bytelength $line]
	if { $buffersize > $maxbuffersize } {
	    set buffersize 0
	    fileevent $sock readable [list HttpdUploadReadFile $sock]
	    update idletasks
	    break
	}
    }
    
}

proc HttpdUploadDone {sock} {
    global Httpd
    upvar #0 Httpd$sock data
    if {[info exists data(upload-fd)]} {
	close $data(upload-fd)
	unset data(upload-fd)
    }
    foreach i [array names data upload-*] {
	if {$i=="upload-ticket"} {
	    set t $data($i)
	    if {[info exists Httpd(uploadticket-sock-$t)]} {
		unset Httpd(uploadticket-sock-$t)
	    }
	}
	unset data($i)
    }
    HttpdRespond $sock
}


