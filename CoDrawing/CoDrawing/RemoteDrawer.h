//
//  RemoteDrawer.h
//  CoDrawing
//
//  Created by Łukasz Czarnecki on 03/11/13.
//  Copyright (c) 2013 Łukasz Czarnecki. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface RemoteDrawer : NSObject

@property (nonatomic, strong) UIImageView *remoteDrawerImageView;
@property (nonatomic) CGPoint lastPoint;

- (id)initWithSuperView:(UIView *)superView;
- (void)prepareToDelete;

@end
