var express = require('express');
var app = express();
var server = require('http').createServer(app);
var io = require('socket.io').listen(server);
var mongoose = require('mongoose');

server.listen(8882);

app.use(express.static('web'));

//setup mongo

mongoose.connect('mongodb://localhost/test');
var db = mongoose.connection;
db.on('error',console.error.bind(console,'connection error:'));
db.once('open', function callback(){
	console.log('db connected!!!');
});

var eventSchema = mongoose.Schema({
  eventID: Number,
	socketID: Number,
	state: Number,
  paint: {
    x: Number,
    y: Number
  }
});

eventSchema.methods.printMe = function(){
  console.log("Hi, my eventID = "+this.eventID);
};

eventSchema.path('eventID').index({unique: true});

var Event = mongoose.model('Event',eventSchema);

var newEvent = new Event({
  eventID: 5,
	socketID: 23,
	state: 9
})


// Event.remove({}, function(err){
//   if (err) return console.error(err);
//   console.log('removed');
// });

//newEvent.save(savingEventCallback);

function savingEventCallback(error, newEvent) {
  if (error) {
    return console.error(error);
  }
  else {
    console.log("saved id: "+newEvent.eventID);
  }
  newEvent.printMe();
}


// Event.find(function (err,events){
//   if (err) return console.error(err);
//   console.log(events);
// });

//setup websockets

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
    saveSocketEvent(paintEvent);

  	for (var i = sockets.length - 1; i >= 0; i--) {
      if (i != socketID) {
        sockets[i].emit('serverPaint',paintEvent);
        console.log('PAINT: %j',paintEvent);
      };
  	};
  })
});

var eventCounter = 0;

function saveSocketEvent(socketEvent) {
  var eventToSave = new Event();
  eventToSave.eventID = eventCounter++;
  eventToSave.socketID = socketEvent.ID;
  eventToSave.state = socketEvent.state;
  eventToSave.paint = socketEvent.paint;
  eventToSave.save(savingEventCallback)
}

function getSocketID(socket)
{
  for (var i = sockets.length - 1; i >= 0; i--) {
    if (sockets[i] == socket) {
      return i;
    };    
  }
  return -1;
}

