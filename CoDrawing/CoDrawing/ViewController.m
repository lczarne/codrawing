//
//  ViewController.m
//  CoDrawing
//
//  Created by Łukasz Czarnecki on 9/25/13.
//  Copyright (c) 2013 Łukasz Czarnecki. All rights reserved.
//

#import "ViewController.h"
#import "RemoteDrawingSyncManager.h"
#import "RemoteDrawer.h"
#import <AFNetworking/AFNetworking.h>
#import <AFNetworking/UIImageView+AFNetworking.h>
#import "UIImage+Resize.h"
#import <MediaPlayer/MediaPlayer.h>
#import <AVFoundation/AVFoundation.h>
#import <VKVideoPlayer.h>
#import "UIView+ViewId.h"
#import <MBProgressHUD/MBProgressHUD.h>

@interface ViewController () <UIScrollViewDelegate, UIActionSheetDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, VKVideoPlayerDelegate>

@property (nonatomic, strong) NSMutableDictionary *remoteDrawers;
@property (nonatomic, strong) RemoteDrawingSyncManager *remoteDrawingManager;
@property (nonatomic) BOOL start;
@property (nonatomic) BOOL painting;
@property (nonatomic) CGPoint lastPoint;
@property (nonatomic, strong) UIPanGestureRecognizer *drawingPanGesture;
@property (nonatomic, strong) UIPanGestureRecognizer *navgationPanGesture;
@property (nonatomic, strong) UIPanGestureRecognizer *mediaPanGesture;
@property (nonatomic, strong) UILongPressGestureRecognizer *longPressGesture;
@property (weak, nonatomic) IBOutlet UIView *menuView;
@property (weak, nonatomic) IBOutlet UIButton *navigationButton;
@property (weak, nonatomic) IBOutlet UIButton *drawingButton;
@property (weak, nonatomic) IBOutlet UIButton *mediaButton;
@property (weak, nonatomic) IBOutlet UIButton *eraseButton;
@property (nonatomic, strong) UIView *mediaSelectionView;
@property (nonatomic, strong) UIView *mediaSelectionResultView;
@property (nonatomic, strong) UIView *deleteMediaSelectionView;
@property CGPoint mediaSelectionStartPoint;
@property (nonatomic, strong) MPMoviePlayerController *player;
@property (nonatomic, strong) NSMutableArray *moviePlayers;
@property CGRect videoPLayerOriginalFrame;
@property NSInteger videoPLayerIndex;
@property (nonatomic, strong) UIActionSheet *addMediaActionSheet;
@property (nonatomic, strong) UIActionSheet *deleteMediaActionSheet;
@property (nonatomic, strong) UIView *mediaViewToDelete;
@property (weak, nonatomic) IBOutlet UIButton *closeButton;

@end

@implementation ViewController 

BOOL mouseSwiped;
BOOL drawingMode = YES;
BOOL eraserMode = NO;

- (void)setupDrawing{
    [self resetButtonColors];
    UIImage *clearImage = [[UIImage alloc] init];
    self.drawingImageView.image = clearImage;
    self.tempDrawingImageView.image = [clearImage copy];
    self.tempDrawingImageView.backgroundColor = [UIColor clearColor];
    self.drawingImageView.backgroundColor = [UIColor clearColor];
}

- (IBAction)closeDrawing:(id)sender {
    [self.remoteDrawingManager leaveRoom];
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)captureScreenshot:(id)sender {
    self.menuView.hidden = YES;
    [self capture];
    self.menuView.hidden = NO;
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    hud.mode = MBProgressHUDModeText;
    hud.labelText = @"Captured edited area!";
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 1.2 * NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [MBProgressHUD hideHUDForView:self.view animated:YES];
    });
}

- (IBAction)navigationMode:(id)sender {
    [self resetButtonColors];
    self.navigationButton.selected = YES;
    [self resetGestureRecognizers];
}

- (IBAction)drawingMode:(id)sender {
    [self resetButtonColors];
    self.drawingButton.selected = YES;
    eraserMode = NO;
    [self turnDrawingModeOn];
}

