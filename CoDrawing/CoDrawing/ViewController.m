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
#import "RemoteDrawer.h"

@interface ViewController () <UIScrollViewDelegate>

@property (nonatomic, strong) NSMutableDictionary *remoteDrawers;
@property (nonatomic, strong) RemoteDrawingSyncManager *remoteDrawingManager;
@property (nonatomic) BOOL start;
@property (nonatomic) BOOL painting;
@property (nonatomic) CGPoint lastPoint;

@end

@implementation ViewController 

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
    self.tempDrawingImageView.image = [clearImage copy];
    self.tempDrawingImageView.backgroundColor = [UIColor clearColor];
    self.drawingImageView.backgroundColor = [UIColor clearColor];
//    UIImage *image = [UIImage imageNamed:@"rondo.png"];
//    self.drawingImageView.image = image;
//    //self.tempDrawingImageView.image = image;
    
}

- (void)viewDidLoad
{
    self.remoteDrawingManager = [[RemoteDrawingSyncManager alloc] init];
    self.remoteDrawingManager.delegate = self;
    self.remoteDrawers = [[NSMutableDictionary alloc] initWithCapacity:10];
    self.drawingScrollView.contentSize = self.drawingImageView.frame.size;

    self.drawingScrollView.maximumZoomScale = 1.0;
    self.drawingScrollView.minimumZoomScale = 0.5;
    self.drawingScrollView.zoomScale = 1.0;
    
    self.drawingScrollView.delegate = self;
    

    red = 0.0/255.0;
    green = 0.0/255.0;
    blue = 0.0/255.0;
    brush = 2.0;
    opacity = 1.0;
    currentEventID = 0;
    
    [self clearDrawing:nil];
    
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    mouseSwiped = NO;
    UITouch *touch = [touches anyObject];
    [self.remoteDrawingManager sendPaintEventWith:[touch locationInView:self.drawingImageView] state:@0];
    self.lastPoint = [touch locationInView:self.drawingImageView];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{    
    mouseSwiped = YES;
    UITouch *touch = [touches anyObject];
    CGPoint nextPoint = [touch locationInView:self.drawingImageView];
    [self.remoteDrawingManager sendPaintEventWith:nextPoint state:@1];
    [self continueLineWithPoint:nextPoint lastPoint:self.lastPoint drawingImageView:self.tempDrawingImageView];
    self.lastPoint = nextPoint;
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    CGPoint endPoint = [touch locationInView:self.drawingImageView];
    [self.remoteDrawingManager sendPaintEventWith:endPoint state:@2];
}

- (void)startDrawingOnImageView:(UIImageView *)drawingImageView
{
    UIGraphicsBeginImageContextWithOptions(self.drawingImageView.frame.size, self.drawingImageView.opaque, 0.0);
    [drawingImageView.image drawInRect:CGRectMake(0, 0, self.drawingImageView.frame.size.width, self.drawingImageView.frame.size.height)];
}

- (void)continueLineWithPoint:(CGPoint)currentPoint lastPoint:(CGPoint)lastPoint drawingImageView:(UIImageView *)drawingImageView
{
    CGContextMoveToPoint(UIGraphicsGetCurrentContext(), lastPoint.x, lastPoint.y);
    CGContextAddLineToPoint(UIGraphicsGetCurrentContext(), currentPoint.x, currentPoint.y);
    CGContextSetLineCap(UIGraphicsGetCurrentContext(), kCGLineCapRound);
    CGContextSetLineWidth(UIGraphicsGetCurrentContext(), self.drawingScrollView.zoomScale*2 );
    CGContextSetRGBStrokeColor(UIGraphicsGetCurrentContext(), red, green, blue, 1.0);
    CGContextSetBlendMode(UIGraphicsGetCurrentContext(),kCGBlendModeNormal);
    
    CGContextStrokePath(UIGraphicsGetCurrentContext());
    drawingImageView.image = UIGraphicsGetImageFromCurrentImageContext();
    [drawingImageView setAlpha:opacity];
    //UIGraphicsEndImageContext();
}

- (void)finishLineWithLastPoint:(CGPoint)lastPoint DrawingImageView:(UIImageView *)drawingImageView
{
    if(!mouseSwiped) {
        UIGraphicsBeginImageContextWithOptions(self.drawingImageView.frame.size, self.drawingImageView.opaque, 0.0);
        [drawingImageView.image drawInRect:CGRectMake(0, 0, self.drawingImageView.frame.size.width, self.drawingImageView.frame.size.height)];
        CGContextSetLineCap(UIGraphicsGetCurrentContext(), kCGLineCapRound);
        CGContextSetLineWidth(UIGraphicsGetCurrentContext(), self.drawingScrollView.zoomScale*2);
        CGContextSetRGBStrokeColor(UIGraphicsGetCurrentContext(), red, green, blue, opacity);
        CGContextMoveToPoint(UIGraphicsGetCurrentContext(), lastPoint.x, lastPoint.y);
        CGContextAddLineToPoint(UIGraphicsGetCurrentContext(), lastPoint.x, lastPoint.y);
        CGContextStrokePath(UIGraphicsGetCurrentContext());
        CGContextFlush(UIGraphicsGetCurrentContext());
        drawingImageView.image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    }
    
    UIGraphicsBeginImageContextWithOptions(self.drawingImageView.frame.size, self.drawingImageView.opaque, 0.0);
    [self.drawingImageView.image drawInRect:CGRectMake(0, 0, self.drawingImageView.frame.size.width, self.drawingImageView.frame.size.height) blendMode:kCGBlendModeNormal alpha:1.0];
    [drawingImageView.image drawInRect:CGRectMake(0, 0, self.drawingImageView.frame.size.width, self.drawingImageView.frame.size.height) blendMode:kCGBlendModeNormal alpha:opacity];
    self.drawingImageView.image = UIGraphicsGetImageFromCurrentImageContext();
    drawingImageView.image = nil;
    UIGraphicsEndImageContext();
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - RemoteDrawingSyncManagerDelegate


- (void)remotePaintReceived:(NSDictionary *)paintEvent
{
    int identifier = [paintEvent[@"ID"] intValue];
    int state = [paintEvent[@"state"] intValue];
    NSDictionary *pointDict = paintEvent[@"paint"];
    CGPoint paintPoint = CGPointMake([pointDict[@"x"] floatValue]*self.drawingScrollView.zoomScale, [pointDict[@"y"] floatValue]*self.drawingScrollView.zoomScale);
    
    //RemoteDrawer *remoteDrawer = self.remoteDrawersImageViews
    NSNumber *remoteDrawerKey = [NSNumber numberWithInt:identifier];
    
    
    switch (state) {
        case 0:
            [self addNewRemoteDrawer:remoteDrawerKey point:paintPoint];
            break;
        case 1:
            [self drawWithRemoteDrawer:remoteDrawerKey point:paintPoint];
            break;
        case 2:
            [self finishRemoteDrawer:remoteDrawerKey point:paintPoint];
            break;
        default:
            break;
    }
}

- (void)addNewRemoteDrawer:(NSNumber *)remotedrawerID point:(CGPoint)startingPoint
{
    RemoteDrawer *drawer = self.remoteDrawers[remotedrawerID];
    if (!drawer) {
        drawer = [[RemoteDrawer alloc] initWithSuperView:self.drawingScrollView];
        [self startDrawingOnImageView:drawer.remoteDrawerImageView];
        [self.remoteDrawers setObject:drawer forKey:remotedrawerID];
    }
    drawer.lastPoint = startingPoint;
}

- (void)drawWithRemoteDrawer:(NSNumber *)remotedrawerID point:(CGPoint)nextPoint
{
    RemoteDrawer *drawer = self.remoteDrawers[remotedrawerID];
    if (drawer) {
        [self continueLineWithPoint:nextPoint lastPoint:drawer.lastPoint drawingImageView:drawer.remoteDrawerImageView];
        drawer.lastPoint = nextPoint;
    }
}

- (void)finishRemoteDrawer:(NSNumber *)remotedrawerID point:(CGPoint)nextPoint
{
    RemoteDrawer *drawer = self.remoteDrawers[remotedrawerID];
    if (drawer) {
        [self finishLineWithLastPoint:drawer.lastPoint DrawingImageView:drawer.remoteDrawerImageView];
        [self deleteDrawer:drawer forKey:remotedrawerID];
    }

}

- (void)deleteDrawer:(RemoteDrawer *)remoteDrawer forKey:(NSNumber *)remoteDrawerKey
{
    [remoteDrawer prepareToDelete];
    [self.remoteDrawers removeObjectForKey:remoteDrawerKey];
}

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView
{
    return self.drawingImageView;
}

@end
