var mongoose = require('mongoose');
var config = require('./config.js');
var rimraf = require('rimraf');
var fs = require('fs');

mongoose.connect(config.dbPath);
var db = mongoose.connection;
db.on('error',console.error.bind(console,'connection error:'));
db.once('open', function callback(){
  //clearDatabase();
  console.log('db connected!!!');
});

var clearDatabase = function() {
  mongoose.connection.db.dropDatabase();
}

//Event setup
var drawEventSchema = mongoose.Schema({
  drawEventId: Number,
  roomId: String,
  state: Number,
  eraser: Boolean,
  paint: {
    x: Number,
    y: Number
  }
});
drawEventSchema.path('drawEventId').index({unique: true});

drawEventSchema.methods.printMe = function(){
  console.log("Hi, my eventId = "+this.drawEventId);
};

var DrawEvent = mongoose.model('DrawEvent',drawEventSchema);

//ImageSetup
var imageSchema = mongoose.Schema({
  imageId: String,
  roomId: String,
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
  roomId: String,
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
var mediaFolderPath = config.staticWebPath+config.mediaPath;

function clearMediaState() {
  ImageMedia.remove({},function (err){
    console.log("Images collection cleared.")
  });
  VideoMedia.remove({},function (err){
    console.log("Video collection cleared.")
  });

  rimraf(mediaFolderPath,function(err){
    if (err) {
      console.log(err);
    }
    else {
      console.log('MEDIA removed')  
    }
    createTempMediaFolder();
  });
}

function clearDrawEventState() {
  DrawEvent.remove({},function (err){
    console.log("Events collection cleared.")
  });
}

function createTempMediaFolder() {
  fs.mkdir(mediaFolderPath, function(err){
    if (err) {
      console.log(err);
    }
    else {
      console.log('media folder created');
    }
  });
}

exports.drawEvent = DrawEvent;
exports.imageMedia = ImageMedia;
exports.videoMedia = VideoMedia;
exports.clearDrawEventState = clearDrawEventState;
exports.clearMediaState = clearMediaState; 