- (IBAction)mediaMode:(id)sender {
    [self resetButtonColors];
    self.mediaButton.selected = YES;
    [self resetGestureRecognizers];
    [self.drawingScrollView addGestureRecognizer:self.mediaPanGesture];
}

- (IBAction)erasingMode:(id)sender {
    [self resetButtonColors];
    self.eraseButton.selected = YES;
    eraserMode = YES;
    [self turnDrawingModeOn];
}

- (void)turnDrawingModeOn {
    [self resetGestureRecognizers];
    [self.drawingScrollView addGestureRecognizer:self.drawingPanGesture];
    CGPoint offset = self.drawingScrollView.contentOffset;
    [self.drawingScrollView setContentOffset:offset animated:NO];
}

- (void)resetGestureRecognizers {
    [self.drawingScrollView removeGestureRecognizer:self.drawingPanGesture];
    [self.drawingScrollView removeGestureRecognizer:self.mediaPanGesture];
}

- (void)resetButtonColors {
    self.navigationButton.selected = NO;
    self.drawingButton.selected = NO;
    self.mediaButton.selected = NO;
    self.eraseButton.selected = NO;
}

- (void)viewDidLoad
{
    [[UIApplication sharedApplication] setStatusBarHidden:YES];
    self.remoteDrawingManager = [[RemoteDrawingSyncManager alloc] initWithRoomId:self.roomId];
    self.remoteDrawingManager.delegate = self;
    self.remoteDrawers = [[NSMutableDictionary alloc] initWithCapacity:10];
    self.drawingScrollView.contentSize = self.drawingImageView.frame.size;

    self.drawingScrollView.maximumZoomScale = 1.0;
    self.drawingScrollView.minimumZoomScale = 0.67;
    self.drawingScrollView.zoomScale = 1.0;
    
    self.drawingScrollView.delegate = self;
    
    self.drawingPanGesture = [self setupDrawingGesture];
    self.longPressGesture = [self setupMediaDeleteGesture];
    [self.drawingScrollView addGestureRecognizer:self.drawingPanGesture];
    [self.drawingScrollView addGestureRecognizer:self.longPressGesture];
    
    self.mediaPanGesture = [self setupMediaGesture];
    
    self.mediaSelectionView = [self setupMediaSelectionView];
    self.deleteMediaSelectionView = [self setupDeleteMediaSelectionView];
    self.addMediaActionSheet = [self setupAddMediaActionSheet];
    self.deleteMediaActionSheet = [self setupDeleteMediaActionSheet];
    
    [self.zoomableView addSubview:self.mediaSelectionView];
    [self.zoomableView addSubview:self.deleteMediaSelectionView];
    
    UITapGestureRecognizer *tapToZoom = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handelDoubleTap:)];
    tapToZoom.numberOfTapsRequired = 2;
    [self.drawingScrollView addGestureRecognizer:tapToZoom];
    
    [self setupInitialState];
    
    [super viewDidLoad];
}

- (void)setupInitialState {
    [self setupDrawing];
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

- (UILongPressGestureRecognizer *)setupMediaDeleteGesture {
    UILongPressGestureRecognizer *longPressGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(askToDelete:)];
    return longPressGesture;
}

- (UIView *)setupMediaSelectionView {
    UIView *mediaSelectionView = [[UIView alloc] init];
    mediaSelectionView.backgroundColor = [UIColor blueColor];
    mediaSelectionView.alpha = .25f;
    mediaSelectionView.hidden = YES;
    return mediaSelectionView;
}

- (UIView *)setupDeleteMediaSelectionView {
    UIView *deleteMediaSelectionView = [[UIView alloc] init];
    deleteMediaSelectionView.backgroundColor = [UIColor redColor];
    deleteMediaSelectionView.alpha = .25f;
    deleteMediaSelectionView.hidden = YES;
    return deleteMediaSelectionView;
}

