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
#import <AFNetworking/AFNetworking.h>
#import <AFNetworking/UIImageView+AFNetworking.h>
#import "UIImage+Resize.h"
#import <MediaPlayer/MediaPlayer.h>
#import <AVFoundation/AVFoundation.h>
#import <VKVideoPlayer.h>

@interface ViewController () <UIScrollViewDelegate, UIActionSheetDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, VKVideoPlayerDelegate>

@property (nonatomic, strong) NSMutableDictionary *remoteDrawers;
@property (nonatomic, strong) RemoteDrawingSyncManager *remoteDrawingManager;
@property (nonatomic) BOOL start;
@property (nonatomic) BOOL painting;
@property (nonatomic) CGPoint lastPoint;
@property (nonatomic, strong) UIPanGestureRecognizer *drawingPanGesture;
@property (nonatomic, strong) UIPanGestureRecognizer *navgationPanGesture;
@property (nonatomic, strong) UIPanGestureRecognizer *mediaPanGesture;
@property (weak, nonatomic) IBOutlet UIButton *clearButton;
@property (weak, nonatomic) IBOutlet UIButton *navigationButton;
@property (weak, nonatomic) IBOutlet UIButton *drawingButton;
@property (weak, nonatomic) IBOutlet UIButton *mediaButton;
@property (nonatomic, strong) UIView *mediaSelectionView;
@property (nonatomic, strong) UIView *mediaSelectionResultView;
@property CGPoint mediaSelectionStartPoint;
@property (nonatomic, strong) MPMoviePlayerController *player;
@property (nonatomic, strong) NSMutableArray *moviePlayers;
@property CGRect videoPLayerOriginalFrame;
@property NSInteger videoPLayerIndex;

@end

@implementation ViewController 

CGFloat red;
CGFloat green;
CGFloat blue;
CGFloat brush;
CGFloat opacity;
int currentEventID;

BOOL mouseSwiped;
BOOL drawingMode = YES;


- (IBAction)clearDrawing:(id)sender {
    [self resetButtonColors];
    UIImage *clearImage = [[UIImage alloc] init];
    self.drawingImageView.image = clearImage;
    self.tempDrawingImageView.image = [clearImage copy];
    self.tempDrawingImageView.backgroundColor = [UIColor clearColor];
    self.drawingImageView.backgroundColor = [UIColor clearColor];
}

- (IBAction)navigationMode:(id)sender {
    [self resetButtonColors];
    [self resetGestureRecognizers];
}

- (IBAction)drawingMode:(id)sender {
    [self resetButtonColors];
    [self resetGestureRecognizers];
    [self.drawingScrollView addGestureRecognizer:self.drawingPanGesture];
    CGPoint offset = self.drawingScrollView.contentOffset;
    [self.drawingScrollView setContentOffset:offset animated:NO];
}

- (IBAction)mediaMode:(id)sender {
    [self resetGestureRecognizers];
    [self.drawingScrollView addGestureRecognizer:self.mediaPanGesture];
    [self resetButtonColors];
}

- (void)resetGestureRecognizers {
    [self.drawingScrollView removeGestureRecognizer:self.drawingPanGesture];
    [self.drawingScrollView removeGestureRecognizer:self.mediaPanGesture];
}

- (void)resetButtonColors {
    self.clearButton.titleLabel.textColor = [UIColor blueColor];
    self.navigationButton.titleLabel.textColor = [UIColor blueColor];
    self.drawingButton.titleLabel.textColor = [UIColor blueColor];
    self.mediaButton.titleLabel.textColor = [UIColor blueColor];
}

