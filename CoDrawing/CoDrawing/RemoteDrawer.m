//
//  RemoteDrawer.m
//  CoDrawing
//
//  Created by Łukasz Czarnecki on 03/11/13.
//  Copyright (c) 2013 Łukasz Czarnecki. All rights reserved.
//

#import "RemoteDrawer.h"

@implementation RemoteDrawer

- (id)initWithSuperView:(UIView *)superView
{
    self = [super init];
    if (!self) {
        return nil;
    }
    
    self.remoteDrawerImageView = [[UIImageView alloc] initWithFrame:superView.frame];
    self.remoteDrawerImageView.backgroundColor = [UIColor clearColor];
    [superView addSubview:self.remoteDrawerImageView];
    return self;
}

- (void)prepareToDelete
{
    [self.remoteDrawerImageView removeFromSuperview];
}

@end