- (UIActionSheet *)setupAddMediaActionSheet {
    UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:@"Add Media?"
                                                             delegate:self
                                                    cancelButtonTitle:@"Cancel"
                                               destructiveButtonTitle:nil
                                                    otherButtonTitles:@"Yes",@"No", nil];
    return actionSheet;
}

- (UIActionSheet *)setupDeleteMediaActionSheet {
    UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:@"Delete Media?"
                                                                  delegate:self
                                                         cancelButtonTitle:@"Cancel"
                                                    destructiveButtonTitle:nil
                                                         otherButtonTitles:@"Yes",@"No", nil];
    return actionSheet;
}

-(UIImage *)capture {
    UIGraphicsBeginImageContext(self.zoomableView.bounds.size);
    [self.view.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *imageView = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    UIImageWriteToSavedPhotosAlbum(imageView, nil, nil, nil);
    return imageView;
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
        [self.addMediaActionSheet showInView:self.view];
    }
}

- (void)askToDelete:(UILongPressGestureRecognizer *)longPressRecognizer {
    if (longPressRecognizer.state == UIGestureRecognizerStateBegan){
        CGPoint touch = [longPressRecognizer locationInView:self.drawingScrollView];
        UIView *touchedView = [self mediaViewTouched:touch];
        if (touchedView) {
            self.deleteMediaSelectionView.frame = touchedView.frame;
            self.deleteMediaSelectionView.hidden = NO;
            self.mediaViewToDelete = touchedView;
            [self.deleteMediaActionSheet showInView:self.view];
        }
    }
}

- (UIView *)mediaViewTouched:(CGPoint)touchedPoint {
    UIView *touchedView = nil;
    for (UIView *mediaView in self.allMediaView.subviews) {
        if (CGRectContainsPoint(mediaView.frame, touchedPoint)) {
            touchedView = mediaView;
        }
    }
    return touchedView;
}

-(void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (actionSheet == self.addMediaActionSheet) {
        [self addMediaActionSheetClickedButtonAtIndex:buttonIndex];
    }
    else if (actionSheet == self.deleteMediaActionSheet) {
        [self deleteMediaActionSheetClickedButtonAtIndex:buttonIndex];
    }
}

- (void)addMediaActionSheetClickedButtonAtIndex:(NSInteger)buttonIndex {
    switch (buttonIndex) {
        case 0: {
            [self chooseImage];
        }
        case 1:
        case 2: {
        }
        break;
    }
    self.mediaSelectionView.hidden = YES;
}

- (void)deleteMediaActionSheetClickedButtonAtIndex:(NSInteger)buttonIndex {
    switch (buttonIndex) {
        case 0: {
            NSString *mediaToDeleteId = self.mediaViewToDelete.viewId;
            if (mediaToDeleteId) {
                [self.remoteDrawingManager sendDeleteMediaEvent:mediaToDeleteId];
                [self.mediaViewToDelete removeFromSuperview];
            }
        }
        case 1:
        case 2: {
        }
        break;
    }
    self.deleteMediaSelectionView.hidden = YES;
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
    [self.remoteDrawingManager sendPaintEventWith:touch state:@0 erasing:eraserMode];
    self.lastPoint = touch;
    [self startDrawingOnImageView:self.tempDrawingImageView erasing:eraserMode];
}

- (void)drawingMoved:(CGPoint)touch
{    
    mouseSwiped = YES;
    [self.remoteDrawingManager sendPaintEventWith:touch state:@1 erasing:eraserMode];
    [self continueLineWithPoint:touch lastPoint:self.lastPoint drawingImageView:self.tempDrawingImageView erasing:eraserMode];
    self.lastPoint = touch;
}

- (void)drawingEnded:(CGPoint)touch
{
    [self.remoteDrawingManager sendPaintEventWith:touch state:@2 erasing:eraserMode];
    [self finishLineWithLastPoint:touch DrawingImageView:self.tempDrawingImageView];
}

- (void)startDrawingOnImageView:(UIImageView *)drawingImageView erasing:(BOOL)erasing
{
    UIGraphicsBeginImageContext(self.drawingImageView.frame.size);
}

