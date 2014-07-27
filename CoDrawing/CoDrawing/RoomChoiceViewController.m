//
//  RoomChoiceViewController.m
//  CoDrawing
//
//  Created by Lukasz Czarnecki on 27.07.2014.
//  Copyright (c) 2014 Łukasz Czarnecki. All rights reserved.
//

#import "RoomChoiceViewController.h"

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

@end

static NSString *const kJoinRoomButtonLabel = @"Join";
static NSString *const kJoinRoomButtonErrorLabel = @"No room with this ID";
static NSString *const kCreateRoomButtonLabel = @"Start";
static NSString *const kCreateRoomButtonErrorLabel = @"ID is already used";
static NSString *const kRoomSegueIdentifier = @"goToRoom";

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
    self.createRoomView.hidden = YES;
    self.joinRoomView.hidden = YES;
    self.createRoomSpinner.hidden = YES;
    self.joinRoomSpinner.hidden = YES;
    
    self.joinRoomIdTextField.delegate = self;
    self.createRoomIdTextField.delegate = self;

    self.initialChoiceView.hidden = NO;
    
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
    self.createRoomSpinner.hidden = NO;
    [self.createRoomSpinner startAnimating];
    [self goToRoom];
}

- (IBAction)joinRoom:(id)sender {
    self.joinRoomSpinner.hidden = NO;
    [self.joinRoomSpinner startAnimating];
    [self goToRoom];
}

- (void)goToRoom {
   [self performSegueWithIdentifier:kRoomSegueIdentifier sender:self];
}

- (NSUInteger)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskLandscape;
}


@end
