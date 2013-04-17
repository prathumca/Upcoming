//
//  TLRootViewController.m
//  Layout Test
//
//  Created by Ash Furrow on 2013-04-12.
//  Copyright (c) 2013 Teehan+Lax. All rights reserved.
//

#import "TLRootViewController.h"

#import "TLDayListViewController.h"
#import "TLHeaderViewController.h"

#import <BlocksKit.h>
#import <EXTScope.h>

static const CGFloat kHeaderHeight = 72.0f;

@interface TLRootViewController ()

@property (nonatomic, strong) TLDayListViewController *dayListViewController;
@property (nonatomic, strong) TLHeaderViewController *headerViewController;

@property (nonatomic, strong) UIView *dayListOverlayView;

@property (nonatomic, strong) UITapGestureRecognizer *tapGestureRecognizer;

@property (nonatomic, strong) RACSubject *downwardPanSubject;
@property (nonatomic, strong) RACSubject *dayListMovementSubject;
@property (nonatomic, strong) RACSubject *headerMovementSubject;
@property (nonatomic, strong) RACSubject *dayListOverlaySubject;

@end

@implementation TLRootViewController

static const CGFloat kMaximumTranslationThreshold = 320.0f;
static const CGFloat kMaximumShrinkTranslation = 0.1f;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if (!(self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) return nil;
    
    self.dayListViewController = [[TLDayListViewController alloc] init];
    [self addChildViewController:self.dayListViewController];
    
    self.headerViewController = [[TLHeaderViewController alloc] initWithNibName:@"TLHeaderViewController" bundle:nil];
    [self addChildViewController:self.headerViewController];
    
    self.dayListOverlayView = [[UIView alloc] initWithFrame:self.dayListViewController.view.frame];
    self.dayListOverlayView.backgroundColor = [UIColor colorWithWhite:0.0f alpha:0.4f];
    self.dayListOverlayView.alpha = 0.0f;
    
    @weakify(self);
    self.dayListOverlaySubject = [RACSubject subject];
    [self.dayListOverlaySubject subscribeNext:^(id x) {
        @strongify(self);
        if ([x boolValue])
        {
            self.dayListViewController.view.userInteractionEnabled = NO;
            self.dayListOverlayView.frame = self.dayListViewController.view.frame;
            [self.view insertSubview:self.dayListOverlayView aboveSubview:self.dayListViewController.view];
        }
        else
        {
            self.dayListViewController.view.userInteractionEnabled = YES;
            [self.dayListOverlayView removeFromSuperview];
        }
    }];
    
    self.headerMovementSubject = [RACSubject subject];
    [self.headerMovementSubject subscribeNext:^(id x) {
        @strongify(self);
        
        CGFloat translation = [x floatValue];
        
        CGRect frame = CGRectMake(0, 0, CGRectGetWidth(self.view.bounds), kHeaderHeight + translation);
        
        if (translation < 0)
        {
            frame = CGRectMake(0, 0, CGRectGetWidth(self.view.bounds), kHeaderHeight);
        }
        
        self.headerViewController.view.frame = frame;
    }];
    
    self.dayListMovementSubject = [RACSubject subject];
    [self.dayListMovementSubject subscribeNext:^(id x) {
        @strongify(self);
        CGFloat ratio = [x floatValue];
        
        self.dayListOverlayView.alpha = ratio;
        
        CGAffineTransform transform = CGAffineTransformIdentity;
        
        if (ratio > 0.01)
        {
            transform = CGAffineTransformMakeScale(1.0f - ratio * kMaximumShrinkTranslation, 1.0f - ratio * kMaximumShrinkTranslation);
        }
        
        self.dayListViewController.view.transform = transform;
        self.dayListOverlayView.transform = transform;
    }];
    
    self.downwardPanSubject = [RACSubject subject];
    [self.downwardPanSubject subscribeNext:^(NSNumber *translation) {
        @strongify(self);
        CGFloat verticalTranslation = [translation floatValue];
        
        CGFloat effectiveRatio = 0.0f;
        
        if (verticalTranslation <= 0)
        {
            effectiveRatio = 0.0f;
        }
        else if (verticalTranslation <= kMaximumTranslationThreshold)
        {
            effectiveRatio = MIN(fabsf(verticalTranslation / kMaximumTranslationThreshold), 1);
        }
        else
        {
            CGFloat overshoot = verticalTranslation - kMaximumTranslationThreshold;
            CGFloat y = 2 * sqrtf(overshoot + 1) - 2;
            effectiveRatio = 1.0f + (y / kMaximumTranslationThreshold);
        }
        
        [self.dayListMovementSubject sendNext:@(effectiveRatio)];
    }];
    
    return self;
}

