//
//  UIImage.h
//  CoDrawing
//
//  Created by Lukasz Czarnecki on 22.06.2014.
//  Copyright (c) 2014 Łukasz Czarnecki. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface UIImage (Resize)

- (UIImage *)scaleToSize:(CGSize)newSize;

@end
