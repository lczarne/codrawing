var express = require('express');
var app = express();
var server = require('http').createServer(app);
var io = require('socket.io').listen(server);
var mongoose = require('mongoose');
var fs = require('fs');
var path = require('path');
var md5 = require('MD5');

var config = require('./config.js');
var db = require('./db.js');
var Set = require('./set.js');

var mediaBaseURL = config.baseURL + ':' + config.port + '/';

server.listen(config.port);

app.use(express.static(config.staticWebPath));
app.use(express.json());
app.use(express.urlencoded());
app.use(express.multipart({uploadDir:config.staticWebPath+config.mediaPath}));
app.use(express.multipart());

function savingEventCallback(error, newEvent) {
  if (error) {
    return console.error(error);
  }
  else {
    console.log("saved id: "+newEvent.drawEventId);
  }
  newEvent.printMe();
}

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

function sendDrawingStateToSocket(socket,joinedRoomId) {
  db.drawEvent.find({roomId : joinedRoomId}, function (err,events) {
    socket.emit('drawingState',events);
  });
  db.imageMedia.find({roomId : joinedRoomId}, function(err,images){
    socket.emit('imageState',images);
    console.log('IMAGES STATE SENT');
  });
  db.videoMedia.find({roomId : joinedRoomId}, function(err,videos){
    socket.emit('videoState',videos);
    console.log('VIDEOS STATE SENT')
  });
}

db.clearDrawEventState();
db.clearMediaState();

//setup websockets

var count = 0;
var sockets = new Array();


var roomSockets = function() {};
var socketRoom = function() {};

function newRoom(roomId) {
  var sockets = new Array();
  roomSockets[roomId] = sockets;
  console.log('Added room with ID: '+roomId);
}

function joinRoom(socket,roomId) {
  var sockets = roomSockets[roomId];
  if (typeof sockets != "undefined") {
    sockets.push(socket);
    socketRoom[socket] = roomId;
    count++;
    console.log('Added new socket to room: '+roomId);
  }
  else {
    console.log('Socket not added to room '+roomId);
  }
}

function leaveRoom(socket) {
  var aRoomId = socketRoom[socket];
  if (typeof aRoomId != 'undefined') {
    var peers = roomSockets[aRoomId];
    if (typeof peers != 'undefined') {
       var index = peers.indexOf(socket);
       if (index > -1) {
        peers.splice(index,1);
        console.log('removed peer from room: '+aRoomId);
       }
       else console.log('not found among peers in room: '+aRoomId);
    }
    else console.log('no peers found for room: '+aRoomId);
  }
  else console.log('no room found with id: '+aRoomId);
}

function setupSocket(socket,roomId) {
  sendDrawingStateToSocket(socket,roomId);

  socket.on('paint',function(msg){
    console.log('painting in : '+roomId);

    var paintEvent = new Object();
    paintEvent.roomId = roomId;
    paintEvent.paint = msg.paint;
    paintEvent.state = msg.state;
    paintEvent.eraser = msg.eraser;
    saveSocketEvent(paintEvent);
    emit('serverPaint',paintEvent,roomId,this);
  });

  socket.on('image',function(msg){
    var imageEvent = new Object();
    imageEvent.roomId = roomId;
    imageEvent.imageId = msg.imageId;
    imageEvent.imageInfo = msg.imageInfo;
    imageEvent.imageURL = mediaURLS[msg.imageId];
    saveImageFromSocket(imageEvent);
    console.log('emittin IMAGEIMAGEIMAGE')
    emit('serverImage',imageEvent,roomId,this);
  });

  socket.on('video',function(msg){
    var videoEvent = new Object();
    videoEvent.roomId = roomId;
    videoEvent.videoId = msg.videoId;
    videoEvent.videoInfo = msg.videoInfo;
    videoEvent.videoURL = mediaURLS[msg.videoId];
    saveVideoFromSocket(videoEvent);
    emit('serverVideo',videoEvent,roomId,this);
  });

  socket.on('mediaDelete',function(msg){
    var mediaDeleteEvent = new Object();
    console.log(msg.mediaId);
    mediaDeleteEvent.roomId = roomId;
    mediaDeleteEvent.mediaId = msg.mediaId;
    console.log('media delteing ID ' + mediaDeleteEvent.mediaId)
    emit('serverMediaDelete',mediaDeleteEvent,roomId,this);

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

  });
}

