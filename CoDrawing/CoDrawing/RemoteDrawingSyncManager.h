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
- (void)remoteDrawingStateReceived:(NSArray *)stateArray;

@end

@interface RemoteDrawingSyncManager : NSObject

@property (nonatomic, strong) id<RemoteDrawingSyncManagerDelegate> delegate;

- (id)init;
- (void)sendSocketControlEvent:(int)controlState;
- (void)sendPaintEventWith:(CGPoint)socketPaintPoint state:(NSNumber *)state;

@end
