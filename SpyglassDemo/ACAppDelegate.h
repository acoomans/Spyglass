//
//  ACAppDelegate.h
//  SpyglassDemo
//
//  Created by Arnaud Coomans on 3/11/13.
//  Copyright (c) 2013 acoomans. All rights reserved.
//

#import <UIKit/UIKit.h>

@class ACViewController;

@interface ACAppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

@property (strong, nonatomic) ACViewController *viewController;

@end
