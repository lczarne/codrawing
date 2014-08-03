var express = require('express');
var app = express();
var server = require('http').createServer(app);
var io = require('socket.io').listen(server);
var mongoose = require('mongoose');
var fs = require('fs');
var path = require('path');
var rimraf = require('rimraf');
var md5 = require('md5');

var imageBaseURL = 'http://192.168.0.10:8080/'
//var imageBaseURL = 'http://54.76.227.228/'

//server.listen(8882);
server.listen(8080);

app.use(express.static('web'));
app.use(express.json());
app.use(express.urlencoded());
app.use(express.multipart({uploadDir:'web/public/media'}));
app.use(express.multipart());

//setup mongo

mongoose.connect('mongodb://localhost/myMongo');
var db = mongoose.connection;
db.on('error',console.error.bind(console,'connection error:'));
db.once('open', function callback(){
  //mongoose.connection.db.dropDatabase();

	console.log('db connected!!!');

});

//Event setup

var eventSchema = mongoose.Schema({
  eventId: Number,
	socketId: Number,
	state: Number,
  eraser: Boolean,
  paint: {
    x: Number,
    y: Number
  }
});

eventSchema.path('eventId').index({unique: true});

eventSchema.methods.printMe = function(){
  console.log("Hi, my eventId = "+this.eventId);
};

var Event = mongoose.model('Event',eventSchema);

function savingEventCallback(error, newEvent) {
  if (error) {
    return console.error(error);
  }
  else {
    console.log("saved id: "+newEvent.eventId);
  }
  newEvent.printMe();
}

//ImageSetup
var imageSchema = mongoose.Schema({
  imageId: String,
  socketId: Number,
  imageInfo: {
    x: Number,
    y: Number,
    width: Number,
    height: Number
  },
  imageURL: String
});
imageSchema.path('imageId').index({unique: true});

imageSchema.methods.printMe = function(){
  console.log("Image: "+this.imageId);
}

var ImageMedia = mongoose.model('ImageMedia',imageSchema);

//VideoSetup
var videoSchema = mongoose.Schema({
  videoId: String,
  socketId: Number,
  videoInfo: {
    x: Number,
    y: Number,
    width: Number,
    height: Number
  },
  videoURL: String
});
videoSchema.path('videoId').index({unique: true});

videoSchema.methods.printMe = function(){
  console.log("Video: "+this.videoId);
}

var VideoMedia = mongoose.model('VideoMedia',videoSchema);

function savingVideoMediaCallback(error, newVideo) {
  if (error) {
    return console.error(error);
  }
  else {
    console.log("saved video id: "+newVideo.videoId);
  }
  newVideo.printMe();
}

function savingImageMediaCallback(error, newImage) {
  if (error) {
    return console.error(error);
  }
  else {
    console.log("saved image id: "+newImage.imageId);
  }
  newImage.printMe();
}

function sendDrawingStateToSocket(socket) {
  Event.find(function (err,events) {
    socket.emit('drawingState',events);
  });
  ImageMedia.find(function(err,images){
    socket.emit('imageState',images);
    console.log('IMAGES STATE SENT');
  });
  VideoMedia.find(function(err,videos){
    socket.emit('videoState',videos);
    console.log('VIDEOS STATE SENT')
  });
}

function clearEventState() {
  Event.remove({},function (err){
    console.log("Events collection cleared.")
  });
}

function clearMediaState() {
  ImageMedia.remove({},function (err){
    console.log("Images collection cleared.")
  });
  VideoMedia.remove({},function (err){
    console.log("Video collection cleared.")
  });

  rimraf('web/public/media',function(err){
    if (err) {
      console.log(err);
    }
    else {
      console.log('MEDIA removed')  
    }
    createTempMediaFolder();
  });
}

function createTempMediaFolder() {
  fs.mkdir('web/public/media', function(err){
    if (err) {
      console.log(err);
    }
    else {
      console.log('media folder created');
    }
  });
}

clearEventState();
clearMediaState();

//setup websockets

var count = 0;
var sockets = new Array();

var roomSockets = function() {};

var testRoomId = "testID";

