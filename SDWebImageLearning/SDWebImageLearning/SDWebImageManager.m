//
//  SDWebImageManager.m
//  SDWebImageLearning
//
//  Created by wildyao on 15/2/18.
//  Copyright (c) 2015年 wildyao. All rights reserved.
//

#import "SDWebImageManager.h"

@interface SDWebImageCombinedOperation : NSObject <SDWebImageOperation>

@property (nonatomic, assign, getter = isCancelled) BOOL cancelled;
@property (nonatomic, copy) void (^cancelBlock)(void);
@property (nonatomic, strong) NSOperation *cacheOperation;

@end

@implementation SDWebImageCombinedOperation

#pragma mark - SDWebImageOperation

- (void)setCancelBlock:(void (^)(void))cancelBlock {
    if (self.isCancelled) {
        if (cancelBlock) {
            cancelBlock();
        }
        _cancelBlock = nil; // don't forget to nil the cancelBlock, otherwise we will get crashes
    } else {
        _cancelBlock = [cancelBlock copy];
    }
}

- (void)cancel {
    self.cancelled = YES;
    if (self.cacheOperation) {
        [self.cacheOperation cancel];
        self.cacheOperation = nil;
    }
    if (self.cancelBlock) {
        self.cancelBlock();
        
        // TODO: test todo
        _cancelBlock = nil;
    }
}

@end

@interface SDWebImageManager ()

@property (nonatomic, strong, readwrite) SDImageCache *imageCache;
@property (nonatomic, strong, readwrite) SDWebImageDownloader *imageDownloader;
@property (nonatomic, strong) NSMutableArray *failedURLs;
@property (nonatomic, strong) NSMutableArray *runningOperations;

@end

@implementation SDWebImageManager

+ (id)sharedManager {
    static dispatch_once_t once;
    static id instance;
    dispatch_once(&once, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (id)init {
    if (self = [super init]) {
        _imageCache = [self createCache];
        _imageDownloader = [SDWebImageDownloader sharedDownloader];
        _failedURLs = [[NSMutableArray alloc] init];
        _runningOperations = [[NSMutableArray alloc] init];
    }
    return self;
}

- (SDImageCache *)createCache {
    return [SDImageCache sharedImageCache];
}

- (NSString *)cacheKeyForURL:(NSURL *)url {
    if (self.cacheKeyFilter) {
        return self.cacheKeyFilter(url);
    } else {
        return [url absoluteString];
    }
}

- (BOOL)cachedImageExistsForURL:(NSURL *)url
{
    NSString *key = [self cacheKeyForURL:url];
    if ([self.imageCache imageFromMemoryCacheForKey:key] != nil) {
        return YES;
    }
    return [self.imageCache diskImageExistsWithKey:key];
}

- (BOOL)diskImageExistsForURL:(NSURL *)url
{
    NSString *key = [self cacheKeyForURL:url];
    return [self.imageCache diskImageExistsWithKey:key];
}

- (void)cachedImageExistsForURL:(NSURL *)url completion:(void(^)(BOOL isInCache))completionBlock
{
    NSString *key = [self cacheKeyForURL:url];
    
    BOOL isInMemoryCache = ([self.imageCache imageFromMemoryCacheForKey:key] != nil);
    
    if (isInMemoryCache) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completionBlock) {
                completionBlock(YES);
            }
        });
        return;
    }
    
    [self.imageCache diskImageExistsWithKey:key completion:^(BOOL isInDiskCache) {
        if (completionBlock) {
            completionBlock(isInDiskCache);
        }
    }];
}

- (void)diskImageExistsForURL:(NSURL *)url completion:(void(^)(BOOL isInCache))completionBlock
{
    NSString *key = [self cacheKeyForURL:url];
    
    [self.imageCache diskImageExistsWithKey:key completion:^(BOOL isInDiskCache) {
        if (completionBlock) {
            completionBlock(isInDiskCache);
        }
    }];
}

