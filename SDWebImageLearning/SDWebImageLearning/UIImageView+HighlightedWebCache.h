//
//  UIImageView+HighlightedWebCache.h
//  SDWebImageLearning
//
//  Created by wildyao on 15/2/20.
//  Copyright (c) 2015年 wildyao. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SDWebImageCompat.h"
#import "SDWebImageManager.h"

@interface UIImageView (HighlightedWebCache)

- (void)sd_setHighlightedImageWithURL:(NSURL *)url;

- (void)sd_setHighlightedImageWithURL:(NSURL *)url options:(SDWebImageOptions)options;

- (void)sd_setHighlightedImageWithURL:(NSURL *)url completed:(void(^)(UIImage *image, NSError *error, SDImageCacheType cacheType, NSURL *imageURL))completedBlock;

- (void)sd_setHighlightedImageWithURL:(NSURL *)url options:(SDWebImageOptions)options completed:(void(^)(UIImage *image, NSError *error, SDImageCacheType cacheType, NSURL *imageURL))completedBlock;

- (void)sd_setHighlightedImageWithURL:(NSURL *)url options:(SDWebImageOptions)options progress:(void(^)(NSInteger receivedSize, NSInteger expectedSize))progressBlock completed:(void(^)(UIImage *image, NSError *error, SDImageCacheType cacheType, NSURL *imageURL))completedBlock;

- (void)sd_cancelCurrentHighlightedImageLoad;

@end
