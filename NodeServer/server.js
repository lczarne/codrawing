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
  	for (var i = sockets.length - 1; i >= 0; i--) {
  		sockets[i].emit('serverPaint',msg);
  	};
  })

  socket.on('control',function(msg){
  	for (var i = sockets.length - 1; i >= 0; i--) {
  		sockets[i].emit('serverControl',msg);
  	};
  })


});

//app.listen(8881);