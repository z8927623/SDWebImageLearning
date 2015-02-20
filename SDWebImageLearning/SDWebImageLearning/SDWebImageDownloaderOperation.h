//
//  SDWebImageDownloaderOperation.h
//  SDWebImageLearning
//
//  Created by wildyao on 15/2/17.
//  Copyright (c) 2015年 wildyao. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SDWebImageOperation.h"
#import "SDWebImageDownloader.h"

@interface SDWebImageDownloaderOperation : NSOperation <SDWebImageOperation>

@property (nonatomic, strong, readonly) NSURLRequest *request;

@property (nonatomic, assign) BOOL shouldUseCredentialStorage;

/**
 * use in `-connection:didReceiveAuthenticationChallenge:`
 */
@property (nonatomic, strong) NSURLCredential *credential;

@property (nonatomic, assign, readonly) SDWebImageDownloaderOptions options;

/**
 *  Initializes a `SDWenImageDownloaderOperation` object
 */
- (id)initWithRequest:(NSURLRequest *)request
              options:(SDWebImageDownloaderOptions)options
             progress:(void (^)(NSInteger receivedSize, NSInteger expectedSize))progressBlock
            completed:(void(^)(UIImage *image, NSData *data, NSError *error, BOOL finished))completedBlock
            cancelled:(void(^)())cancelBlock;

@end
