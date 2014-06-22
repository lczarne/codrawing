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

@end

@implementation RemoteDrawingSyncManager

- (id)init
{
    self = [super init];
    [self setupSocket];
    return self;
}

- (void)setupSocket
{
    self.socketIO = [[SocketIO alloc] initWithDelegate:self];
    [self.socketIO connectToHost:kBaseURL onPort:kServerPort];
    [self.socketIO sendMessage:@"Hello from iOS"];
    NSLog(@"message test done");
}

- (void)sendSocketControlEvent:(int)controlState
{
    NSDictionary *stateDict = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:controlState] forKey:@"value"];
    [self.socketIO sendEvent:@"control" withData:stateDict];
}

- (void)sendPaintEventWith:(CGPoint)socketPaintPoint state:(NSNumber *)state
{
    NSNumber* xNumber = [NSNumber numberWithFloat:socketPaintPoint.x];
    NSNumber* yNumber = [NSNumber numberWithFloat:socketPaintPoint.y];
    
    NSDictionary *paintPointDict = [NSDictionary dictionaryWithObjects:@[xNumber,yNumber] forKeys:@[@"x",@"y"]];
    NSDictionary *paintInfoToSend = [NSDictionary dictionaryWithObjects:@[paintPointDict, state] forKeys:@[@"paint",@"state"]];
    [self.socketIO sendEvent:@"paint" withData:paintInfoToSend];
}

- (void)sendImageEvent:(CGRect)imageRect imageURL:(NSString *)imageURL {
    NSDictionary *imageRectDict = @{
                                    @"x" : @(imageRect.origin.x),
                                    @"y" : @(imageRect.origin.y),
                                    @"width" : @(imageRect.size.width),
                                    @"height" : @(imageRect.size.height),
                                    };
    NSDictionary *imageEventDict = [NSDictionary dictionaryWithObjects:@[imageRectDict,imageURL] forKeys:@[@"imageInfo",@"imageURL"]];
    [self.socketIO sendEvent:@"image" withData:imageEventDict];
}

#pragma mark - SocketIODelegate

- (void)socketIODidConnect:(SocketIO *)socket
{
    NSLog(@"connected: %@",socket);
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
                else if ([eventName isEqualToString:@"drawingState"]){
                    [self.delegate remoteDrawingStateReceived:properData];
                }
                
            }

            
        }
    }
}

@end