io.sockets.on('connection', function (socket) {

  sendDrawingStateToSocket(socket);

	sockets[count] = socket;
	count++;

  socket.on('paint',function(msg){
    if (msg.eraser) {
      console.log("eraser id f* TRUE!!!");
    }
    else {
      console.log("eraser id f* FALSE!!!");
    }

    var paintEvent = new Object();
    var socketId = getSocketId(this);
    paintEvent.socketId = socketId;
    paintEvent.paint = msg.paint;
    paintEvent.state = msg.state;
    paintEvent.eraser = msg.eraser;
    saveSocketEvent(paintEvent);
    emit('serverPaint',paintEvent,socketId);
  });

  socket.on('image',function(msg){
    var imageEvent = new Object();
    var socketId = getSocketId(this);
    imageEvent.imageId = msg.imageId;
    imageEvent.socketId = socketId;
    imageEvent.imageInfo = msg.imageInfo;
    imageEvent.imageURL = mediaURLS[msg.imageId];
    saveImageFromSocket(imageEvent);
    emit('serverImage',imageEvent,socketId);
  });

  socket.on('video',function(msg){
    var videoEvent = new Object();
    var socketId = getSocketId(this);
    videoEvent.videoId = msg.videoId;
    videoEvent.socketId = socketId;
    videoEvent.videoInfo = msg.videoInfo;
    videoEvent.videoURL = mediaURLS[msg.videoId];
    saveVideoFromSocket(videoEvent);
    emit('serverVideo',videoEvent,socketId);
  });

  socket.on('mediaDelete',function(msg){
    var mediaDeleteEvent = new Object();
    var socketId = getSocketId(this);
    console.log(msg.mediaId);
    mediaDeleteEvent.mediaId = msg.mediaId;
    console.log('media delteing ID ' + mediaDeleteEvent.mediaId)
    emit('serverMediaDelete',mediaDeleteEvent,socketId);

    ImageMedia.remove({imageId : msg.mediaId},function (err){
      if (!err) {
        console.log("Image "+msg.mediaId+" deleted");        
      }
    });

    VideoMedia.remove({videoId : msg.mediaId},function (err){
      if (!err) {
        console.log("Video "+msg.mediaId+" deleted");        
      }
    });

    //TODO - delete file
  });

});

function emit(eventName,eventData,senderId) {
  for (var i = sockets.length - 1; i >= 0; i--) {
      if (i != senderId) {
        sockets[i].emit(eventName,eventData);
      };
    };
}

var eventCounter = 0;

function getSocketId(socket)
{
  for (var i = sockets.length - 1; i >= 0; i--) {
    if (sockets[i] == socket) {
      return i;
    };    
  }
  return -1;
}

function saveSocketEvent(socketEvent) {
  var eventToSave = new Event();
  eventToSave.eventId = eventCounter++;
  eventToSave.socketId = socketEvent.socketId;
  eventToSave.state = socketEvent.state;
  eventToSave.eraser = socketEvent.eraser;
  eventToSave.paint = socketEvent.paint;
  eventToSave.save(savingEventCallback)
}

function saveImageFromSocket(imageEvent) {
  var imageMediaToSave = new ImageMedia();
  imageMediaToSave.imageId = imageEvent.imageId
  imageMediaToSave.socketId = imageEvent.socketId;
  imageMediaToSave.imageInfo = imageEvent.imageInfo;
  imageMediaToSave.imageURL = imageEvent.imageURL;
  imageMediaToSave.save(savingImageMediaCallback);
}

function saveVideoFromSocket(videoEvent) {
  var videoMediaToSave = new VideoMedia();
  videoMediaToSave.videoId = videoEvent.videoId;
  videoMediaToSave.socketId = videoEvent.socketId;
  videoMediaToSave.videoInfo = videoEvent.videoInfo;
  videoMediaToSave.videoURL = videoEvent.videoURL;
  videoMediaToSave.save(savingVideoMediaCallback);
}

var mediaURLS = {};

//Images upload
app.post('/api/images',function(req,res) {
  var serverPath = req.files.myImage.path;
  var pathComponents = serverPath.split('/');
  pathComponents.shift();
  serverPath = pathComponents.join('/');
  serverPath = imageBaseURL + serverPath;
  var timestamp = new Date().getTime();
  var newImageId = md5(timestamp+Math.random());
  mediaURLS[newImageId] = serverPath;

  console.log('saved IN MEDIA URLS: '+mediaURLS[newImageId]);
  res.send({
      imageId : newImageId
  });
});

app.post('/api/videos',function(req,res) {
  var serverPath = req.files.myVideo.path;
  var pathComponents = serverPath.split('/');
  pathComponents.shift();
  serverPath = pathComponents.join('/');
  serverPath = imageBaseURL + serverPath;
  var timestamp = new Date().getTime();
  var newVideoId = md5(timestamp+Math.random());
  mediaURLS[newVideoId] = serverPath;
  res.send({
      videoId : newVideoId
  });
});

var Set = function() {};
Set.prototype.add = function(bla) {
  if (typeof bla != "undefined") {
    this[bla] = true;
    return true;
  }
  return false;
}
Set.prototype.remove = function(bla) {delete this[bla];}

var rooms = new Set();
rooms.add('testID');
rooms.add('nazwa dluzsza');

app.get('/api/room/:id',function(req,res){
  console.log('got ID: '+req.params.id);
  var roomId = req.params.id;
  if (roomId in rooms) res.send(true);
  else res.send(false);
});

app.post('/api/room',function(req,res){
  console.log('createRoom2: '+req.body.roomId);
  var roomId = req.body.roomId;
  console.log('new roomId: '+roomId);
  console.log(rooms);
  var roomCreated = true;

  if (roomId in rooms) {
    roomCreated = false;
    console.log('exists');
  }
  else {
    if (rooms.add(roomId) == false) {
      roomCreated = false;
    }
    
  }

  res.send({
    created : roomCreated
  });
});

