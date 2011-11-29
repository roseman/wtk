var wtk = {
    
    widgets : new Array(),
    
    init : function() {
        wtk.widgets['obj0'] = document.getElementById('obj0');
        setTimeout(wtk.poller,100);
    },
    
    poller : function() {$.ajax({type:'GET', url:'poll.html', dataType:'script', success: function() {setTimeout(wtk.poller,100);}});},
    sendto : function(msg) { $.get('wtkcb.html', {cmd : msg});},
    
    CreateWidget : function(id,type,txt,attr) {
        var w = document.createElement(type);
        w.id = id;
        if(txt!='') {if (attr=='innerHTML') {w.innerHTML=txt;} else {w.value=txt;};}
        wtk.widgets[id] = w;
        return w;
    },
    
    createButton  : function(id,txt) { wtk.CreateWidget(id,'button',txt,'innerHTML').onclick = function() {wtk.buttonClicked(id);}; },
    buttonClicked : function(id) { wtk.sendto('EVENT '+id+' pressed'); },

    createLabel   : function(id, txt) { wtk.CreateWidget(id, 'span', txt,'innerHTML'); },

    createEntry   : function(id, txt) { wtk.CreateWidget(id, 'input', txt,'value').onkeyup = function() {wtk.entryChanged(id);}; },
    entryChanged  : function(id) { wtk.sendto('EVENT '+id+' value '+wtk.widgets[id].value); },
    
    griditup      : function(master,slave) { wtk.widgets[master].appendChild(wtk.widgets[slave]); }
};

