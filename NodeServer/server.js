var express = require('express');
var app = express();
var server = require('http').createServer(app);
var io = require('socket.io').listen(server);
var mongoose = require('mongoose');
var fs = require('fs');
var path = require('path');
var rimraf = require('rimraf');

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
	console.log('db connected!!!');

});

//Event setup

var eventSchema = mongoose.Schema({
  eventID: Number,
	socketID: Number,
	state: Number,
  eraser: Boolean,
  paint: {
    x: Number,
    y: Number
  }
});

eventSchema.path('eventID').index({unique: true});

eventSchema.methods.printMe = function(){
  console.log("Hi, my eventID = "+this.eventID);
};

var Event = mongoose.model('Event',eventSchema);

function savingEventCallback(error, newEvent) {
  if (error) {
    return console.error(error);
  }
  else {
    console.log("saved id: "+newEvent.eventID);
  }
  newEvent.printMe();
}

//ImageSetup
var imageSchema = mongoose.Schema({
  imageID: Number,
  socketID: Number,
  imageInfo: {
    x: Number,
    y: Number,
    width: Number,
    height: Number
  },
  imageURL: String
});
imageSchema.path('imageID').index({unique: true});

imageSchema.methods.printMe = function(){
  console.log("Image: "+this.imageID);
}

var ImageMedia = mongoose.model('ImageMedia',imageSchema);

//VideoSetup
var videoSchema = mongoose.Schema({
  videoId: Number,
  socketID: Number,
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
    console.log("saved image id: "+newImage.imageID);
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
    var socketID = getSocketID(this);
    paintEvent.socketID = socketID;
    paintEvent.paint = msg.paint;
    paintEvent.state = msg.state;
    paintEvent.eraser = msg.eraser;
    saveSocketEvent(paintEvent);
    emit('serverPaint',paintEvent,socketID);
  });

  socket.on('image',function(msg){
    var imageEvent = new Object();
    var socketID = getSocketID(this);
    imageEvent.socketID = socketID;
    imageEvent.imageInfo = msg.imageInfo;
    imageEvent.imageURL = msg.imageURL;
    saveImageFromSocket(imageEvent);
    emit('serverImage',imageEvent,socketID);
  });

  socket.on('video',function(msg){
    var videoEvent = new Object();
    var socketID = getSocketID(this);
    videoEvent.socketID = socketID;
    videoEvent.videoInfo = msg.videoInfo;
    videoEvent.videoURL = msg.videoURL;
    saveVideoFromSocket(videoEvent);
    emit('serverVideo',videoEvent,socketID);
  });

});

function emit(eventName,eventData,senderID) {
  for (var i = sockets.length - 1; i >= 0; i--) {
      if (i != senderID) {
        sockets[i].emit(eventName,eventData);
      };
    };
}

var eventCounter = 0;
var imageCounter = 0;
var videoCounter = 0;

function getSocketID(socket)
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
  eventToSave.eventID = eventCounter++;
  eventToSave.socketID = socketEvent.socketID;
  eventToSave.state = socketEvent.state;
  eventToSave.eraser = socketEvent.eraser;
  eventToSave.paint = socketEvent.paint;
  eventToSave.save(savingEventCallback)
}

function saveImageFromSocket(imageEvent) {
  var imageMediaToSave = new ImageMedia();
  imageMediaToSave.imageID = imageCounter++;
  imageMediaToSave.socketID = imageEvent.socketID;
  imageMediaToSave.imageInfo = imageEvent.imageInfo;
  imageMediaToSave.imageURL = imageEvent.imageURL;
  imageMediaToSave.save(savingImageMediaCallback);
}

function saveVideoFromSocket(videoEvent) {
  var videoMediaToSave = new VideoMedia();
  videoMediaToSave.videoId = videoCounter++;
  videoMediaToSave.socketID = videoEvent.socketID;
  videoMediaToSave.videoInfo = videoEvent.videoInfo;
  videoMediaToSave.videoURL = videoEvent.videoURL;
  videoMediaToSave.save(savingVideoMediaCallback);
}

//Images upload
app.post('/api/images',function(req,res) {
  var serverPath = req.files.myImage.path;
  var pathComponents = serverPath.split('/');
  pathComponents.shift();
  serverPath = pathComponents.join('/');
  serverPath = imageBaseURL + serverPath;
  res.send({
      path: serverPath
  });
});

app.post('/api/videos',function(req,res) {
  var serverPath = req.files.myVideo.path;
  var pathComponents = serverPath.split('/');
  pathComponents.shift();
  serverPath = pathComponents.join('/');
  serverPath = imageBaseURL + serverPath;
  res.send({
      path: serverPath
  });
});

