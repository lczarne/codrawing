//
//  ViewController.h
//  CoDrawing
//
//  Created by Łukasz Czarnecki on 9/25/13.
//  Copyright (c) 2013 Łukasz Czarnecki. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "RemoteDrawingSyncManager.h"

@interface ViewController : UIViewController <RemoteDrawingSyncManagerDelegate>
@property (weak, nonatomic) IBOutlet UIImageView *drawingImageView;
@property (weak, nonatomic) IBOutlet UIImageView *tempDrawingImageView;
@property (weak, nonatomic) IBOutlet UIScrollView *drawingScrollView;
@property (weak, nonatomic) IBOutlet UIView *zoomableView;
@property (weak, nonatomic) IBOutlet UIView *allMediaView;

@end
