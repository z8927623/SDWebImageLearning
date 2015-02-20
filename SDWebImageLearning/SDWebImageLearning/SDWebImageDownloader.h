//
//  SDWebImageDownloader.h
//  SDWebImageLearning   
//
//  Created by wildyao on 15/1/31.
//  Copyright (c) 2015年 wildyao. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SDWebImageCompat.h"
#import "SDWebImageOperation.h"

// 位移类型的enum
typedef NS_OPTIONS(NSUInteger, SDWebImageDownloaderOptions) {
    SDWebImageDownloaderLowPriority = 1 << 0,
    SDWebImageDownloaderProgressiveDownload = 1 << 1,

    /**
     * 使用NSURLCache
     */
    SDWebImageDownloaderUseNSURLCache = 1 << 2,
    
    /**
     * 忽略缓存
     */
    SDWebImageDownloaderIgnoreCachedResponse = 1 << 3,
    
    /**
     * 后台下载
     */
    SDWebImageDownloaderContinueInBackground = 1 << 4,

    /**
     * 设置NSMutableURLRequest.HTTPShouldHandleCoolies = YES;
     * 处理存储在NSHTTPCookieStore的cookies，
     */
    SDWebImageDownloaderHandleCookies = 1 << 5,
    
    /**
     * 处理不受信任的SSL证书，谨慎用于生产
     */
    SDWebImageDownloaderAllowInvalidSSLCertificates = 1 << 6,
    
    /**
     * 将operation移到队列头部优先下载
     */
    SDWebImageDownloaderHighPriority = 1 << 7,
};

// 普通enum
typedef NS_ENUM(NSInteger, SDWebImageDownloaderExecutionOrder) {
    /**
     * 先进先出策略，队列
     */
    SDWebImageDownloaderFIFOExecutionOrder,
    /**
     * 后进先出策略，栈
     */
    SDWebImageDownloaderLIFOExecutionOrder
};

extern NSString *const SDWebImageDownloadStartNotification;
extern NSString *const SDWebImageDownloadStopNotification;

//typedef void(^SDWebImageDownloaderProgressBlock)(NSInteger receivedSize, NSInteger expectedSize);
//typedef void(^SDWebImageDownloaderCompletionBlock)(UIImage *image, NSData *data, NSError *error, BOOL finished);
//typedef NSDictionary *(^SDWebImageDownloaderHeaderFilterBlock)(NSURL *url, NSDictionary *headers);


@interface SDWebImageDownloader : NSObject

@property (nonatomic, assign) NSInteger maxConcurrentDownloads;

@property (nonatomic, assign) NSUInteger currentDownloadCount;

@property (nonatomic, assign) NSTimeInterval downloadTimeout;

@property (nonatomic, assign) SDWebImageDownloaderExecutionOrder executionOrder;

+ (SDWebImageDownloader *)sharedDownloader;

@property (strong, nonatomic) NSString *username;

@property (strong, nonatomic) NSString *password;

@property (nonatomic, copy) NSDictionary *(^headersFilter)(NSURL *url, NSDictionary *headers);

- (void)setValue:(NSString *)value forHTTPHeadersField:(NSString *)field;

- (NSString *)valueForHTTPHeaderField:(NSString *)field;

- (void)setOperationClass:(Class)operationClass;

- (id <SDWebImageOperation>)downloadImageWithURL:(NSURL *)url
                                         options:(SDWebImageDownloaderOptions)options
                                        progress:(void(^)(NSInteger receivedSize, NSInteger expectedSize))progressBlock
                                       completed:(void(^)(UIImage *image, NSData *data, NSError *error, BOOL finished))completedBlock;
- (void)setSuspended:(BOOL)suspended;

@end