- (id <SDWebImageOperation>)downloadImageWithURL:(NSURL *)url
                                         options:(SDWebImageOptions)options
                                        progress:(void(^)(NSInteger receivedSize, NSInteger expectedSize))progressBlock
                                       completed:(void(^)(UIImage *image, NSError *error, SDImageCacheType cacheType, BOOL finished, NSURL *imageURL))completedBlock
{
    NSAssert(completedBlock != nil, @"If you mean to prefetch the image, use -[SDWebImagePrefetcher prefetchURLs] instead");
    
    if ([url isKindOfClass:NSString.class]) {
        url = [NSURL URLWithString:(NSString *)url];
    }
    
    if (![url isKindOfClass:NSURL.class]) {
        url = nil;
    }
    
    __block SDWebImageCombinedOperation *operation = [[SDWebImageCombinedOperation alloc] init];
    __weak SDWebImageCombinedOperation *weakOperation = operation;
    
    BOOL isFailedUrl = NO;
    @synchronized(self.failedURLs) {
        isFailedUrl = [self.failedURLs containsObject:url];
    }
    
    if (!url || (!(options & SDWebImageRetryFailed) && isFailedUrl)) {
        dispatch_main_sync_safe(^{
            NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorFileDoesNotExist userInfo:nil];
            completedBlock(nil, error, SDImageCacheTypeNone, YES, url);
        });
        return operation;
    }
    
    @synchronized(self.runningOperations) {
        [self.runningOperations addObject:operation];
    }
    NSString *key = [self cacheKeyForURL:url];
    
    // 查找磁盘是否有缓存图片
    operation.cacheOperation = [self.imageCache queryDiskCacheForKey:key done:^(UIImage *image, SDImageCacheType cacheType) {
        // 一层block
        if (operation.isCancelled) {
            @synchronized(self.runningOperations) {
                // 操作取消，移除操作数组
                [self.runningOperations removeObject:operation];
            }
            return;
        }
        
        // 缓存中没有图片
        if ((!image || options & SDWebImageRefreshCached) && (![self.delegate respondsToSelector:@selector(imageManager:shouldDownloadImageForURL:)] || [self.delegate imageManager:self shouldDownloadImageForURL:url])) {
            if (image && options & SDWebImageRefreshCached) {
                dispatch_main_sync_safe(^{
                    completedBlock(image, nil, cacheType, YES, url);
                });
            }
            
            SDWebImageDownloaderOptions downloaderOptions = 0;
            if (options & SDWebImageLowPriority) {
                downloaderOptions |= SDWebImageDownloaderLowPriority;
            }
            if (options & SDWebImageProgressiveDownload) {
                downloaderOptions |= SDWebImageProgressiveDownload;
            }
            if (options & SDWebImageRefreshCached) {
               downloaderOptions |= SDWebImageDownloaderUseNSURLCache;
            }
            if (options & SDWebImageContinueInBackground) {
                downloaderOptions |= SDWebImageDownloaderContinueInBackground;
            }
            if (options & SDWebImageHandleCookies) {
                downloaderOptions |= SDWebImageDownloaderHandleCookies;
            }
            if (options & SDWebImageAllowInvalidSSLCertificates) {
                downloaderOptions |= SDWebImageDownloaderAllowInvalidSSLCertificates;
            }
            if (options & SDWebImageHighPriority) {
                downloaderOptions |= SDWebImageDownloaderHighPriority;
            }
            if (image && options & SDWebImageRefreshCached) {
                // force progressive off if image already cached but forced refreshing
                downloaderOptions &= ~SDWebImageDownloaderProgressiveDownload;
                // ignore image read from NSURLCache if image if cached but force refreshing
                downloaderOptions |= SDWebImageDownloaderIgnoreCachedResponse;
            }
            
            // 缓存中没有图片，则下载图片
            id <SDWebImageOperation> subOperation = [self.imageDownloader downloadImageWithURL:url
                                                                                       options:downloaderOptions
                                                                                      progress:progressBlock
                                                                                     completed:^(UIImage *downloadedImage, NSData *data, NSError *error, BOOL finished) {
                
                // 两层block
                if (weakOperation.isCancelled) {
                    
                } else if (error) {  // 下载错误
                    dispatch_main_sync_safe(^{
                        if (!weakOperation.isCancelled) {
                            completedBlock(nil, error, SDImageCacheTypeNone, finished, url);
                        }
                    });
                    
                    if (error.code != NSURLErrorNotConnectedToInternet && error.code != NSURLErrorCancelled && error.code != NSURLErrorTimedOut) {
                        @synchronized(self.failedURLs) {
                            if (![self.failedURLs containsObject:url]) {
                                // 存入失败url数组
                                [self.failedURLs addObject:url];
                            }
                        }
                    }
                } else {            // 下载成功
                    BOOL cacheOnDisk = !(options & SDWebImageCacheMemoryOnly);

                    if (options & SDWebImageRefreshCached && image && !downloadedImage) {
                        
                    } else if (downloadedImage && (!downloadedImage.images || (options & SDWebImageTransformAnimatedImage)) && [self.delegate respondsToSelector:@selector(imageManager:transformDownloadedImage:withURL:)]) {   // 需要转换图片
                        
                        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                            UIImage *transformedImage = [self.delegate imageManager:self transformDownloadedImage:downloadedImage withURL:url];
                            
                            if (transformedImage && finished) {
                                // 图片是否已经被转换
                                BOOL imageWasTransformed = ![transformedImage isEqual:downloadedImage];
                                // 保存图片
                                [self.imageCache storeImage:transformedImage recalculateFromImage:imageWasTransformed imageData:data forKey:key toDisk:cacheOnDisk];
                            }
                            
                            dispatch_main_sync_safe(^{   // 主线程同步调用block
                                if (!weakOperation.isCancelled) {
                                    // 调用完成block
                                    completedBlock(transformedImage, nil, SDImageCacheTypeNone, finished, url);
                                }
                            });
                        });
                    } else {                                // 原始图片，不需要转换
                        if (downloadedImage && finished) {
                            // 保存图片
                            [self.imageCache storeImage:downloadedImage recalculateFromImage:NO imageData:data forKey:key toDisk:cacheOnDisk];
                        }
                        
                        dispatch_main_sync_safe(^{
                            if (!weakOperation.isCancelled) {
                                // 调用完成block
                                completedBlock(downloadedImage, nil, SDImageCacheTypeNone, finished, url);
                            }
                        });
                    }
                }
                if (finished) {
                    @synchronized(self.runningOperations) {
                        // 完成后移除操作
                        [self.runningOperations removeObject:operation];
                    }
                }
            }];
            operation.cancelBlock = ^{
                [subOperation cancel];
                
                @synchronized(self.runningOperations) {
                    // 取消后移除操作
                    [self.runningOperations removeObject:weakOperation];
                }
            };
        } else if (image) {     // 缓存中有图片
            dispatch_main_sync_safe(^{
                if (!weakOperation.isCancelled) {
                    completedBlock(image, nil, cacheType, YES, url);
                }
            });
            @synchronized(self.runningOperations) {
                // 移除操作
                [self.runningOperations removeObject:operation];
            }
        } else {                // 其他
            dispatch_main_sync_safe(^{
                if (!weakOperation.isCancelled) {
                    completedBlock(nil, nil, SDImageCacheTypeNone, YES, url);
                }
            });
            @synchronized(self.runningOperations) {
                // 移除操作
                [self.runningOperations removeObject:operation];
            }
        }
    }];
    
    return operation;
}

- (void)saveImageToCache:(UIImage *)image forURL:(NSURL *)url
{
    if (image && url) {
        NSString *key = [self cacheKeyForURL:url];
        [self.imageCache storeImage:image forKey:key toDisk:YES];
    }
}

- (void)cancelAll
{
    @synchronized(self.runningOperations) {
        NSArray *copiedOperations = [self.runningOperations copy];
        // 数组中每个object都调用cancel
        [copiedOperations makeObjectsPerformSelector:@selector(cancel)];
        [self.runningOperations removeObjectsInArray:copiedOperations];
    }
}

- (BOOL)isRunning
{
    return self.runningOperations.count > 0;
}

@end
