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
- (void)remoteMediaDeleteReceived:(NSDictionary *)mediaDeleteEvent;
- (void)remoteDrawingStateReceived:(NSArray *)stateArray;
- (void)remoteImageStateReceived:(NSArray *)imageArray;
- (void)remoteVideoStateReceived:(NSArray *)videoArray;
- (void)remoteJoinedRoomApproval:(NSDictionary *)roomDict;

@end

//Amazon EC2 instance address
//static NSString* const kBaseURL = @"54.76.227.228";
//static int const kServerPort = 80;
//static NSString* const kAPIURL = @"http://54.76.227.228";

//local
//static NSString* const kBaseURL = @"192.168.0.10";
//static int const kServerPort = 8080;
//static NSString* const kAPIURL = @"http://192.168.0.10:8080";


static NSString* const kBaseURL = @"192.168.0.105";
static int const kServerPort = 8080;
static NSString* const kAPIURL = @"http://192.168.0.105:8080";


static NSString* const kAPIImageUploadPath = @"/api/images/";
static NSString* const kAPIVideoUploadPath = @"/api/videos/";
static NSString* const kAPIRoomPath = @"/api/room/";

@interface RemoteDrawingSyncManager : NSObject

@property (nonatomic, strong) id<RemoteDrawingSyncManagerDelegate> delegate;

- (id)initWithRoomId:(NSString *)roomId;
- (void)leaveRoom;
- (void)sendPaintEventWith:(CGPoint)socketPaintPoint
                     state:(NSNumber *)state
                    erasing:(BOOL)erasing;
- (void)sendImageEvent:(CGRect)imageRect imageId:(NSString *)imageId;
- (void)sendVideoEvent:(CGRect)videoRect videoId:(NSString *)videoId;
- (void)sendDeleteMediaEvent:(NSString *)mediaId;

@end
