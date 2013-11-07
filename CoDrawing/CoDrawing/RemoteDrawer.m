//
//  RemoteDrawer.m
//  CoDrawing
//
//  Created by Łukasz Czarnecki on 03/11/13.
//  Copyright (c) 2013 Łukasz Czarnecki. All rights reserved.
//

#import "RemoteDrawer.h"

@implementation RemoteDrawer

- (id)initWithSuperView:(UIScrollView *)superView
{
    self = [super init];
    if (!self) {
        return nil;
    }
    
    CGRect newFrame = CGRectMake(0, 0, superView.contentSize.width, superView.contentSize.height);
    
    self.remoteDrawerImageView = [[UIImageView alloc] initWithFrame:newFrame];
    self.remoteDrawerImageView.backgroundColor = [UIColor clearColor];
    [superView addSubview:self.remoteDrawerImageView];
    return self;
}

- (void)prepareToDelete
{
    [self.remoteDrawerImageView removeFromSuperview];
}

@end
