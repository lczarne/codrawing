//
//  UIImage.m
//  CoDrawing
//
//  Created by Lukasz Czarnecki on 22.06.2014.
//  Copyright (c) 2014 Łukasz Czarnecki. All rights reserved.
//

#import "UIImage+Resize.h"

@implementation UIImage (Resize)

- (UIImage *)scaleToSize:(CGSize)newSize {
    UIGraphicsBeginImageContextWithOptions(newSize, NO, self.scale);
    [self drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
}

@end
