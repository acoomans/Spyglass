//
// ACSpyglass.h
// Spyglass
//
// Created by Arnaud Coomans on 3/11/13.
// Copyright 2013 Arnaud Coomans
// Copyright 2012 Mixpanel
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import <Foundation/Foundation.h>

@interface ACSpyglass : NSObject

/** @name Properties */

/** Unique device identifier
 *
 * Defaults to OpenUDID.
 */
@property (nonatomic, strong) NSString *deviceIdentifier;

/** Unique user identifier
 */
@property (nonatomic, strong) NSString *userIdentifier;

/** The base URL for API requests.
 */
@property (nonatomic, strong) NSString *serverURL;

/** Flush timer's interval in seconds
 *
 * Default is 10 seconds.s
 * Setting a flush interval of 0 will turn off the flush timer.
 */
@property (nonatomic, assign) NSUInteger flushInterval;


/** @name Initialization */

/** Singleton instance
 */
+ (instancetype)sharedInstance;


/** @name Tracking events */

/** Track an event
 */
- (void)track:(NSString *)event;

/** Track an event with properties
 */
- (void)track:(NSString *)event properties:(NSDictionary *)properties;


/** @name Flushing events */

/** Flush events and send them server
 */
- (void)flush;

@end
