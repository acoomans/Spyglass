//
// ACSpyglass.m
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


#import "ACSpyglass.h"
#import "OpenUDID.h"
#import "Base64.h"

#ifdef SPYGLASS_LOG
#define SGLog(...) NSLog(__VA_ARGS__)
#else
#define SGLog(...)
#endif


static NSUInteger const kACSpyglassFlushInterval = 10;
static NSUInteger const kACSpyglassEventsBatchCount = 50;
static NSString * const kACSpyglassPersistanceFilename = @"spyglass-%@.plist";


@interface ACSpyglass ()
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, strong) NSMutableArray *eventsQueue;
@property (nonatomic, strong) NSArray *eventsBatch;
@property (nonatomic, strong) NSURLConnection *eventsConnection;
@property (nonatomic, strong) NSMutableData *eventsResponseData;
#if __IPHONE_OS_VERSION_MIN_REQUIRED >= 40000
@property(nonatomic,assign) UIBackgroundTaskIdentifier taskId;
#endif
@end


@implementation ACSpyglass

#pragma mark - Initialization

- (id)init {
    self = [super init];
    if (self) {
        self.deviceIdentifier = [OpenUDID value];
        self.userIdentifier = nil;
        self.serverURL = nil;
        self.flushInterval = kACSpyglassFlushInterval;
        self.eventsQueue = [@[] mutableCopy];
        self.eventsBatch = nil;
        self.eventsConnection = nil;
        self.eventsResponseData = nil;
        self.taskId = UIBackgroundTaskInvalid;
    }
    return self;
}

+ (id)sharedInstance {
    static dispatch_once_t p = 0;
    __strong static id _sharedObject = nil;
    dispatch_once(&p, ^{
        _sharedObject = [[self alloc] init];
    });
    return _sharedObject;
}

#pragma mark - Tracking events

- (void)track:(NSString *)event {
    [self track:event properties:nil];
}

- (void)track:(NSString *)event properties:(NSDictionary *)properties {
    
    @synchronized(self) {
    
        if (event == nil || [event length] == 0) {
            NSLog(@"Spyglass track called with empty event parameter. Ignored");
            return;
        }
                
        NSMutableDictionary *e = [@{
                                  @"event": event,
                                  @"timestamp": [NSNumber numberWithLong:(long)[[NSDate date] timeIntervalSince1970]],
                                  @"properties": (properties ? properties : @{})
                                  } mutableCopy];
        
        for (id key in @[@"deviceIdentifier", @"userIdentifier"]) {
            if ([self valueForKey:key]) {
                e[key] = [self valueForKey:key];
            }
        }
                            
        SGLog(@"Spyglass: queueing event %@", e);
        [self.eventsQueue addObject:e];
        
        dispatch_queue_t myQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0);
        dispatch_async(myQueue, ^{
		    [self archiveEvents];
        });
    }
}

#pragma mark - Flushing events

- (void)setFlushInterval:(NSUInteger)interval {
    @synchronized(self) {
        _flushInterval = interval;
        [self startFlushTimer];
    }
}

- (void)startFlushTimer {
    @synchronized(self) {
        [self stopFlushTimer];
        if (self.flushInterval > 0) {
            self.timer = [NSTimer scheduledTimerWithTimeInterval:self.flushInterval
                                                          target:self
                                                        selector:@selector(flush)
                                                        userInfo:nil
                                                         repeats:YES];
            SGLog(@"Spyglass: started flush timer %@", self.timer);
        }
    }
}

- (void)stopFlushTimer {
    @synchronized(self) {
        if (self.timer) {
            [self.timer invalidate];
            SGLog(@"Spyglass: stopped flush timer %@", self.timer);
        }
        self.timer = nil;
    }
}

- (void)flush {
    @synchronized(self) {
        SGLog(@"Spyglass: flushing data to %@", self.serverURL);
        [self flushEvents];
    }
}

- (void)flushEvents {
    if (
        ([self.eventsQueue count] == 0) ||
        (self.eventsConnection != nil)
    ) {
        return;
    } else if ([self.eventsQueue count] > kACSpyglassEventsBatchCount) {
        self.eventsBatch = [self.eventsQueue subarrayWithRange:NSMakeRange(0, kACSpyglassEventsBatchCount)];
    } else {
        self.eventsBatch = [NSArray arrayWithArray:self.eventsQueue];
    }
    
    NSString *data = [self encodeAPIData:self.eventsBatch];
    NSString *postBody = [NSString stringWithFormat:@"data=%@", data];
    self.eventsConnection = [self apiConnectionWithEndpoint:@"/track/events/" andBody:postBody];
}

