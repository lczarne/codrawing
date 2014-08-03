//
//  RemoteDrawingSyncManager.m
//  CoDrawing
//
//  Created by Łukasz Czarnecki on 10/19/13.
//  Copyright (c) 2013 Łukasz Czarnecki. All rights reserved.
//

#import "RemoteDrawingSyncManager.h"
#import "SocketIO.h"
#import "SocketIOPacket.h"

@interface RemoteDrawingSyncManager () <SocketIODelegate>

@property (nonatomic, strong) SocketIO *socketIO;
@property (nonatomic, strong) NSString *roomId;

@end

@implementation RemoteDrawingSyncManager

- (id)initWithRoomId:(NSString *)roomId;
{
    self = [super init];
    if (self) {
        _roomId = roomId;
        [self setupSocket];
    }
    return self;
}

- (void)setupSocket
{
    self.socketIO = [[SocketIO alloc] initWithDelegate:self];
    [self.socketIO connectToHost:kBaseURL onPort:kServerPort];
    [self.socketIO sendMessage:@"Hello from iOS"];
    NSLog(@"message test done");
}

- (void)sendJoinRoomEvent {
    if (self.roomId) {
        NSDictionary *roomDict = @{@"roomId":self.roomId};
        [self.socketIO sendEvent:@"joinRoom" withData:roomDict];
    }
}

- (void)leaveRoom {
    [self.socketIO disconnect];
}

- (void)sendPaintEventWith:(CGPoint)socketPaintPoint
                     state:(NSNumber *)state
                   erasing:(BOOL)erasing {
    NSNumber* xNumber = [NSNumber numberWithFloat:socketPaintPoint.x];
    NSNumber* yNumber = [NSNumber numberWithFloat:socketPaintPoint.y];
    
    NSDictionary *paintPointDict = [NSDictionary dictionaryWithObjects:@[xNumber,yNumber] forKeys:@[@"x",@"y"]];
    NSDictionary *paintInfoToSend = [NSDictionary dictionaryWithObjects:@[paintPointDict, state, @(erasing)] forKeys:@[@"paint",@"state",@"eraser"]];
    [self.socketIO sendEvent:@"paint" withData:paintInfoToSend];
}

- (void)sendImageEvent:(CGRect)imageRect imageId:(NSString *)imageId {
    NSDictionary *imageRectDict = @{
                                    @"x" : @(imageRect.origin.x),
                                    @"y" : @(imageRect.origin.y),
                                    @"width" : @(imageRect.size.width),
                                    @"height" : @(imageRect.size.height),
                                    };
    NSDictionary *imageEventDict = [NSDictionary dictionaryWithObjects:@[imageRectDict,imageId] forKeys:@[@"imageInfo",@"imageId"]];
    [self.socketIO sendEvent:@"image" withData:imageEventDict];
}

- (void)sendVideoEvent:(CGRect)videoRect videoId:(NSString *)videoId {
    NSDictionary *videoRectDict = @{
                                    @"x" : @(videoRect.origin.x),
                                    @"y" : @(videoRect.origin.y),
                                    @"width" : @(videoRect.size.width),
                                    @"height" : @(videoRect.size.height),
                                    };
    NSDictionary *videoEventDict = [NSDictionary dictionaryWithObjects:@[videoRectDict,videoId] forKeys:@[@"videoInfo",@"videoId"]];
    [self.socketIO sendEvent:@"video" withData:videoEventDict];
}

- (void)sendDeleteMediaEvent:(NSString *)mediaId {
    NSDictionary *mediaDeleteEvent = [NSDictionary dictionaryWithObject:mediaId forKey:@"mediaId"];
    [self.socketIO sendEvent:@"mediaDelete" withData:mediaDeleteEvent];
}

#pragma mark - SocketIODelegate

- (void)socketIODidConnect:(SocketIO *)socket
{
    NSLog(@"connected: %@",socket);
    [self sendJoinRoomEvent];
}

- (void)socketIO:(SocketIO *)socket didReceiveEvent:(SocketIOPacket *)packet
{
    NSLog(@"packet received: %@",[packet dataAsJSON]);
    NSDictionary *dataReceived = [packet dataAsJSON];
    if ([dataReceived isKindOfClass:[NSDictionary class]]) {
        NSArray *arguments = [dataReceived objectForKey:@"args"];
        if ([arguments isKindOfClass:[NSArray class]] && arguments.count >0) {
            id properData = arguments[0];
            
            NSString *eventName = [dataReceived objectForKey:@"name"];
            
            if (eventName) {
                
                if ([eventName isEqualToString:@"serverPaint"]) {
                    [self.delegate remotePaintReceived:properData];
                }
                else if ([eventName isEqualToString:@"serverImage"]){
                    [self.delegate remoteImageReceived:properData];
                }
                else if ([eventName isEqualToString:@"serverVideo"]){
                    [self.delegate remoteVideoReceived:properData];
                }
                else if ([eventName isEqualToString:@"serverMediaDelete"]){
                    [self.delegate remoteMediaDeleteReceived:properData];
                }
                else if ([eventName isEqualToString:@"drawingState"]){
                    [self.delegate remoteDrawingStateReceived:properData];
                }
                else if ([eventName isEqualToString:@"imageState"]){
                    [self.delegate remoteImageStateReceived:properData];
                }
                else if ([eventName isEqualToString:@"videoState"]){
                    [self.delegate remoteVideoStateReceived:properData];
                }
                else if ([eventName isEqualToString:@"joinedRoom"]){
                    [self.delegate remoteJoinedRoomApproval:properData];
                }
            }
            
        }
    }
}

@end
