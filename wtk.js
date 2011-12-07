var wtk = {
    
    widgets : new Array(),
    widgetInfo : new Array(),
    
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
                                complete: function() {setTimeout(wtk.poller,100);},
                                error: function(jqXHR, textStatus, errorThrown) {console.log('ajax error '+textStatus+' '+errorThrown);}});},
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
    
    createFrame   : function(id) { wtk.CreateWidget(id, 'div', '', '');},
    
    createCheckButton : function(id,txt) { 
        var w = wtk.CreateWidget(id,'span', '', ''); 
        var c = w.appendChild(document.createElement('input'));
        var l = w.appendChild(document.createElement('span'));
        c.type = 'checkbox';
        c.onclick = function() {wtk.checkButtonClicked(id);};
        l.innerHTML = txt;
    },
    checkButtonClicked : function(id) { var ev; if (wtk.widgets[id].childNodes[0].checked==true) {ev='checked';} else {ev='unchecked';}; wtk.sendto('EVENT ' + id + ' ' + ev);},
    
    /*
     * Grid .
     */
    
    newGrid : function(parent,id) {
        var w = document.createElement('table');
        w.id = id;
        wtk.widgets[parent].appendChild(w);
    },
    
    /*
     * Canvas
     */
    
    createCanvas : function(id) {
        var w = wtk.CreateWidget(id,'canvas', '', '');
        w.width = 100; w.height = 100; w.style.width = '100px'; w.style.height = '100px';
        w.style.background = '#ffffff';
        w.style.position = 'relative';
        w.style.cursor = 'default';
        w.onmousedown = function(ev) {wtk.canvasMouse(ev, id, 'mousedown');}
        w.onmousemove = function(ev) {wtk.canvasMouse(ev, id, 'mousemove');}
        w.onmouseup = function(ev) {wtk.canvasMouse(ev, id, 'mouseup');}
        w.ondrag = function(ev) {wtk.canvasMouse(ev, id, 'drag');}
        wtk.widgetInfo[id] = {items:[]};
    },
    
    canvasMouse : function(ev, id, action) {
        wtk.sendto('EVENT '+id+' '+action+' '+(ev.pageX-wtk.widgets[id].offsetLeft)+' '+(ev.pageY-wtk.widgets[id].offsetTop)+' '+ev.button);
    },
    
    canvasCreateItem : function(id, cid, type, x0, y0, x1, y1) {
        wtk.widgetInfo[id].items[cid] = {type:type, x0:x0, y0:y0, x1:x1, y1:y1};
        var ctx = wtk.widgets[id].getContext("2d");
        ctx.fillStyle='#ff0000';
        ctx.lineWidth = 3;
        ctx.lineCap = 'round';
        if (type=="line") {ctx.moveTo(x0,y0);ctx.lineTo(x1,y1);ctx.stroke();} 
    }
    
};