- (void)viewDidLoad
{
    [[UIApplication sharedApplication] setStatusBarHidden:YES];
    self.remoteDrawingManager = [[RemoteDrawingSyncManager alloc] init];
    self.remoteDrawingManager.delegate = self;
    self.remoteDrawers = [[NSMutableDictionary alloc] initWithCapacity:10];
    self.drawingScrollView.contentSize = self.drawingImageView.frame.size;

    self.drawingScrollView.maximumZoomScale = 1.0;
    self.drawingScrollView.minimumZoomScale = 0.5;
    self.drawingScrollView.zoomScale = 1.0;
    
    self.drawingScrollView.delegate = self;
    
    self.drawingPanGesture = [self setupDrawingGesture];
    [self.drawingScrollView addGestureRecognizer:self.drawingPanGesture];
    
    self.mediaPanGesture = [self setupMediaGesture];
    
    self.mediaSelectionView = [self setupMediaSelectionView];
    [self.zoomableView addSubview:self.mediaSelectionView];
    
    UITapGestureRecognizer *tapToZoom = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handelDoubleTap:)];
    tapToZoom.numberOfTapsRequired = 2;
    [self.drawingScrollView addGestureRecognizer:tapToZoom];

    red = 0.0/255.0;
    green = 0.0/255.0;
    blue = 0.0/255.0;
    brush = 2.0;
    opacity = 1.0;
    currentEventID = 0;
    
    [self setupInitialState];
    
    [super viewDidLoad];
}

- (void)setupInitialState {
    [self clearDrawing:nil];
    [self drawingMode:nil];
    [self.drawingButton setSelected:YES];
    self.moviePlayers = [NSMutableArray array];
}

- (UIPanGestureRecognizer *)setupDrawingGesture {
    UIPanGestureRecognizer *drawingGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(drawingScroll:)];
    drawingGesture.minimumNumberOfTouches = 1;
    drawingGesture.maximumNumberOfTouches = 1;
    return drawingGesture;
}

- (UIPanGestureRecognizer *)setupMediaGesture {
    UIPanGestureRecognizer *mediaGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(mediaAreaSelection:)];
    mediaGesture.minimumNumberOfTouches = 1;
    mediaGesture.maximumNumberOfTouches = 1;
    return mediaGesture;
}

- (UIView *)setupMediaSelectionView {
    UIView *mediaSelectionView = [[UIView alloc] init];
    mediaSelectionView.backgroundColor = [UIColor blueColor];
    mediaSelectionView.alpha = .25f;
    mediaSelectionView.hidden = YES;
    return mediaSelectionView;
}

- (void)drawingScroll:(UIPanGestureRecognizer *)gesture
{
    CGPoint touch = [gesture locationInView:self.drawingScrollView];
    touch.x /= self.drawingScrollView.zoomScale;
    touch.y /= self.drawingScrollView.zoomScale;
    if (gesture.state == UIGestureRecognizerStateBegan){
        [self drawingBegan:touch];
    }
    else if (gesture.state == UIGestureRecognizerStateChanged){
        [self drawingMoved:touch];
    }
    else if (gesture.state == UIGestureRecognizerStateEnded){
        [self drawingEnded:touch];
    }
}

- (void)mediaAreaSelection:(UIPanGestureRecognizer *)gesture {
    CGPoint touch = [gesture locationInView:self.drawingScrollView];
    touch.x /= self.drawingScrollView.zoomScale;
    touch.y /= self.drawingScrollView.zoomScale;
    if (gesture.state == UIGestureRecognizerStateBegan){
        self.mediaSelectionStartPoint = touch;
        self.mediaSelectionView.frame = CGRectMake(touch.x, touch.y, 0, 0);
        self.mediaSelectionView.hidden = NO;
    }
    else if (gesture.state == UIGestureRecognizerStateChanged){
        CGFloat minX = MIN(self.mediaSelectionStartPoint.x, touch.x);
        CGFloat minY = MIN(self.mediaSelectionStartPoint.y, touch.y);
        CGFloat maxX = MAX(self.mediaSelectionStartPoint.x, touch.x);
        CGFloat maxY = MAX(self.mediaSelectionStartPoint.y, touch.y);

        
        CGRect leftTop = CGRectMake(minX, minY, 0, 0);
        CGRect rightBottom = CGRectMake(maxX, maxY, 0, 0);
        CGRect selectionRect = CGRectUnion(leftTop, rightBottom);
        
        self.mediaSelectionView.frame = selectionRect;
    }
    else if (gesture.state == UIGestureRecognizerStateEnded){
        [self showMediaActionSheet];
    }
}

