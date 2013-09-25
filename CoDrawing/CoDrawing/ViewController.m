//
//  ViewController.m
//  CoDrawing
//
//  Created by Łukasz Czarnecki on 9/25/13.
//  Copyright (c) 2013 Łukasz Czarnecki. All rights reserved.
//

#import "ViewController.h"
#import "EditingEvent.h"

@interface ViewController ()

@property (nonatomic, strong) NSMutableArray *drawPointsArray;
@property (nonatomic, strong) NSMutableArray *eventsArray;

@end

@implementation ViewController

CGPoint lastPoint;
CGFloat red;
CGFloat green;
CGFloat blue;
CGFloat brush;
CGFloat opacity;
int currentEventID;

BOOL mouseSwiped;

- (IBAction)clearDrawing:(id)sender {
    
    UIImage *clearImage = [[UIImage alloc] init];
    self.drawingImageView.image = clearImage;
    self.tempDrawingImageView.image = clearImage;
    self.drawPointsArray = [[NSMutableArray alloc] init];
    self.eventsArray = [[NSMutableArray alloc] init];
}

- (void)viewDidLoad
{
    red = 0.0/255.0;
    green = 0.0/255.0;
    blue = 0.0/255.0;
    brush = 10.0;
    opacity = 1.0;
    currentEventID = 0;
    
    [self clearDrawing:nil];
    
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    
    mouseSwiped = NO;
    UITouch *touch = [touches anyObject];
    lastPoint = [touch locationInView:self.view];
    
    [self.drawPointsArray addObject:[NSValue valueWithCGPoint:lastPoint]];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    
    mouseSwiped = YES;
    UITouch *touch = [touches anyObject];
    CGPoint currentPoint = [touch locationInView:self.view];
    
    [self.drawPointsArray addObject:[NSValue valueWithCGPoint:currentPoint]];
    
    UIGraphicsBeginImageContext(self.view.frame.size);
    [self.tempDrawingImageView.image drawInRect:CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height)];
    CGContextMoveToPoint(UIGraphicsGetCurrentContext(), lastPoint.x, lastPoint.y);
    CGContextAddLineToPoint(UIGraphicsGetCurrentContext(), currentPoint.x, currentPoint.y);
    CGContextSetLineCap(UIGraphicsGetCurrentContext(), kCGLineCapRound);
    CGContextSetLineWidth(UIGraphicsGetCurrentContext(), brush );
    CGContextSetRGBStrokeColor(UIGraphicsGetCurrentContext(), red, green, blue, 1.0);
    CGContextSetBlendMode(UIGraphicsGetCurrentContext(),kCGBlendModeNormal);
    
    CGContextStrokePath(UIGraphicsGetCurrentContext());
    self.tempDrawingImageView.image = UIGraphicsGetImageFromCurrentImageContext();
    [self.tempDrawingImageView setAlpha:opacity];
    UIGraphicsEndImageContext();
    
    lastPoint = currentPoint;
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    
    if(!mouseSwiped) {
        UIGraphicsBeginImageContext(self.view.frame.size);
        [self.tempDrawingImageView.image drawInRect:CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height)];
        CGContextSetLineCap(UIGraphicsGetCurrentContext(), kCGLineCapRound);
        CGContextSetLineWidth(UIGraphicsGetCurrentContext(), brush);
        CGContextSetRGBStrokeColor(UIGraphicsGetCurrentContext(), red, green, blue, opacity);
        CGContextMoveToPoint(UIGraphicsGetCurrentContext(), lastPoint.x, lastPoint.y);
        CGContextAddLineToPoint(UIGraphicsGetCurrentContext(), lastPoint.x, lastPoint.y);
        CGContextStrokePath(UIGraphicsGetCurrentContext());
        CGContextFlush(UIGraphicsGetCurrentContext());
        self.tempDrawingImageView.image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    }
    
    UIGraphicsBeginImageContext(self.drawingImageView.frame.size);
    [self.drawingImageView.image drawInRect:CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height) blendMode:kCGBlendModeNormal alpha:1.0];
    [self.tempDrawingImageView.image drawInRect:CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height) blendMode:kCGBlendModeNormal alpha:opacity];
    self.drawingImageView.image = UIGraphicsGetImageFromCurrentImageContext();
    self.tempDrawingImageView.image = nil;
    UIGraphicsEndImageContext();
    
    [self finishDrawingEvent];
    
    
}

- (void)finishDrawingEvent
{
    EditingEvent *newEvent = [[EditingEvent alloc] init];
    newEvent.eventObject = self.drawPointsArray;
    newEvent.eventType = 0;
    newEvent.identifier = currentEventID;
    
    [self.eventsArray addObject:newEvent];
    
    currentEventID++;
    self.drawPointsArray = [[NSMutableArray alloc] init];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