- (void)cancelFlush {
    if (self.eventsConnection == nil) {
    } else {
        [self.eventsConnection cancel];
        self.eventsConnection = nil;
    }
}

- (NSString *)encodeAPIData:(NSArray *)array {
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:array options:0 error:&error];
    if (!data) {
        NSLog(@"Spyglass: failed to encode data (%@)", error);
    }
    NSString *base64 = [data base64EncodedString];
    return base64;
}

#pragma mark * Persistence

- (NSString *)filePathForData:(NSString *)data {
    NSString *filename = [NSString stringWithFormat:kACSpyglassPersistanceFilename, data];
    return [[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject]
            stringByAppendingPathComponent:filename];
}

- (NSString *)eventsFilePath {
    return [self filePathForData:@"events"];
}

- (void)archive {
    @synchronized(self) {
        [self archiveEvents];
    }
}

- (void)archiveEvents {
    @synchronized(self) {
        NSString *filePath = [self eventsFilePath];
        if (![NSKeyedArchiver archiveRootObject:self.eventsQueue toFile:filePath]) {
            NSLog(@"Spyglass: unable to archive events data");
        }
    }
}


- (void)unarchive {
    @synchronized(self) {
        [self unarchiveEvents];
    }
}

- (void)unarchiveEvents {
    NSString *filePath = [self eventsFilePath];
    
    @try {
        self.eventsQueue = [NSKeyedUnarchiver unarchiveObjectWithFile:filePath];
    }
    @catch (NSException *exception) {
        NSLog(@"Spyglass: unable to unarchive events data");
        [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
        self.eventsQueue = nil;
    }
    
    if (!self.eventsQueue) {
        self.eventsQueue = [NSMutableArray array];
    }
}


#pragma mark * Application lifecycle events

- (void)addApplicationObservers {
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter addObserver:self
                           selector:@selector(applicationWillTerminate:)
                               name:UIApplicationWillTerminateNotification
                             object:nil];
    [notificationCenter addObserver:self
                           selector:@selector(applicationWillResignActive:)
                               name:UIApplicationWillResignActiveNotification
                             object:nil];
    [notificationCenter addObserver:self
                           selector:@selector(applicationDidBecomeActive:)
                               name:UIApplicationDidBecomeActiveNotification
                             object:nil];
#if __IPHONE_OS_VERSION_MIN_REQUIRED >= 40000
    if ([[UIDevice currentDevice] respondsToSelector:@selector(isMultitaskingSupported)] && &UIBackgroundTaskInvalid) {
        self.taskId = UIBackgroundTaskInvalid;
        if (&UIApplicationDidEnterBackgroundNotification) {
            [notificationCenter addObserver:self
                                   selector:@selector(applicationDidEnterBackground:)
                                       name:UIApplicationDidEnterBackgroundNotification
                                     object:nil];
        }
        if (&UIApplicationWillEnterForegroundNotification) {
            [notificationCenter addObserver:self
                                   selector:@selector(applicationWillEnterForeground:)
                                       name:UIApplicationWillEnterForegroundNotification
                                     object:nil];
        }
    }
#endif
}

- (void)removeApplicationObservers {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)applicationDidBecomeActive:(NSNotification *)notification {
    [self track:@"applicationDidBecomeActive"];
    @synchronized(self) {
        [self startFlushTimer];
    }
}

- (void)applicationWillResignActive:(NSNotification *)notification {
    [self track:@"applicationWillResignActive"];
    @synchronized(self) {
        [self stopFlushTimer];
    }
}

- (void)applicationDidEnterBackground:(NSNotificationCenter *)notification {
    @synchronized(self) {
#if __IPHONE_OS_VERSION_MIN_REQUIRED >= 40000
        if ([[UIApplication sharedApplication] respondsToSelector:@selector(beginBackgroundTaskWithExpirationHandler:)] &&
            [[UIApplication sharedApplication] respondsToSelector:@selector(endBackgroundTask:)]) {
            
            self.taskId = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
                [self cancelFlush];
                [[UIApplication sharedApplication] endBackgroundTask:self.taskId];
                self.taskId = UIBackgroundTaskInvalid;
            }];
            
            [self flush];
        }
