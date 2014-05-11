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
    NSString *socketHostString = @"54.200.33.146";
    int port = 80;
    self.socketIO = [[SocketIO alloc] initWithDelegate:self];
    [self.socketIO connectToHost:socketHostString onPort:port];
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
            NSDictionary *properData = arguments[0];
            
            NSString *eventName = [dataReceived objectForKey:@"name"];
            
            if (eventName) {
                
                if ([eventName isEqualToString:@"serverPaint"]) {
                    
                    //temp - new way
                    [self.delegate remotePaintReceived:properData];
                    
//                    NSDictionary *paintDict = properData[@"paint"];
//                    
//                    CGPoint paintPoint = CGPointZero;
//                    NSNumber *paintXNumber = [paintDict objectForKey:@"x"];
//                    NSNumber *paintYNumber = [paintDict objectForKey:@"y"];
//                    
//                    if (paintXNumber && paintYNumber) {
//                        paintPoint.x = paintXNumber.intValue;
//                        paintPoint.y = paintYNumber.intValue;
//                        [self.delegate remoteDrawingPaintPointReceived:paintPoint];
//                    }
                }
//                else if ([eventName isEqualToString:@"serverControl"]){
//                    NSNumber *receivedControlState = [properData objectForKey:@"value"];
//                    if (receivedControlState) {
//                        [self.delegate remoteDrawingControlStateReceived:receivedControlState.intValue];
//                    }
//                }
                
            }

            
        }
    }
}

@end
