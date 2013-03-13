//
//  ACViewController.m
//  SpyglassDemo
//
//  Created by Arnaud Coomans on 3/11/13.
//  Copyright (c) 2013 acoomans. All rights reserved.
//

#import "ACViewController.h"
#import "ACSpyglass.h"

@interface ACViewController ()
@property (nonatomic, strong) NSTimer *timer;
@end

@implementation ACViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [ACSpyglass sharedInstance].userIdentifier = @"black beard";
    
    self.timer = [NSTimer scheduledTimerWithTimeInterval:3.0
                                                  target:self
                                                selector:@selector(onTick:)
                                                userInfo:nil
                                                 repeats:YES];
                                         
    [self.timer fire];
}

-(void)onTick:(NSTimer *)timer {
    [[ACSpyglass sharedInstance] track:@"Attack!" properties:@{
        @"roll" : [NSNumber numberWithInt:arc4random() % 74]
     }];
}

@end
