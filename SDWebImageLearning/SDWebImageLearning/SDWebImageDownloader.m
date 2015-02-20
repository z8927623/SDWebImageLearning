//
//  SDWebImageDownloader.m
//  SDWebImageLearning
//
//  Created by wildyao on 15/1/31.
//  Copyright (c) 2015年 wildyao. All rights reserved.
//

#import "SDWebImageDownloader.h"
#import "SDWebImageDownloaderOperation.h"
#import <ImageIO/ImageIO.h>

NSString *const SDWebImageDownloadStartNotification = @"SDWebImageDownloadStartNotification";
NSString *const SDWebImageDownloadStopNotification = @"SDWebImageDownloadStopNotification";

static NSString *const kProgressCallbackKey = @"progress";
static NSString *const kCompletedCallbackKey = @"completed";

@interface SDWebImageDownloader ()

@property (nonatomic, strong) NSOperationQueue *downloadQueue;
@property (nonatomic, weak) NSOperation *lastAddedOperation;
@property (nonatomic, assign) Class operationClass;
@property (nonatomic, strong) NSMutableDictionary *URLCallbacks;
@property (nonatomic, strong) NSMutableDictionary *HTTPHeaders;
@property (nonatomic, SDDispatchQueueSetterSementics) dispatch_queue_t barrierQueue;

@end

@implementation SDWebImageDownloader

+ (void)initialize {
    if (NSClassFromString(@"SDNetworkActivityIndicator")) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        id activityIndicator = [NSClassFromString(@"SDNetworkActivityIndicator") performSelector:NSSelectorFromString(@"sharedActivityIndicator")];
#pragma clang diagnostic pop
        
        // 移除之前添加的通知
        [[NSNotificationCenter defaultCenter] removeObserver:activityIndicator name:SDWebImageDownloadStartNotification object:nil];
        [[NSNotificationCenter defaultCenter] removeObserver:activityIndicator name:SDWebImageDownloadStopNotification object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:activityIndicator selector:(NSSelectorFromString(@"startActivity")) name:SDWebImageDownloadStartNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:activityIndicator selector:(NSSelectorFromString(@"stopActivity")) name:SDWebImageDownloadStopNotification object:nil];
    }
}

