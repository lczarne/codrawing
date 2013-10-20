//
//  ViewController.m
//  CoDrawing
//
//  Created by Łukasz Czarnecki on 9/25/13.
//  Copyright (c) 2013 Łukasz Czarnecki. All rights reserved.
//

#import "ViewController.h"
#import "EditingEvent.h"
#import "RemoteDrawingSyncManager.h"

@interface ViewController ()

@property (nonatomic, strong) NSMutableArray *drawPointsArray;
@property (nonatomic, strong) NSMutableArray *eventsArray;
@property (nonatomic, strong) RemoteDrawingSyncManager *remoteDrawingManager;
@property (nonatomic) BOOL start;
@property (nonatomic) BOOL painting;

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
    self.remoteDrawingManager = [[RemoteDrawingSyncManager alloc] init];
    self.remoteDrawingManager.delegate = self;
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

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    mouseSwiped = NO;
    [self.remoteDrawingManager sendSocketControlEvent:1];
    //UITouch *touch = [touches anyObject];
    //[self startLineWithPoint:[touch locationInView:self.view]];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{    
    mouseSwiped = YES;
    UITouch *touch = [touches anyObject];    
    [self.remoteDrawingManager sendSocketPaint:[touch locationInView:self.view]];
//    [self continueLineWithPoint:[touch locationInView:self.view]];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self.remoteDrawingManager sendSocketControlEvent:0];
}

- (void)startLineWithPoint:(CGPoint)startPoint
{
    lastPoint = startPoint;
    [self.drawPointsArray addObject:[NSValue valueWithCGPoint:lastPoint]];
}

- (void)continueLineWithPoint:(CGPoint)currentPoint
{
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

- (void)finishLine
{
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

#pragma mark - RemoteDrawingSyncManagerDelegate

- (void)remoteDrawingControlStateReceived:(int)controlState
{
    self.painting = controlState;
    if (controlState == 1) {
        self.start = YES;
    }
    else if (controlState == 0){
        [self finishLine];
    }
}

-(void)remoteDrawingPaintPointReceived:(CGPoint)pointReceived
{
    if (self.painting) {
        if (self.start) {
            self.start = NO;
            [self startLineWithPoint:pointReceived];
        }
        else {
            [self continueLineWithPoint:pointReceived];
        }
    }
}

@end