- (void)showMediaActionSheet {
    UIActionSheet *mediaActionSheet = [[UIActionSheet alloc] initWithTitle:@"Media choice"
                                                                  delegate:self
                                                         cancelButtonTitle:@"Cancel"
                                                    destructiveButtonTitle:nil
                                                         otherButtonTitles:@"Image",@"Video URL",@"Other URL", nil];
                                                        
    [mediaActionSheet showInView:self.view];
}

-(void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    switch (buttonIndex) {
        case 0: {
         NSLog(@"image");
         [self chooseImage];
         [self showNewMediaView];
        }
        break;
        case 1: {
         NSLog(@"video");
         [self showNewMediaView];
        }
        break;
        case 2: {
         NSLog(@"URL");
         [self showNewMediaView];
        }
        break;
        case 3: {
         NSLog(@"Cancel");
        }
        break;
    }
    
    self.mediaSelectionView.hidden = YES;
}


- (void)showNewMediaView {
    [self.allMediaView addSubview:self.mediaSelectionResultView];
}

- (void)chooseImage {
    UIImagePickerController *imagePicker = [[UIImagePickerController alloc] init];
    imagePicker.delegate = self;

    if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary]) {
        imagePicker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
        imagePicker.mediaTypes = [UIImagePickerController availableMediaTypesForSourceType:UIImagePickerControllerSourceTypePhotoLibrary];
    }
    else if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
        imagePicker.sourceType = UIImagePickerControllerSourceTypeCamera;
        imagePicker.mediaTypes = [UIImagePickerController availableMediaTypesForSourceType:UIImagePickerControllerSourceTypeCamera];
    }
    
    [self presentViewController:imagePicker animated:YES completion:^{
        
    }];
}

- (void)handelDoubleTap:(UITapGestureRecognizer *)gesture
{
    if(self.drawingScrollView.zoomScale > self.drawingScrollView.minimumZoomScale){
        [self.drawingScrollView setZoomScale:self.drawingScrollView.minimumZoomScale animated:YES];
    }
    else {
        CGPoint touch = [gesture locationInView:self.drawingImageView];
        CGSize scrollViewSize = self.drawingScrollView.bounds.size;
        
        CGFloat w = scrollViewSize.width / self.drawingScrollView.maximumZoomScale;
        CGFloat h = scrollViewSize.height / self.drawingScrollView.maximumZoomScale;
        CGFloat x = touch.x - (w/2);
        CGFloat y = touch.y - (h/2);
        
        CGRect rectTozoom=CGRectMake(x, y, w, h);

        [self.drawingScrollView zoomToRect:rectTozoom animated:YES];
    }
}

- (void)drawingBegan:(CGPoint)touch
{
    mouseSwiped = NO;
    [self.remoteDrawingManager sendPaintEventWith:touch state:@0];
    self.lastPoint = touch;
    [self startDrawingOnImageView:self.tempDrawingImageView];
}

- (void)drawingMoved:(CGPoint)touch
{    
    mouseSwiped = YES;
    [self.remoteDrawingManager sendPaintEventWith:touch state:@1];
    [self continueLineWithPoint:touch lastPoint:self.lastPoint drawingImageView:self.tempDrawingImageView];
    self.lastPoint = touch;
}

- (void)drawingEnded:(CGPoint)touch
{
    [self.remoteDrawingManager sendPaintEventWith:touch state:@2];
    [self finishLineWithLastPoint:touch DrawingImageView:self.tempDrawingImageView];
}

- (void)startDrawingOnImageView:(UIImageView *)drawingImageView
{
    //UIGraphicsBeginImageContextWithOptions(self.drawingImageView.frame.size, self.drawingImageView.opaque, 0.0);
    UIGraphicsBeginImageContext(self.drawingImageView.frame.size);
}