+ (SDWebImageDownloader *)sharedDownloader {
    static dispatch_once_t once;
    static id instance;
    dispatch_once(&once, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (id)init {
    if (self = [super init]) {
        _operationClass = [SDWebImageDownloaderOperation class];
        _executionOrder = SDWebImageDownloaderFIFOExecutionOrder;
        _downloadQueue = [[NSOperationQueue alloc] init];
        _downloadQueue.maxConcurrentOperationCount = 6;
        _URLCallbacks = [[NSMutableDictionary alloc] init];
        _HTTPHeaders = [NSMutableDictionary dictionaryWithObject:@"image/webp,image/*;q=0.8" forKey:@"Accept"];
        _barrierQueue = dispatch_queue_create("com.hackemist.SDWebImageDownloaderBarrierQueue", DISPATCH_QUEUE_CONCURRENT);
        _downloadTimeout = 15.0;
    }
    return self;
}

- (void)dealloc {
    [self.downloadQueue cancelAllOperations];
    SDDispatchQueueRelease(_barrierQueue);
}

- (void)setValue:(NSString *)value forHTTPHeadersField:(NSString *)field {
    if (value) {
        self.HTTPHeaders[field] = value;
    } else {
        [self.HTTPHeaders removeObjectForKey:field];
    }
}

- (NSString *)valueForHTTPHeaderField:(NSString *)field
{
    return self.HTTPHeaders[field];
}

- (void)setMaxConcurrentDownloads:(NSInteger)maxConcurrentDownloads {
    _downloadQueue.maxConcurrentOperationCount = maxConcurrentDownloads;
}

- (NSInteger)maxConcurrentDownloads {
    return _downloadQueue.maxConcurrentOperationCount;
}

- (NSUInteger)currentDownloadCount {
    return _downloadQueue.operationCount;
}

- (void)setOperationClass:(Class)operationClass {
    _operationClass = operationClass ?: [SDWebImageDownloaderOperation class];
}

- (id <SDWebImageOperation>)downloadImageWithURL:(NSURL *)url
                                         options:(SDWebImageDownloaderOptions)options
                                        progress:(void(^)(NSInteger receivedSize, NSInteger expectedSize))progressBlock
                                       completed:(void(^)(UIImage *image, NSData *data, NSError *error, BOOL finished))completedBlock
{
    __block SDWebImageDownloaderOperation *operation;
    __weak SDWebImageDownloader *wself = self;
    
    [self addProgressCallback:progressBlock andCompletedBlock:completedBlock forURL:url createCallback:^{
        NSTimeInterval timeoutInterval = wself.downloadTimeout;
        if (timeoutInterval == 0.0) {
            timeoutInterval = 15.0;
        }
        
        NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url cachePolicy:(options & SDWebImageDownloaderUseNSURLCache ? NSURLRequestUseProtocolCachePolicy : NSURLRequestReloadIgnoringLocalCacheData) timeoutInterval:timeoutInterval];
        request.HTTPShouldHandleCookies = (options & SDWebImageDownloaderHandleCookies);
        // 开启http管线化
        request.HTTPShouldUsePipelining = YES;
        if (wself.headersFilter) {
            request.allHTTPHeaderFields = wself.headersFilter(url, [wself.HTTPHeaders copy]);
        } else {
            request.allHTTPHeaderFields = wself.HTTPHeaders;
        }
        // operationClass: SDWebImageDownloaderOperation
        operation = [[wself.operationClass alloc] initWithRequest:request
                                                          options:options
                                                         progress:^(NSInteger receivedSize, NSInteger expectedSize) {
                                                             SDWebImageDownloader *sself = wself;
                                                             if (!sself) {
                                                                 return;
                                                             }
                                                             NSArray *callbacksForURL = [sself callbacksForURL:url];
                                                             for (NSDictionary *callbacks in callbacksForURL) {
                                                                 void(^callback)(NSInteger receivedSize, NSInteger expectedSize) = callbacks[kProgressCallbackKey];
                                                                 if (callback) {
                                                                     callback(receivedSize, expectedSize);
                                                                 }
                                                             }
                                                             
                                                        }
                                                        completed:^(UIImage *image, NSData *data, NSError *error, BOOL finished) {
                                                            SDWebImageDownloader *sself = wself;
                                                            if (!sself) {
                                                                return;
                                                            }
                                                            NSArray *callbacksForURL = [sself callbacksForURL:url];
                                                            if (finished) {
                                                                [sself removeCallbacksForURL:url];
                                                            }
                                                            for (NSDictionary *callbacks in callbacksForURL) {
                                                                void(^callback)(UIImage *image, NSData *data, NSError *error, BOOL finished) = callbacks[kCompletedCallbackKey];
                                                                if (callback) {
                                                                    callback(image, data, error, finished);
                                                                }
                                                            }
                                                        }
                                                        cancelled:^{
                                                            SDWebImageDownloader *sself = wself;
                                                            if (!sself) {
                                                                return;
                                                            }
                                                            [sself removeCallbacksForURL:url];
            
                                                        }];
        if (wself.username && wself.password) {
            operation.credential = [NSURLCredential credentialWithUser:wself.username password:wself.password persistence:NSURLCredentialPersistenceForSession];
        }
        
        if (options & SDWebImageDownloaderHighPriority) {
            operation.queuePriority = NSOperationQueuePriorityHigh;
        } else if (options & SDWebImageDownloaderLowPriority) {
            operation.queuePriority = NSOperationQueuePriorityLow;
        }
        // 添加到队列
        [wself.downloadQueue addOperation:operation];
        if (wself.executionOrder == SDWebImageDownloaderLIFOExecutionOrder) {
            [wself.lastAddedOperation addDependency:operation];
            wself.lastAddedOperation = operation;
        }
    }];
    
    return operation;
}

- (void)addProgressCallback:(void(^)(NSInteger receivedSize, NSInteger expectedSize))progressBlock andCompletedBlock:(void(^)(UIImage *image, NSData *data, NSError *error, BOOL finished))completedBlock forURL:(NSURL *)url createCallback:(void (^)(void))createCallback {
    if (url == nil) {
        if (completedBlock != nil) {
            completedBlock(nil, nil, nil, nil);
        }
        return;
    }
    
    dispatch_barrier_sync(self.barrierQueue, ^{
        BOOL first = NO;
        if (!self.URLCallbacks[url]) {
            self.URLCallbacks[url] = [[NSMutableArray alloc] init];
            first = YES;
        }
        
        // 处理下载相同图片的情况
        NSMutableArray *callbacksForURL = self.URLCallbacks[url];
        NSMutableDictionary *callbacks = [[NSMutableDictionary alloc] init];
        if (progressBlock) {
            callbacks[kProgressCallbackKey] = [progressBlock copy];
        }
        if (completedBlock) {
            callbacks[kCompletedCallbackKey] = [completedBlock copy];
        }
        [callbacksForURL addObject:callbacks];
        self.URLCallbacks[url] = callbacksForURL;
        // dic          ->      arr         ->     dic
        // URLCallbacks -> callbacksForURL       callbacks
        if (first) {
            createCallback();
        }
    });
}

- (NSArray *)callbacksForURL:(NSURL *)url {
    __block NSArray *callbacksForURL;
    dispatch_sync(self.barrierQueue, ^{
        callbacksForURL = self.URLCallbacks[url];
    });
    return [callbacksForURL copy];
}

- (void)removeCallbacksForURL:(NSURL *)url {
    dispatch_barrier_async(self.barrierQueue, ^{
        [self.URLCallbacks removeObjectForKey:url];
    });
}

- (void)setSuspended:(BOOL)suspended {
    [self.downloadQueue setSuspended:suspended];
}
@end