#endif
    }
}

- (void)applicationWillEnterForeground:(NSNotificationCenter *)notification {
#if __IPHONE_OS_VERSION_MIN_REQUIRED >= 40000
    @synchronized(self) {
        
        if (&UIBackgroundTaskInvalid) {
            if (self.taskId != UIBackgroundTaskInvalid) {
                [[UIApplication sharedApplication] endBackgroundTask:self.taskId];
            }
            self.taskId = UIBackgroundTaskInvalid;
        }
        [self cancelFlush];
    }
#endif
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    @synchronized(self) {
        [self archive];
    }
}

- (void)endBackgroundTaskIfComplete {
#if __IPHONE_OS_VERSION_MIN_REQUIRED >= 40000
    // if the os version allows background tasks, the app supports them, and we're in one, end it
    @synchronized(self) {
        if (&UIBackgroundTaskInvalid && [[UIApplication sharedApplication] respondsToSelector:@selector(endBackgroundTask:)] &&
            self.taskId != UIBackgroundTaskInvalid && self.eventsConnection == nil) {
            [[UIApplication sharedApplication] endBackgroundTask:self.taskId];
            self.taskId = UIBackgroundTaskInvalid;
        }
    }
#endif
}


#pragma mark * NSURLConnection callbacks

- (NSURLConnection *)apiConnectionWithEndpoint:(NSString *)endpoint andBody:(NSString *)body {
    if (!self.serverURL) {
        NSLog(@"Spyglass: cannot connect to api, serverURL is not set.");
        return nil;
    }
    NSURL *url = [NSURL URLWithString:[[self.serverURL absoluteString] stringByAppendingString:endpoint]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setValue:@"gzip" forHTTPHeaderField:@"Accept-Encoding"];
    [request setHTTPMethod:@"POST"];
    [request setHTTPBody:[body dataUsingEncoding:NSUTF8StringEncoding]];
    SGLog(@"Spyglass: http request");
    return [NSURLConnection connectionWithRequest:request delegate:self];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSHTTPURLResponse *)response {
    SGLog(@"Spyglass: http status code %d", [response statusCode]);
    if ([response statusCode] != 200) {
        NSLog(@"Spyglass: http error: %@", [NSHTTPURLResponse localizedStringForStatusCode:[response statusCode]]);
    } else if (connection == self.eventsConnection) {
        self.eventsResponseData = [NSMutableData data];
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    if (connection == self.eventsConnection) {
        [self.eventsResponseData appendData:data];
    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    @synchronized(self) {
        NSLog(@"Spyglass: network failure (%@)", error);
        if (connection == self.eventsConnection) {
            self.eventsBatch = nil;
            self.eventsResponseData = nil;
            self.eventsConnection = nil;
            [self archiveEvents];
        }
        [self endBackgroundTaskIfComplete];
    }
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    @synchronized(self) {
        @try {
            SGLog(@"Spyglass: http response finished loading");
            if (connection == self.eventsConnection) {
                
                if (!self.eventsResponseData) {
                    [NSException raise:@"noEventsResponseData" format:@"Spyglass: api response error, no data"];
                }
                
                NSDictionary *responseObject = [NSJSONSerialization JSONObjectWithData:self.eventsResponseData
                                                                               options:0
                                                                                 error:nil];
                if (!responseObject) {
                    [NSException raise:@"noResponseObject" format:@"Spyglass: api response error, data not json"];
                }
                
                if ([responseObject[@"code"] intValue] != 0) {
                    [NSException raise:@"responseCodeError" format:@"Spyglass: track api error, %@", responseObject];
                }
                
                [self.eventsQueue removeObjectsInArray:self.eventsBatch];
                [self archiveEvents];
            }
        }
        @catch (NSException *exception) {
            NSLog(@"%@", exception);
        }
        @finally {
            self.eventsBatch = nil;
            self.eventsResponseData = nil;
            self.eventsConnection = nil;
            [self endBackgroundTaskIfComplete];
        }
    }
}

@end