- (void)continueLineWithPoint:(CGPoint)currentPoint lastPoint:(CGPoint)lastPoint drawingImageView:(UIImageView *)drawingImageView
{
    @autoreleasepool {
        CGContextRef context = UIGraphicsGetCurrentContext();
        CGContextMoveToPoint(context, lastPoint.x, lastPoint.y);
        CGContextAddLineToPoint(context, currentPoint.x, currentPoint.y);
        CGContextSetLineCap(context, kCGLineCapRound);
        CGContextSetLineWidth(context, self.drawingScrollView.zoomScale*2 );
        CGContextSetRGBStrokeColor(context, red, green, blue, 1.0);
        CGContextSetBlendMode(context, kCGBlendModeNormal);

        CGContextStrokePath(context);

        drawingImageView.image = UIGraphicsGetImageFromCurrentImageContext();
    }
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
    int identifier = [paintEvent[@"socketID"] intValue];
    int state = [paintEvent[@"state"] intValue];
    NSDictionary *pointDict = paintEvent[@"paint"];
    CGPoint paintPoint = CGPointMake([pointDict[@"x"] floatValue], [pointDict[@"y"] floatValue]);
    
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

- (void)remoteImageReceived:(NSDictionary *)imageEvent {
    NSDictionary *imageInfo = imageEvent[@"imageInfo"];
    NSString *imageURL = imageEvent[@"imageURL"];
    CGPoint imageOrigin = CGPointMake([imageInfo[@"x"] floatValue], [imageInfo[@"y"] floatValue]);
    CGSize imageSize = CGSizeMake([imageInfo[@"width"] floatValue], [imageInfo[@"height"] floatValue]);
    CGRect imageRect = CGRectMake(imageOrigin.x, imageOrigin.y, imageSize.width, imageSize.height);
    
    [self addImageWithURL:imageURL imageRect:imageRect];
}

- (void)addImageWithURL:(NSString *)imageURLString imageRect:(CGRect)imageRect {
    UIImageView *newImageView = [[UIImageView alloc] initWithFrame:imageRect];
    [self.allMediaView addSubview:newImageView];

    __weak UIImageView *weakImageView = newImageView;
    
    NSURL *imageURL = [NSURL URLWithString:imageURLString];
    NSURLRequest *imageRequest = [NSURLRequest requestWithURL:imageURL];
    
    [newImageView setImageWithURLRequest:imageRequest placeholderImage:nil success:^(NSURLRequest *request, NSHTTPURLResponse *response, UIImage *image) {
        weakImageView.alpha = 0.0;
        weakImageView.image = image;
        [UIView animateWithDuration:0.75
                         animations:^{
                            weakImageView.alpha = 1.0;
                        }];
    } failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error) {
    }];
}

- (void)remoteDrawingStateReceived:(NSArray *)stateArray {
    for (NSDictionary *paintEvent in stateArray) {
        [self remotePaintReceived:paintEvent];
    }
}

- (void)remoteImageStateReceived:(NSArray *)imageArray {
    for (NSDictionary *imageMedia in imageArray) {
        [self remoteImageReceived:imageMedia];
    }
}

- (void)addNewRemoteDrawer:(NSNumber *)remotedrawerID point:(CGPoint)startingPoint
{
    RemoteDrawer *drawer = self.remoteDrawers[remotedrawerID];
    if (!drawer) {
        drawer = [[RemoteDrawer alloc] initWithSuperView:self.drawingScrollView.subviews[0]];
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
    return scrollView.subviews[0];
}

- (BOOL)shouldAutorotate {
    return YES;
}

- (NSUInteger)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskLandscape;
}

- (void)didPickMovie:(NSString *)moviePath {
    NSURL *movieURL = [NSURL fileURLWithPath:moviePath];

    VKVideoPlayer *player = [[VKVideoPlayer alloc] init];
    player.view.frame = self.mediaSelectionView.frame;
    player.delegate = self;
    
    VKVideoPlayerTrack *track = [[VKVideoPlayerTrack alloc] initWithStreamURL:movieURL];
    
    [self.moviePlayers addObject:player];
    self.player.view.frame = self.mediaSelectionView.frame;
    [self.allMediaView addSubview:player.view];
    
    [player.view removeControlView:player.view.rewindButton];
    [player.view removeControlView:player.view.doneButton];
    [player.view removeControlView:player.view.nextButton];
    [player.view removeControlView:player.view.videoQualityButton];
    [player.view addSubviewForControl:player.view.fullscreenButton];
    
    [player loadVideoWithTrack:track];
    [player playContent];
}