- (void)continueLineWithPoint:(CGPoint)currentPoint lastPoint:(CGPoint)lastPoint drawingImageView:(UIImageView *)drawingImageView erasing:(BOOL)erasing
{
    @autoreleasepool {
        CGContextRef context = UIGraphicsGetCurrentContext();
        CGContextMoveToPoint(context, lastPoint.x, lastPoint.y);
        CGContextAddLineToPoint(context, currentPoint.x, currentPoint.y);
        CGContextSetLineCap(context, kCGLineCapRound);
        CGContextSetLineWidth(context, self.drawingScrollView.zoomScale*2 );
        CGContextSetRGBStrokeColor(context, 0.f, 0.f, 0.f, 1.0);
        if (erasing) {
            CGContextSetLineWidth(context, 20);
            CGContextSetRGBStrokeColor(context, 1.0, 1.0, 1.0, 1.0);
        }
        CGContextSetBlendMode(context, kCGBlendModeNormal);
        CGContextStrokePath(context);
        drawingImageView.image = UIGraphicsGetImageFromCurrentImageContext();
    }
}

- (void)finishLineWithLastPoint:(CGPoint)lastPoint DrawingImageView:(UIImageView *)drawingImageView
{
    if(!mouseSwiped) {
        UIGraphicsBeginImageContextWithOptions(self.drawingImageView.frame.size, self.drawingImageView.opaque, 0.0);
        [drawingImageView.image drawInRect:CGRectMake(0, 0, self.drawingImageView.frame.size.width, self.drawingImageView.frame.size.height)];
        CGContextSetLineCap(UIGraphicsGetCurrentContext(), kCGLineCapRound);
        CGContextSetLineWidth(UIGraphicsGetCurrentContext(), self.drawingScrollView.zoomScale*2);
        CGContextSetRGBStrokeColor(UIGraphicsGetCurrentContext(), 0.f, 0.f, 0.f, 1.0);
        CGContextMoveToPoint(UIGraphicsGetCurrentContext(), lastPoint.x, lastPoint.y);
        CGContextAddLineToPoint(UIGraphicsGetCurrentContext(), lastPoint.x, lastPoint.y);
        CGContextStrokePath(UIGraphicsGetCurrentContext());
        CGContextFlush(UIGraphicsGetCurrentContext());
        drawingImageView.image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    }
    
    UIGraphicsBeginImageContextWithOptions(self.drawingImageView.frame.size, self.drawingImageView.opaque, 0.0);
    [self.drawingImageView.image drawInRect:CGRectMake(0, 0, self.drawingImageView.frame.size.width, self.drawingImageView.frame.size.height) blendMode:kCGBlendModeNormal alpha:1.0];
    [drawingImageView.image drawInRect:CGRectMake(0, 0, self.drawingImageView.frame.size.width, self.drawingImageView.frame.size.height) blendMode:kCGBlendModeNormal alpha:1.0];
    self.drawingImageView.image = UIGraphicsGetImageFromCurrentImageContext();
    drawingImageView.image = nil;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

#pragma mark - RemoteDrawingSyncManagerDelegate

- (void)remotePaintReceived:(NSDictionary *)paintEvent
{
    int identifier = [paintEvent[@"socketId"] intValue];
    int state = [paintEvent[@"state"] intValue];
    NSDictionary *pointDict = paintEvent[@"paint"];
    CGPoint paintPoint = CGPointMake([pointDict[@"x"] floatValue], [pointDict[@"y"] floatValue]);
    BOOL remoteErasing = [paintEvent[@"eraser"] boolValue];
    //RemoteDrawer *remoteDrawer = self.remoteDrawersImageViews
    NSNumber *remoteDrawerKey = [NSNumber numberWithInt:identifier];
    
    switch (state) {
        case 0:
            [self addNewRemoteDrawer:remoteDrawerKey point:paintPoint erasing:remoteErasing];
            break;
        case 1:
            [self drawWithRemoteDrawer:remoteDrawerKey point:paintPoint erasing:remoteErasing];
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
    NSString *imageId = imageEvent[@"imageId"];
    NSString *imageURL = imageEvent[@"imageURL"];
    CGPoint imageOrigin = CGPointMake([imageInfo[@"x"] floatValue], [imageInfo[@"y"] floatValue]);
    CGSize imageSize = CGSizeMake([imageInfo[@"width"] floatValue], [imageInfo[@"height"] floatValue]);
    CGRect imageRect = CGRectMake(imageOrigin.x, imageOrigin.y, imageSize.width, imageSize.height);
    [self addImageWithURL:imageURL imageRect:imageRect imageId:imageId];
}

- (void)remoteVideoReceived:(NSDictionary *)videoEvent {
    NSDictionary *videoInfo = videoEvent[@"videoInfo"];
    NSString *videoURL = videoEvent[@"videoURL"];
    NSString *videoId = videoEvent[@"videoId"];
    CGPoint videoOrigin = CGPointMake([videoInfo[@"x"] floatValue], [videoInfo[@"y"] floatValue]);
    CGSize videoSize = CGSizeMake([videoInfo[@"width"] floatValue], [videoInfo[@"height"] floatValue]);
    CGRect videoRect = CGRectMake(videoOrigin.x, videoOrigin.y, videoSize.width, videoSize.height);
    [self addVideoWithURL:videoURL videoRect:videoRect videoId:videoId];
}

- (void)remoteMediaDeleteReceived:(NSDictionary *)mediaDeleteEvent {
    NSString *mediaId = mediaDeleteEvent[@"mediaId"];
    for (UIView *mediaView in self.allMediaView.subviews) {
        if ([mediaView.viewId isEqualToString:mediaId]) {
            [mediaView removeFromSuperview];
        }
    }
}

- (void)remoteJoinedRoomApproval:(NSDictionary *)roomDict {
    NSString *joinedRoomId = roomDict[@"roomId"];
    NSLog(@"Has joined room: %@",joinedRoomId);
}


- (void)addImageWithURL:(NSString *)imageURLString imageRect:(CGRect)imageRect imageId:(NSString *)imageId{
    UIImageView *newImageView = [[UIImageView alloc] initWithFrame:imageRect];
    [self.allMediaView addSubview:newImageView];

    __weak UIImageView *weakImageView = newImageView;
    
    NSURL *imageURL = [NSURL URLWithString:imageURLString];
    NSURLRequest *imageRequest = [NSURLRequest requestWithURL:imageURL];
    
    [newImageView setImageWithURLRequest:imageRequest placeholderImage:nil success:^(NSURLRequest *request, NSHTTPURLResponse *response, UIImage *image) {
        weakImageView.viewId = imageId;
        weakImageView.alpha = 0.0;
        weakImageView.image = image;
        [UIView animateWithDuration:0.75
                         animations:^{
                            weakImageView.alpha = 1.0;
                        }];
    } failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error) {
    }];
}

- (void)addVideoWithURL:(NSString *)videoURLString videoRect:(CGRect)videoRect videoId:(NSString *)videoId{
    NSURL *movieURL = [NSURL URLWithString:videoURLString];
    
    VKVideoPlayer *player = [[VKVideoPlayer alloc] init];
    player.view.frame = videoRect;
    player.view.viewId = videoId;
    
    [self setupVideoPlayer:player withVideoURL:movieURL];

}

- (void)setupVideoPlayer:(VKVideoPlayer *)player withVideoURL:(NSURL *)videoURL {
    player.delegate = self;
    VKVideoPlayerTrack *track = [[VKVideoPlayerTrack alloc] initWithStreamURL:videoURL];
    
    [self.moviePlayers addObject:player];
    [self.allMediaView addSubview:player.view];
    
    [player.view removeControlView:player.view.rewindButton];
    [player.view removeControlView:player.view.doneButton];
    [player.view removeControlView:player.view.nextButton];
    [player.view removeControlView:player.view.videoQualityButton];
    [player.view addSubviewForControl:player.view.fullscreenButton];
    
    [player loadVideoWithTrack:track];
    [player playContent];
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

- (void)remoteVideoStateReceived:(NSArray *)videoArray {
    for (NSDictionary *videoMedia in videoArray) {
        [self remoteVideoReceived:videoMedia];
    }
}

- (void)addNewRemoteDrawer:(NSNumber *)remotedrawerID point:(CGPoint)startingPoint erasing:(BOOL)erasing
{
    RemoteDrawer *drawer = self.remoteDrawers[remotedrawerID];
    if (!drawer) {
        drawer = [[RemoteDrawer alloc] initWithSuperView:self.drawingScrollView.subviews[0]];
        [self startDrawingOnImageView:drawer.remoteDrawerImageView erasing:erasing];
        [self.remoteDrawers setObject:drawer forKey:remotedrawerID];
    }
    drawer.lastPoint = startingPoint;
}

- (void)drawWithRemoteDrawer:(NSNumber *)remotedrawerID point:(CGPoint)nextPoint erasing:(BOOL)erasing
{
    RemoteDrawer *drawer = self.remoteDrawers[remotedrawerID];
    if (drawer) {
        [self continueLineWithPoint:nextPoint lastPoint:drawer.lastPoint drawingImageView:drawer.remoteDrawerImageView erasing:erasing];
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

- (void)didPickImage:(UIImage *)imagePicked {
    UIImageView *mediaResultImageView = [[UIImageView alloc] initWithFrame:self.mediaSelectionView.frame];
    UIImage *chosenImageScaled = [imagePicked scaleToSize:mediaResultImageView.frame.size];
    
    mediaResultImageView.image = chosenImageScaled;
    mediaResultImageView.backgroundColor = [UIColor yellowColor];
    self.mediaSelectionResultView = mediaResultImageView;
    [self showNewMediaView];
    [self uploadImage:chosenImageScaled withImageRect:mediaResultImageView.frame forView:mediaResultImageView];
}

- (void)uploadImage:(UIImage *)imageToUpload withImageRect:(CGRect)imageRect forView:(UIView *)displayedView{
    AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
    NSData *imageData = UIImagePNGRepresentation(imageToUpload);
    NSString *URLString = [kAPIURL stringByAppendingString:kAPIImageUploadPath];
    
    [manager POST:URLString parameters:nil constructingBodyWithBlock:^(id<AFMultipartFormData> formData) {
        [formData appendPartWithFileData:imageData name:@"myImage" fileName:@"userImage.png" mimeType:@"image/png"];
        
    } success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSLog(@"AF Success: %@", responseObject);
        NSString *imageId = responseObject[@"imageId"];
        displayedView.viewId = imageId;
        [self.remoteDrawingManager sendImageEvent:imageRect imageId:imageId];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"AF Error: %@", error);
    }];
}

- (void)uploadVideo:(NSData *)videoData withVideoRect:(CGRect)videoRect forView:(UIView *)displayedView{
    AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
    NSString *URLString = [kAPIURL stringByAppendingString:kAPIVideoUploadPath];
    
    [manager POST:URLString parameters:nil constructingBodyWithBlock:^(id<AFMultipartFormData> formData) {
        [formData appendPartWithFileData:videoData name:@"myVideo" fileName:@"userVideo.mov" mimeType:@"video/mov"];
        
    } success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSLog(@"AF Success: %@", responseObject);
        NSString *videoId = responseObject[@"videoId"];
        displayedView.viewId = videoId;
        [self.remoteDrawingManager sendVideoEvent:videoRect videoId:videoId];
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

    [[UIApplication sharedApplication] setStatusBarHidden:YES];
}


- (void)didPickMovie:(NSString *)moviePath {
    NSURL *movieURL = [NSURL fileURLWithPath:moviePath];
    
    VKVideoPlayer *player = [[VKVideoPlayer alloc] init];
    player.view.frame = self.mediaSelectionView.frame;
    
    [self setupVideoPlayer:player withVideoURL:movieURL];
    
    NSData *videoData = [NSData dataWithContentsOfURL:movieURL];
    [self uploadVideo:videoData withVideoRect:self.mediaSelectionView.frame forView:player.view];
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