io.sockets.on('connection', function (socket) {
  console.log('conndected to ROOM');

  socket.on('joinRoom',function(msg){
    var roomId = msg.roomId;
    joinRoom(this,roomId);
    setupSocket(socket,roomId);

    var rsp = new Object();
    rsp.roomId = roomId;

    this.emit('joinedRoom',rsp);
  });

  socket.on('disconnect', function () {
    leaveRoom(socket);
    console.log('disconnected event');
  });


});

function emit(eventName,eventData,roomId,socket) {
  var peers = roomSockets[roomId];
  console.log('Emit to room '+roomId);
  for (var i = peers.length - 1; i >= 0; i--) {
      var peer = peers[i];
      if (peer != socket) {
        peer.emit(eventName,eventData);
      };
  };
}

var eventCounter = 0;

function saveSocketEvent(socketEvent) {
  var eventToSave = new db.drawEvent();
  eventToSave.drawEventId = eventCounter++;
  eventToSave.roomId = socketEvent.roomId;
  eventToSave.state = socketEvent.state;
  eventToSave.eraser = socketEvent.eraser;
  eventToSave.paint = socketEvent.paint;
  eventToSave.save(savingEventCallback)
}

function saveImageFromSocket(imageEvent) {
  var imageMediaToSave = new db.imageMedia();
  imageMediaToSave.imageId = imageEvent.imageId
  imageMediaToSave.roomId = imageEvent.roomId;
  imageMediaToSave.imageInfo = imageEvent.imageInfo;
  imageMediaToSave.imageURL = imageEvent.imageURL;
  imageMediaToSave.save(savingImageMediaCallback);
}

function saveVideoFromSocket(videoEvent) {
  var videoMediaToSave = new db.videoMedia();
  videoMediaToSave.videoId = videoEvent.videoId;
  videoMediaToSave.roomId = videoEvent.roomId;
  videoMediaToSave.videoInfo = videoEvent.videoInfo;
  videoMediaToSave.videoURL = videoEvent.videoURL;
  videoMediaToSave.save(savingVideoMediaCallback);
}

var mediaURLS = {};

//Images upload
app.post(config.APIImages,function(req,res) {
  var serverPath = req.files.myImage.path;
  var newMediaId = createAndSaveNewMediaId(serverPath);
  res.send({
      imageId : newMediaId
  });
});

app.post(config.APIVideos,function(req,res) {
  var serverPath = req.files.myVideo.path;
  var newMediaId = createAndSaveNewMediaId(serverPath);
  res.send({
      videoId : newMediaId
  });
});

function createAndSaveNewMediaId(serverPath) {
  var pathComponents = serverPath.split('/');
  console.log('IMG path '+serverPath);
  //cut '../web/'
  pathComponents.shift();
  pathComponents.shift();
  var newPath = pathComponents.join('/');
  newPath = mediaBaseURL + newPath;
  var timestamp = new Date().getTime();
  var newMediaId = md5(timestamp+Math.random());
  mediaURLS[newMediaId] = newPath;
  console.log('saved IN MEDIA URLS: '+mediaURLS[newMediaId]);

  return newMediaId;
}

var rooms = new Set();

app.get(config.APIRoom+':id',function(req,res){
  console.log('got ID: '+req.params.id);
  var roomId = req.params.id;
  var roomExists = false;
  if (roomId in rooms) {
    roomExists = true;
  }
  else {
    roomExists = false;
  }

  setTimeout(function() {
    res.send({
      exists : roomExists
    });
  },1500);
  
});

app.post(config.APIRoom,function(req,res){
  var roomId = req.body.roomId;
  console.log('roomId to create: '+roomId);
  console.log(rooms);
  var roomCreated = true;

  if (roomId in rooms) {
    roomCreated = false;
    console.log('exists');
  }
  else {
    if (rooms.add(roomId) == true) {
      newRoom(roomId);
    }
    else {
      roomCreated = false;
    }
  }

  res.send({
    created : roomCreated
  });
});
