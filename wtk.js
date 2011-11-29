var wtk = {
    
    widgets : new Array(),
    
    /*
     *   Initialize, and manage two AJAX connections to the server; one is used to send
     *   messages, and the other polling connection is used to receive messages.  These
     *   correspond to the routines in server.tcl, and could be equally well replaced by
     *   a different and/or more reliable communications channel.
     */
    init : function(sessionid) {
        wtk.sessionid = sessionid;
        wtk.widgets['obj0'] = document.getElementById('obj0');
        setTimeout(wtk.poller,100);
    },
    
    poller : function() {$.ajax({type:'GET', url:'wtkpoll.html?sessionid='+wtk.sessionid, dataType:'script', 
                                success: function() {setTimeout(wtk.poller,100);}});},
    sendto : function(msg) { $.get('wtkcb.html?sessionid='+wtk.sessionid, {cmd : msg});},
    
    /*
     * Generic widget creation; each widget is an HTML element of a certain type, and is given an
     * id by the wtk code on the server side which is used to uniquely identify it.
     */
    CreateWidget : function(id,type,txt,attr) {
        var w = document.createElement(type);
        w.id = id;
        if(txt!='') {if (attr=='innerHTML') {w.innerHTML=txt;} else {w.value=txt;};}
        wtk.widgets[id] = w;
        return w;
    },
    
    /*
     * Buttons, labels and entries, oh my!
     */
    createButton  : function(id,txt) { wtk.CreateWidget(id,'button',txt,'innerHTML').onclick = function() {wtk.buttonClicked(id);}; },
    buttonClicked : function(id) { wtk.sendto('EVENT '+id+' pressed'); },

    createLabel   : function(id, txt) { wtk.CreateWidget(id, 'span', txt,'innerHTML'); },

    createEntry   : function(id, txt) { wtk.CreateWidget(id, 'input', txt,'value').onkeyup = function() {wtk.entryChanged(id);}; },
    entryChanged  : function(id) { wtk.sendto('EVENT '+id+' value '+wtk.widgets[id].value); },
    
    /*
     * Grid placeholder; for now we simply add a slave as the last child of its master.
     */
    griditup      : function(master,slave) { wtk.widgets[master].appendChild(wtk.widgets[slave]); }
};

