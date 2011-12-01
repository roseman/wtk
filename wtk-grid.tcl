namespace eval ::wtk {
    # Grid geometry manager and friends
    
    # Place a slave inside its master.  Right now this doesn't process any actual grid options. Or handle multiple widgets. Or etc.
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
                if {[dict keys $args -column]==""} {dict set args -column 0}; # TODO - proper defaults
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
            if {[dict keys $args -column] eq "" || [dict keys $args -row] eq ""} {error "need to supply -column and -row"}; # NOTE: caller ensures we have a column and row
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