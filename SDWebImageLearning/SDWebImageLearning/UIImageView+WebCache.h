//
//  UIImageView+WebCache.h
//  SDWebImageLearning
//
//  Created by wildyao on 15/2/20.
//  Copyright (c) 2015年 wildyao. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SDWebImageCompat.h"
#import "SDWebImageManager.h"

@interface UIImageView (WebCache)

- (NSURL *)sd_imageURL;

- (void)sd_setImageWithURL:(NSURL *)url;

- (void)sd_setImageWithURL:(NSURL *)url placeholderImage:(UIImage *)placeholder;

- (void)sd_setImageWithURL:(NSURL *)url placeholderImage:(UIImage *)placeholder options:(SDWebImageOptions)options;

- (void)sd_setImageWithURL:(NSURL *)url completed:(void(^)(UIImage *image, NSError *error, SDImageCacheType cacheType, NSURL *imageURL))completedBlock;

- (void)sd_setImageWithURL:(NSURL *)url placeholderImage:(UIImage *)placeholder completed:(void(^)(UIImage *image, NSError *error, SDImageCacheType cacheType, NSURL *imageURL))completedBlock;

- (void)sd_setImageWithURL:(NSURL *)url placeholderImage:(UIImage *)placeholder options:(SDWebImageOptions)options completed:(void(^)(UIImage *image, NSError *error, SDImageCacheType cacheType, NSURL *imageURL))completedBlock;

- (void)sd_setImageWithURL:(NSURL *)url placeholderImage:(UIImage *)placeholder options:(SDWebImageOptions)options progress:(void(^)(NSInteger receivedSize, NSInteger expectedSize))progressBlock completed:(void(^)(UIImage *image, NSError *error, SDImageCacheType cacheType, NSURL *imageURL))completedBlock;

- (void)sd_setImageWithPreviousCachedImageWithURL:(NSURL *)url andPlaceholderImage:(UIImage *)placeholder options:(SDWebImageOptions)options progress:(void(^)(NSInteger receivedSize, NSInteger expectedSize))progressBlock completed:(void(^)(UIImage *image, NSError *error, SDImageCacheType cacheType, NSURL *imageURL))completedBlock;

/**
 * 下载一组图片
 */
- (void)sd_setAnimationImagesWithURLs:(NSArray *)arrayOfURLs;

- (void)sd_cancelCurrentImageLoad;

- (void)sd_cancelCurrentAnimationImagesLoad;

@end