- (void)didPickImage:(UIImage *)imagePicked {
    UIImageView *mediaResultImageView = [[UIImageView alloc] initWithFrame:self.mediaSelectionView.frame];
    UIImage *chosenImageScaled = [imagePicked scaleToSize:mediaResultImageView.frame.size];
    
    mediaResultImageView.image = chosenImageScaled;
    mediaResultImageView.backgroundColor = [UIColor yellowColor];
    self.mediaSelectionResultView = mediaResultImageView;
    [self showNewMediaView];
    [self uploadImage:chosenImageScaled withImageRect:mediaResultImageView.frame];
}

- (void)uploadImage:(UIImage *)imageToUpload withImageRect:(CGRect)imageRect{
    AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
    NSData *imageData = UIImagePNGRepresentation(imageToUpload);
    NSDictionary *parameters = @{@"foo": @"bar"};
    NSString *URLString = [kAPIURL stringByAppendingString:kAPIImageUploadPath];
    
    [manager POST:URLString parameters:parameters constructingBodyWithBlock:^(id<AFMultipartFormData> formData) {
        [formData appendPartWithFileData:imageData name:@"myImage" fileName:@"userImage.png" mimeType:@"image/png"];
        
    } success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSLog(@"AF Success: %@", responseObject);
        NSString *imageURLString = responseObject[@"path"];
        [self.remoteDrawingManager sendImageEvent:imageRect imageURL:imageURLString];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"AF Error: %@", error);
    }];
}

- (void)imagePickerController:(UIImagePickerController *) Picker didFinishPickingMediaWithInfo:(NSDictionary *)info {

    NSString *mediaType = [info objectForKey: UIImagePickerControllerMediaType];
    UIImage *originalImage, *editedImage, *imageToUse;
    if (CFStringCompare ((CFStringRef) mediaType, kUTTypeImage, 0)
        == kCFCompareEqualTo) {
        editedImage = (UIImage *) [info objectForKey:
                                   UIImagePickerControllerEditedImage];
        originalImage = (UIImage *) [info objectForKey:
                                     UIImagePickerControllerOriginalImage];
        
        if (editedImage) {
            imageToUse = editedImage;
        } else {
            imageToUse = originalImage;
        }
        [self dismissViewControllerAnimated:YES completion:^{
        }];
        [self didPickImage:imageToUse];
    }
    
    if (CFStringCompare ((CFStringRef) mediaType, kUTTypeMovie, 0)
        == kCFCompareEqualTo) {
        
        NSString *moviePath = [[info objectForKey:
                                UIImagePickerControllerMediaURL] path];
        
        [self dismissViewControllerAnimated:YES completion:^{
        }];
        [self didPickMovie:moviePath];
    }

    
}

- (void)videoPlayer:(VKVideoPlayer *)videoPlayer didControlByEvent:(VKVideoPlayerControlEvent)event {
    if (event == VKVideoPlayerControlEventTapFullScreen) {
        if (videoPlayer.isFullScreen) {
            self.videoPLayerOriginalFrame = videoPlayer.view.frame;
            videoPlayer.view.frame = self.view.bounds;
            [self.view addSubview:videoPlayer.view];
            for (UIView *subview in self.allMediaView.subviews) {
                subview.hidden = YES;
            }
            self.videoPLayerIndex = [self.allMediaView.subviews indexOfObject:videoPlayer.view];
            self.drawingImageView.hidden = YES;
            videoPlayer.view.hidden = NO;
        }
        else {
            videoPlayer.view.frame = self.videoPLayerOriginalFrame;
            for (UIView *subview in self.allMediaView.subviews) {
                subview.hidden = NO;
            }
            self.drawingImageView.hidden = NO;
            [self.allMediaView insertSubview:videoPlayer.view atIndex:self.videoPLayerIndex];
            
        }
    }
}

@end
