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
- (void)remoteDrawingStateReceived:(NSArray *)stateArray;
- (void)remoteImageStateReceived:(NSArray *)imageArray;

@end

//Amazon EC2 instance address
//static NSString* const kBaseURL = @"54.200.33.146";
static NSString* const kBaseURL = @"192.168.0.10";
static int const kServerPort = 8882;
static NSString* const kAPIURL = @"http://192.168.0.10:8882";
static NSString* const kAPIImageUploadPath = @"/api/images";

@interface RemoteDrawingSyncManager : NSObject

@property (nonatomic, strong) id<RemoteDrawingSyncManagerDelegate> delegate;

- (id)init;
- (void)sendSocketControlEvent:(int)controlState;
- (void)sendPaintEventWith:(CGPoint)socketPaintPoint state:(NSNumber *)state;
- (void)sendImageEvent:(CGRect)imageRect imageURL:(NSString *)imageURL;

@end
