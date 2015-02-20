//
//  SDImageCache.h
//  SDWebImageLearning
//
//  Created by wildyao on 15/1/31.
//  Copyright (c) 2015年 wildyao. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SDWebImageCompat.h"

typedef NS_ENUM(NSInteger, SDImageCacheType) {
    SDImageCacheTypeNone,
    SDImageCacheTypeDisk,
    SDImageCacheTypeMemory
};

//typedef void (^SDWebImageQueryCompletedBlock)(UIImage *, SDImageCacheType cacheType);
//typedef void (^SDWebImageCheckCacheCompletionBlock)(BOOL isInCache);
//typedef void (SDWebImageCalculateSizeBlock)(NSUInteger fileCount, NSInteger totalSize);

@interface SDImageCache : NSObject

/**
 * 内存花费
 */
@property (nonatomic, assign) NSUInteger maxMemoryCost;

/**
 * 缓存时间
 */
@property (nonatomic, assign) NSUInteger maxCacheAge;

/**
 * 缓存大小（byte）
 */
@property (nonatomic, assign) NSUInteger maxCacheSize;

#pragma mark - init
+ (SDImageCache *)sharedImageCache;

/**
 * 初始化工作
 */
- (id)initWithNamespace:(NSString *)ns;

/**
 * 添加自定义路径
 */
- (void)addReadOnlyCachePath:(NSString *)path;

#pragma mark - store
/**
 * 将图片存入磁盘
 */
- (void)storeImage:(UIImage *)image forKey:(NSString *)key;

/**
 *  将图片存入内存缓存、磁盘缓存
 */
- (void)storeImage:(UIImage *)image forKey:(NSString *)key toDisk:(BOOL)toDisk;
- (void)storeImage:(UIImage *)image recalculateFromImage:(BOOL)recalculate imageData:(NSData *)imageData forKey:(NSString *)key toDisk:(BOOL)toDisk;

#pragma mark - search

/**
 *  同步查询内存缓存
 */
- (UIImage *)imageFromMemoryCacheForKey:(NSString *)key;

/**
 *  同步查询图片缓存包括内存和磁盘
 */
- (UIImage *)imageFromDiskCacheForKey:(NSString *)key;

/**
 *  异步查询图片缓存包括内存和磁盘
 */
- (NSOperation *)queryDiskCacheForKey:(NSString *)key done:(void (^)(UIImage *, SDImageCacheType cacheType))doneBlock;

/**
 *  查看磁盘上是否有相应key的缓存图片
 */
- (BOOL)diskImageExistsWithKey:(NSString *)key;
- (void)diskImageExistsWithKey:(NSString *)key completion:(void (^)(BOOL isInCache))completionBlock;

#pragma mark - remove
/**
 *  异步移除某个图片，包括内存或磁盘上的
 */
- (void)removeImageForKey:(NSString *)key;
- (void)removeImageForKey:(NSString *)key withCompletion:(void (^)(void))completion;
- (void)removeImageForKey:(NSString *)key fromDisk:(BOOL)fromDisk;
- (void)removeImageForKey:(NSString *)key fromDisk:(BOOL)fromDisk withCompletion:(void (^)(void))completion;

/**
 *  清除内存中所有缓存的图片
 */
- (void)clearMemory;

/**
 *  清除磁盘上所有缓存的图片
 */
- (void)clearDisk;
- (void)clearDiskOnCompletion:(void (^)(void))completion;

/**
 *  移除磁盘上所有过期的缓存图片
 */
- (void)cleanDisk;
- (void)cleanDiskWithCompletionBlock:(void (^)(void))completion;

#pragma mark - size
/**
 *  获取磁盘上所有缓存图片的大小
 */
- (NSUInteger)getSize;

/**
 *  获取磁盘上所有缓存图片的数目
 */
- (NSUInteger)getDiskCount;

/**
 *  异步计算磁盘上缓存的数目和大小
 */
- (void)calculateSizeWithCompletionBlock:(void (^)(NSUInteger fileCount, NSUInteger totalSize))completionBlock;


#pragma mark - path
/**
 *  获取某key默认的缓存路径
 */
- (NSString *)defaultCachePathForKey:(NSString *)key;

/**
 *  获取某key对应的缓存路径（需要指定缓存根目录）
 *  @param key  一般为url
 *  @param path 缓存路径根目录
 *  @return 指定key图片的缓存路径
 */
- (NSString *)cachePathForKey:(NSString *)key inPath:(NSString *)path;

@end
