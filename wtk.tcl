# This code is loaded into each application instance interpreter.  It maintains state
# for each widget, and then actually creates and manipulates widgets on the client side 
# by sending Javascript commands.  It also receives callbacks from the client side which
# are interpreted and used to update internal widget state here, which often triggers
# callbacks or other event bindings.
#
# Communication with the client is solely via the "fromclient" and "toclient" routines
# (the latter of which is setup in the wtk::init call).


package require snit

source wtk-base.tcl
source wtk-widgets.tcl
source wtk-grid.tcl

