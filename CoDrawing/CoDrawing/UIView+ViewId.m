//
//  UIView+ViewId.m
//  CoDrawing
//
//  Created by Lukasz Czarnecki on 27.07.2014.
//  Copyright (c) 2014 Łukasz Czarnecki. All rights reserved.
//

#import "UIView+ViewId.h"
#import <objc/runtime.h>

static void * viewIdProperty = &viewIdProperty;

@implementation UIView (ViewId)

- (NSString *)viewId {
    return objc_getAssociatedObject(self, viewIdProperty);
}

- (void)setViewId:(NSString *)viewId {
    objc_setAssociatedObject(self, viewIdProperty, viewId, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
