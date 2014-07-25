//
//  RemoteDrawingSyncManager.h
//  CoDrawing
//
//  Created by Łukasz Czarnecki on 10/19/13.
//  Copyright (c) 2013 Łukasz Czarnecki. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol RemoteDrawingSyncManagerDelegate

- (void)remotePaintReceived:(NSDictionary *)paintEvent;
- (void)remoteImageReceived:(NSDictionary *)imageEvent;
- (void)remoteVideoReceived:(NSDictionary *)videoEvent;
- (void)remoteDrawingStateReceived:(NSArray *)stateArray;
- (void)remoteImageStateReceived:(NSArray *)imageArray;
- (void)remoteVideoStateReceived:(NSArray *)videoArray;

@end

//Amazon EC2 instance address
//static NSString* const kBaseURL = @"54.76.227.228";
//static int const kServerPort = 80;
//static NSString* const kAPIURL = @"http://54.76.227.228";

//local
static NSString* const kBaseURL = @"192.168.0.10";
static int const kServerPort = 8080;
static NSString* const kAPIURL = @"http://192.168.0.10:8080";

static NSString* const kAPIImageUploadPath = @"/api/images";
static NSString* const kAPIVideoUploadPath = @"/api/videos";

@interface RemoteDrawingSyncManager : NSObject

@property (nonatomic, strong) id<RemoteDrawingSyncManagerDelegate> delegate;

- (id)init;
- (void)sendSocketControlEvent:(int)controlState;
- (void)sendPaintEventWith:(CGPoint)socketPaintPoint
                     state:(NSNumber *)state
                    erasing:(BOOL)erasing;
- (void)sendImageEvent:(CGRect)imageRect imageURL:(NSString *)imageURL;
- (void)sendVideoEvent:(CGRect)videoRect videoURL:(NSString *)videoURL;

@end
