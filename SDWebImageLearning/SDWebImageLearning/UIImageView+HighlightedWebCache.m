//
//  UIImageView+HighlightedWebCache.m
//  SDWebImageLearning
//
//  Created by wildyao on 15/2/20.
//  Copyright (c) 2015年 wildyao. All rights reserved.
//

#import "UIImageView+HighlightedWebCache.h"
#import "UIView+WebCacheOperation.h"

#define UIImageViewHighlightedWebCacheOperationKey @"highlightedImage"

@implementation UIImageView (HighlightedWebCache)

- (void)sd_setHighlightedImageWithURL:(NSURL *)url {
    [self sd_setHighlightedImageWithURL:url options:0 progress:nil completed:nil];
}

- (void)sd_setHighlightedImageWithURL:(NSURL *)url options:(SDWebImageOptions)options {
    [self sd_setHighlightedImageWithURL:url options:options progress:nil completed:nil];
}

- (void)sd_setHighlightedImageWithURL:(NSURL *)url completed:(void(^)(UIImage *image, NSError *error, SDImageCacheType cacheType, NSURL *imageURL))completedBlock {
    [self sd_setHighlightedImageWithURL:url options:0 progress:nil completed:completedBlock];
}

- (void)sd_setHighlightedImageWithURL:(NSURL *)url options:(SDWebImageOptions)options completed:(void(^)(UIImage *image, NSError *error, SDImageCacheType cacheType, NSURL *imageURL))completedBlock {
    [self sd_setHighlightedImageWithURL:url options:options progress:nil completed:completedBlock];
}

- (void)sd_setHighlightedImageWithURL:(NSURL *)url options:(SDWebImageOptions)options progress:(void(^)(NSInteger receivedSize, NSInteger expectedSize))progressBlock completed:(void(^)(UIImage *image, NSError *error, SDImageCacheType cacheType, NSURL *imageURL))completedBlock {
    [self sd_cancelCurrentHighlightedImageLoad];
    
    if (url) {
        __weak UIImageView *wself = self;
        id <SDWebImageOperation> operation = [SDWebImageManager.sharedManager downloadImageWithURL:url options:options progress:progressBlock completed:^(UIImage *image, NSError *error, SDImageCacheType cacheType, BOOL finished, NSURL *imageURL) {
            if (!wself) {
                return;
            }
            dispatch_main_sync_safe(^{
                if (!wself) {
                    return;
                }
                if (image) {
                    wself.highlightedImage = image;
                    [wself setNeedsLayout];
                }
                if (completedBlock && finished) {
                    completedBlock(image, error, cacheType, url);
                }
            });
        }];
        // 将单个操作添加到字典
        [self sd_setImageLoadOperation:operation forKey:@"UIImageViewImageLoad"];
    } else {
        dispatch_main_async_safe(^{
            NSError *error = [NSError errorWithDomain:@"SDWebImageErrorDomain" code:-1 userInfo:@{NSLocalizedDescriptionKey : @"Trying to load a nil url"}];
            if (completedBlock) {
                completedBlock(nil, error, SDImageCacheTypeNone, url);
            }
        });
    }
}

- (void)sd_cancelCurrentHighlightedImageLoad {
    [self sd_cancelImageLoadOperationWithKey:UIImageViewHighlightedWebCacheOperationKey];
}

@end
