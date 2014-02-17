var express = require('express');
var app = express();
var server = require('http').createServer(app);
var io = require('socket.io').listen(server);


server.listen(8882);

app.use(express.static('web'));

var count = 0;
var sockets = new Array();

io.sockets.on('connection', function (socket) {

	sockets[count] = socket;
	count++;

  socket.on('paint',function(msg){
    
    var paintEvent = new Object();
    var socketID = getSocketID(this);
    paintEvent.ID = socketID;
    paintEvent.paint = msg.paint;
    paintEvent.state = msg.state;

  	for (var i = sockets.length - 1; i >= 0; i--) {
      if (i != socketID) {
        sockets[i].emit('serverPaint',paintEvent);
        console.log('PAINT: %j',paintEvent);
      };
  		
  	};
  })

  // socket.on('control',function(msg){
  // 	for (var i = sockets.length - 1; i >= 0; i--) {
  // 		sockets[i].emit('serverControl',msg);
  // 	};
  // })


});

function getSocketID(socket)
{
  for (var i = sockets.length - 1; i >= 0; i--) {
    if (sockets[i] == socket) {
      return i;
    };    
  }
  return -1;
}

//app.listen(8881);