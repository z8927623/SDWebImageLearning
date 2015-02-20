//
//  SDWebImageManager.h
//  SDWebImageLearning
//
//  Created by wildyao on 15/2/18.
//  Copyright (c) 2015年 wildyao. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SDWebImageOperation.h"
#import "SDWebImageDownloader.h"
#import "SDImageCache.h"

typedef NS_OPTIONS(NSUInteger, SDWebImageOptions) {
    /**
     * 禁止黑名单
     */
    SDWebImageRetryFailed = 1 << 0,
   
    /**
     * 默认情况下，图片在有UI交互情况下下载，该选项关闭此功能
     */
    SDWebImageLowPriority = 1 << 1,
    
    /**
     * 禁止磁盘缓存
     */
    SDWebImageCacheMemoryOnly = 1 << 2,
  
    /**
     * 边下载边显示
     */
    SDWebImageProgressiveDownload = 1 << 3,
    
    /**
     *
     */
    SDWebImageRefreshCached = 1 << 4,
   
    /**
     * 后台下载
     */
    SDWebImageContinueInBackground = 1 << 5,
    
    /**
     * 设置NSMutableURLRequest.HTTPShouldHandleCoolies = YES;
     * 处理存储在NSHTTPCookieStore的cookies，
     */
    SDWebImageHandleCookies = 1 << 6,
    
    /**
     *  处理不受信任的SSL证书，谨慎用于生产
     */
    SDWebImageAllowInvalidSSLCertificates = 1 << 7,
   
    /**
     * 将operation移到队列头部优先下载
     */
    SDWebImageHighPriority = 1 << 8,
    
    /**
     * 延迟显示placeholder直到图片下载完成
     */
    SDWebImageDelayPlaceholder = 1 << 9,
    
    /**
     * 是否转化图片
     */
    SDWebImageTransformAnimatedImage = 1 << 10,
};

@class SDWebImageManager;

@protocol SDWebImageManagerDelegate <NSObject>

@optional

/**
 * 当缓存图片没找到时，决定那个图片应该下载
 */
- (BOOL)imageManager:(SDWebImageManager *)imageManager shouldDownloadImageForURL:(NSURL *)imageURL;

/**
 * 下载完成后立马在全局队列里进行图片处理，以防堵塞主线程
 */
- (UIImage *)imageManager:(SDWebImageManager *)imageManager transformDownloadedImage:(UIImage *)image withURL:(NSURL *)imageURL;

@end

@interface SDWebImageManager : NSObject

@property (nonatomic, weak) id <SDWebImageManagerDelegate> delegate;

@property (nonatomic, strong, readonly) SDImageCache *imageCache;
@property (nonatomic, strong, readonly) SDWebImageDownloader *imageDownloader;
@property (nonatomic, copy) NSString *(^cacheKeyFilter)(NSURL *url);

+ (SDWebImageManager *)sharedManager;

- (id <SDWebImageOperation>)downloadImageWithURL:(NSURL *)url
                                         options:(SDWebImageOptions)options
                                        progress:(void(^)(NSInteger receivedSize, NSInteger expectedSize))progressBlock
                                       completed:(void(^)(UIImage *image, NSError *error, SDImageCacheType cacheType, BOOL finished, NSURL *imageURL))completedBlock;

- (void)saveImageToCache:(UIImage *)image forURL:(NSURL *)url;

- (void)cancelAll;

- (BOOL)isRunning;

- (BOOL)cachedImageExistsForURL:(NSURL *)url;

- (BOOL)diskImageExistsForURL:(NSURL *)url;

- (void)cachedImageExistsForURL:(NSURL *)url completion:(void(^)(BOOL isInCache))completionBlock;

- (void)diskImageExistsForURL:(NSURL *)url completion:(void(^)(BOOL isInCache))completionBlock;

- (NSString *)cacheKeyForURL:(NSURL *)url;

@end
