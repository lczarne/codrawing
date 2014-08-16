//
//  RoomChoiceViewController.m
//  CoDrawing
//
//  Created by Lukasz Czarnecki on 27.07.2014.
//  Copyright (c) 2014 Łukasz Czarnecki. All rights reserved.
//

#import "RoomChoiceViewController.h"
#import <AFNetworking.h>
#import "RemoteDrawingSyncManager.h"
#import "ViewController.h"

@interface RoomChoiceViewController()  <UITextFieldDelegate>
@property (weak, nonatomic) IBOutlet UIView *initialChoiceView;
@property (weak, nonatomic) IBOutlet UIView *joinRoomView;
@property (weak, nonatomic) IBOutlet UIView *createRoomView;
@property (weak, nonatomic) IBOutlet UITextField *joinRoomIdTextField;
@property (weak, nonatomic) IBOutlet UIButton *joinRoomButton;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *joinRoomSpinner;
@property (weak, nonatomic) IBOutlet UITextField *createRoomIdTextField;
@property (weak, nonatomic) IBOutlet UIButton *createRoomButton;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *createRoomSpinner;
@property (weak, nonatomic) IBOutlet UILabel *createRoomErrorLabel;
@property (weak, nonatomic) IBOutlet UILabel *joinRoomErrorLabel;
@property (nonatomic, strong) NSString *chosenRoomId;

@end

static NSString *const kJoinRoomButtonLabel = @"Join";
static NSString *const kJoinRoomButtonErrorLabel = @"No room with this ID";
static NSString *const kCreateRoomButtonLabel = @"Start";
static NSString *const kCreateRoomButtonErrorLabel = @"ID is already used";
static NSString *const kRoomSegueIdentifier = @"goToRoom";
static NSString *const kNetworkError = @"Network error. Try again.";

static CGFloat kChoiceViewsTopOffset = 200.f;

@implementation RoomChoiceViewController

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.joinRoomIdTextField.delegate = self;
    self.createRoomIdTextField.delegate = self;
    [self setupViews];
    [[UIApplication sharedApplication] setStatusBarHidden:YES];
}

- (void)setupViews {
    self.createRoomView.hidden = YES;
    self.joinRoomView.hidden = YES;
    self.createRoomSpinner.hidden = YES;
    self.joinRoomSpinner.hidden = YES;
    self.createRoomErrorLabel.hidden = YES;
    self.joinRoomErrorLabel.hidden = YES;
    self.initialChoiceView.hidden = NO;
    self.joinRoomIdTextField.text = nil;
    self.createRoomIdTextField.text = nil;
}

- (void)viewDidAppear:(BOOL)animated {
    [self moveViewToCenter:self.initialChoiceView];
}

- (void)moveViewToCenter:(UIView *)viewToMove {
    CGRect viewFrame = viewToMove.frame;
    viewFrame.origin.y = kChoiceViewsTopOffset;
    viewToMove.frame = viewFrame;
}

- (IBAction)showCreateRoomView:(id)sender {
    self.initialChoiceView.hidden = YES;
    self.createRoomView.hidden = NO;
    [self moveViewToCenter:self.createRoomView];
    
}

- (IBAction)showJoinRoomView:(id)sender {
    self.initialChoiceView.hidden = YES;
    self.joinRoomView.hidden = NO;
    [self moveViewToCenter:self.joinRoomView];
    
}

- (IBAction)createRoom:(id)sender {
    [self requestCreatingRoom];
}

- (IBAction)joinRoom:(id)sender {
    [self requestJoiningRoom];
}

- (IBAction)cancelCreatingRoom:(id)sender {
    [self setupViews];
}
- (IBAction)cancelJoiningRoom:(id)sender {
    [self setupViews];
}

- (void)goToRoomWithId:(NSString *)roomId {
    self.chosenRoomId = roomId;
   [self performSegueWithIdentifier:kRoomSegueIdentifier sender:self];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:kRoomSegueIdentifier]) {
        ViewController *viewController = [segue destinationViewController];
        viewController.roomId = self.chosenRoomId;
    }
}

- (void)requestCreatingRoom {
    NSString *roomId = self.createRoomIdTextField.text;
    
    if (roomId) {
        AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
        NSString *URLString = [kAPIURL stringByAppendingString:kAPIRoomPath];
        NSDictionary *params = @{@"roomId" : roomId};
                                 
        [manager POST:URLString parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
            NSLog(@"success: %@",responseObject);
            NSDictionary *rsp = responseObject;
            if ([rsp[@"created"] boolValue]) {
                [self goToRoomWithId:roomId];
            }
            else {
                [self animateLabelShowUp:self.createRoomErrorLabel withText:kCreateRoomButtonErrorLabel];
            }

        } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
            NSLog(@"fail: %@",error);
                [self animateLabelShowUp:self.createRoomErrorLabel withText:kNetworkError];
        }];
    }
}

- (void)requestJoiningRoom {

    NSString *roomId = self.joinRoomIdTextField.text;
    NSString *URLString = [kAPIURL stringByAppendingString:kAPIRoomPath];
    URLString = [URLString stringByAppendingString:roomId];
    AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
    
    [manager GET:URLString parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSLog(@"success %@",responseObject);
        NSDictionary *rsp = responseObject;
        if ([rsp[@"exists"] boolValue]) {
            [self goToRoomWithId:roomId];
        }
        else {
            [self animateLabelShowUp:self.joinRoomErrorLabel withText:kJoinRoomButtonErrorLabel];
        }
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        [self animateLabelShowUp:self.joinRoomErrorLabel withText:kNetworkError];
    }];
}

- (void)animateLabelShowUp:(UILabel *)labelToShow withText:(NSString *)labelText{
    labelToShow.alpha = 0.f;
    labelToShow.text = labelText;
    labelToShow.hidden = NO;
    [UIView animateWithDuration:.3 animations:^{
        labelToShow.alpha = 1.f;
    }];
}

- (NSUInteger)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskLandscape;
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {

    self.createRoomErrorLabel.hidden = YES;
    self.joinRoomErrorLabel.hidden = YES;

    return YES;
}

@end
