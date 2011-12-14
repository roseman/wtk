var wtk = {
    
    widgets : new Array(),
    objs : new Array(),
    
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
    
    Canvas : function(w,id) {
        var self = this;
        this.w = w;
        this.id = id;
        this.ctx = null;
        this.items = [];
        this.context = w.getContext("2d");
        this.drawtimer = null;
        this.ghostcanvas = null;
        this.gctx = null;
        w.width = 100; w.height = 100; w.style.width = '100px'; w.style.height = '100px';
        w.style.background = '#ffffff';
        w.style.position = 'relative';
        w.style.cursor = 'default';
        
        w.onmousedown = function(ev) {self.handleMouse(ev, 'mousedown');}
        w.onmousemove = function(ev) {self.handleMouse(ev, 'mousemove');}
        w.onmouseup = function(ev) {self.handleMouse(ev, 'mouseup');}
        w.ondrag = function(ev) {self.handleMouse(ev, 'drag');}
        
        this.createItem = function(cid, type, coords, opts) {
            var o = {'cid':cid,'type':type,'coords':coords,'opts':opts};
            this.items.push(o);
            this.scheduleDraw();
        }
        
        this.scheduleDraw = function() {if (this.drawtimer==null) {var self=this;this.drawtimer = setTimeout(function() {self.draw()}, 100)}}
        
        this.draw = function() {
            var self = this;
            this.drawtimer = null;
            var ctx = this.context;
            ctx.clearRect(0,0,this.w.width,this.w.height);
            ctx.beginPath();
            $.each(this.items, function(idx,i) {self.drawItem(ctx,i)});
        }
        
        this.drawItem = function(ctx,i,color) {
            ctx.beginPath();
            ctx.strokeStyle='#000000'; if ('strokeStyle' in i.opts && color!='black') {ctx.strokeStyle = i.opts['strokeStyle'];}
            ctx.fillStyle='#000000'; if ('fillStyle' in i.opts && color!='black') {ctx.fillStyle = i.opts['fillStyle'];}
            ctx.lineWidth = 3; if ('lineWidth' in i.opts) {ctx.lineWidth = i.opts['lineWidth'];}
            ctx.lineCap = 'round';
            if (i.type=="line") {ctx.moveTo(i.coords[0],i.coords[1]); for (var j=2;j<i.coords.length;j+=2) {ctx.lineTo(i.coords[j],i.coords[j+1]);};ctx.stroke();} 
            if (i.type=="rectangle") {ctx.fillRect(i.coords[0],i.coords[1],i.coords[2]-i.coords[0],i.coords[3]-i.coords[1]);}
        }
      
        this.itemAt = function(x,y) {
            /* use a 'ghost canvas' - see http://simonsarris.com/blog/140-canvas-moving-selectable-shapes */
            if (this.ghostcanvas==null) {this.ghostcanvas = document.createElement('canvas');this.gctx = null;}
            if (this.ghostcanvas.width!=this.w.width || this.ghostcanvas.height!=this.w.height) {
                this.ghostcanvas.width = this.w.width; this.ghostcanvas.height = this.w.height; this.gctx = null;
            }
            if (this.gctx==null) {this.gctx = this.ghostcanvas.getContext("2d");}
            this.gctx.clearRect(0,0,this.ghostcanvas.width,this.ghostcanvas.height);
            for (var i = this.items.length-1; i>=0; i--) {
                this.drawItem(this.gctx, this.items[i],'black');
                var imageData = this.gctx.getImageData(x,y,1,1);
                if (imageData.data[3]>0) {
                    return this.items[i].cid;
                }
            }
            return '';
        }
      
        this.handleMouse = function(ev, action) {
            var itemhit = '';
            var x = ev.pageX-this.w.offsetLeft;
            var y = ev.pageY-this.w.offsetTop;
            if (action=="mousedown") {itemhit = this.itemAt(x,y);}
            wtk.sendto('EVENT '+this.id+' '+action+' '+x+' '+y+' '+ev.button+' '+itemhit);
        }
        
    },
        
    createCanvas : function(id) {
        var w = wtk.CreateWidget(id,'canvas', '', '');
        wtk.objs[id] = new wtk.Canvas(w,id);
    },
    
};