-(void)loadView
{
    [super loadView];
    
    self.dayListViewController.view.frame = CGRectMake(0, kHeaderHeight, CGRectGetWidth(self.view.bounds), CGRectGetHeight(self.view.bounds) - kHeaderHeight);
    self.dayListViewController.view.autoresizingMask = UIViewAutoresizingFlexibleHeight;
    self.dayListViewController.view.layer.shadowColor = [[UIColor blackColor] CGColor];
    self.dayListViewController.view.layer.shadowOpacity = 1.0f;
    self.dayListViewController.view.layer.shadowOffset = CGSizeMake(0, 1);
    self.dayListViewController.view.layer.shadowPath = [[UIBezierPath bezierPathWithRect:self.dayListViewController.view.bounds] CGPath];
    self.dayListViewController.view.layer.shadowRadius = 5.0f;
    self.dayListViewController.view.layer.masksToBounds = NO;
    
    [self.view addSubview:self.dayListViewController.view];
    
    self.headerViewController.view.frame = CGRectMake(0, 0, CGRectGetWidth(self.view.bounds), kHeaderHeight);
    [self.view addSubview:self.headerViewController.view];
}

-(void)viewDidLoad
{
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor colorWithWhite:33.0f/255.0f alpha:1.0f];
    
    self.tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithHandler:^(UIGestureRecognizer *sender, UIGestureRecognizerState state, CGPoint location) {
        if (CGRectContainsPoint(self.headerViewController.view.frame, location)) return;
        
        [UIView animateWithDuration:0.25f animations:^{
            [self.downwardPanSubject sendNext:@(0)];
            [self.headerMovementSubject sendNext:@(0)];
        } completion:^(BOOL finished) {
            [self.dayListOverlaySubject sendNext:@(NO)];
        }];
    }];
    
    [self.view addGestureRecognizer:self.tapGestureRecognizer];
    
    RAC(self.tapGestureRecognizer.enabled) = [RACSignal combineLatest:@[RACAble(self.headerViewController.view.frame)]
                                                               reduce:^(NSValue *frameValue){
                                                                   CGRect frame = [frameValue CGRectValue];
                                                                   
                                                                   return @(CGRectGetHeight(frame) >= kMaximumTranslationThreshold);
                                                               }];
    
    UIPanGestureRecognizer *panDownGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithHandler:^(UIGestureRecognizer *sender, UIGestureRecognizerState state, CGPoint location) {
        UIPanGestureRecognizer *recognizer = (UIPanGestureRecognizer *)sender;
        
        CGPoint translation = [recognizer translationInView:self.view];
        
        if (state == UIGestureRecognizerStateBegan)
        {
            [self.dayListOverlaySubject sendNext:@(YES)];
        }
        else if (state == UIGestureRecognizerStateChanged)
        {
            [self.downwardPanSubject sendNext:@(translation.y)];
            [self.headerMovementSubject sendNext:@(translation.y)];
        }
        else if (state == UIGestureRecognizerStateEnded)
        {
            BOOL movingDown = ([recognizer velocityInView:self.view].y > 0);
            [UIView animateWithDuration:0.25f animations:^{
                
                if (movingDown)
                {
                    [self.downwardPanSubject sendNext:@(kMaximumTranslationThreshold)];
                    [self.headerMovementSubject sendNext:@(kMaximumTranslationThreshold)];
                }
                else
                {
                    [self.downwardPanSubject sendNext:@(0)];
                    [self.headerMovementSubject sendNext:@(0)];
                }
            } completion:^(BOOL finished) {
                if (!movingDown)
                {
                    [self.dayListOverlaySubject sendNext:@(NO)];
                }
            }];
        }
    }];
    
    [self.headerViewController.view addGestureRecognizer:panDownGestureRecognizer];
}


@end
