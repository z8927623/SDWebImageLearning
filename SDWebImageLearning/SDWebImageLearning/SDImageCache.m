//
//  SDImageCache.m
//  SDWebImageLearning
//
//  Created by wildyao on 15/1/31.
//  Copyright (c) 2015年 wildyao. All rights reserved.
//

#import "SDImageCache.h"
#import "SDWebImageDecoder.h"
#import "UIImage+MultiFormat.h"
#import <CommonCrypto/CommonDigest.h>

static const NSInteger kDefaultCacheMaxCacheAge = 60 * 60 * 24 * 7; // 1 week
static unsigned char kPNGSignatureBytes[8] = {0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A};
static NSData *kPNGSignatureData = nil;
BOOL ImageDataHasPNGPreffix(NSData *data);

BOOL ImageDataHasPNGPreffix(NSData *data) {
    NSUInteger pngSignatureLength = [kPNGSignatureData length];
    if ([data length] >= pngSignatureLength) {
        if ([[data subdataWithRange:NSMakeRange(0, pngSignatureLength)] isEqualToData:kPNGSignatureData]) {
            return YES;
        }
    }
    
    return NO;
}

@interface SDImageCache ()
// 内存缓存
@property (nonatomic, strong) NSCache *memCache;
// 磁盘缓存路径
@property (nonatomic, strong) NSString *diskCachePath;
// 自定义路径
@property (nonatomic, strong) NSMutableArray *customPaths;
@property (nonatomic, SDDispatchQueueSetterSementics) dispatch_queue_t ioQueue;

@end

@implementation SDImageCache {
    NSFileManager *_fileManager;
}

#pragma mark - init

+ (SDImageCache *)sharedImageCache {
    static dispatch_once_t once;
    static id instance;
    dispatch_once(&once, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (id)init {
    return [self initWithNamespace:@"default"];
}

- (id)initWithNamespace:(NSString *)ns {
    if (self = [super init]) {
        NSString *fullNamespace = [@"com.hackemist.SDWebImageCache." stringByAppendingString:ns];
        // PNG图片data
        kPNGSignatureData = [NSData dataWithBytes:kPNGSignatureBytes length:8];
        
        _ioQueue = dispatch_queue_create("com.hackemist.SDWebImageCache", DISPATCH_QUEUE_SERIAL);
        
        _maxCacheAge = kDefaultCacheMaxCacheAge;
        _memCache = [[NSCache alloc] init];
        _memCache.name = fullNamespace;
        /**
         * 默认存在NSCachesDirectory fullNamespace目录
         */
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
        _diskCachePath = [paths[0] stringByAppendingPathComponent:fullNamespace];
        
        dispatch_sync(_ioQueue, ^{
            _fileManager = [[NSFileManager alloc] init];
        });
        
#if TARGET_OS_IPHONE
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(clearMemory) name:UIApplicationDidReceiveMemoryWarningNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(cleanDisk) name:UIApplicationWillTerminateNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(backgroundCleanDisk) name:UIApplicationDidEnterBackgroundNotification
                                                   object:nil];
#endif
    }
    
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    SDDispatchQueueRelease(_ioQueue);
}

- (void)addReadOnlyCachePath:(NSString *)path {
    if (!self.customPaths) {
        self.customPaths = [[NSMutableArray alloc] init];
    }
    
    if (![self.customPaths containsObject:path]) {
        [self.customPaths addObject:path];
    }
}

#pragma mark - maxMemoryCost's setter/getter
- (void)setMaxMemoryCost:(NSUInteger)maxMemoryCost {
    self.memCache.totalCostLimit = maxMemoryCost;
}

- (NSUInteger)maxMemoryCost {
    return self.memCache.totalCostLimit;
}


#pragma mark - store

// 将图片存入内存缓存、磁盘缓存
- (void)storeImage:(UIImage *)image recalculateFromImage:(BOOL)recalculate imageData:(NSData *)imageData forKey:(NSString *)key toDisk:(BOOL)toDisk {
    if (!image || !key) {
        return;
    }
    
    // 存入内存缓存NSCache
    [self.memCache setObject:image forKey:key cost:image.size.height * image.size.width * image.scale * image.scale];
    
    if (toDisk) {   // 存入磁盘
        dispatch_async(self.ioQueue, ^{
            NSData *data = imageData;
            // 重新计算
            if (image && (recalculate || !data)) {
#if TARGET_OS_IPHONE
                BOOL imageIsPng = YES;
                if ([imageData length] >= [kPNGSignatureData length]) {
                    imageIsPng = ImageDataHasPNGPreffix(imageData);
                }
                
                if (imageIsPng) {
                    data = UIImagePNGRepresentation(image);
                } else {
                    // 1.0，选择不压缩
                    data = UIImageJPEGRepresentation(image, (CGFloat)1.0);
                }
#else
                data = [NSBitmapImageRep representationOfImageRepsInArray:image.representations usingType: NSJPEGFileType properties:nil];
#endif
            }
            
            if (data) {
                if (![_fileManager fileExistsAtPath:_diskCachePath]) {
                    // 创建文件夹
                    [_fileManager createDirectoryAtPath:_diskCachePath withIntermediateDirectories:YES attributes:nil error:NULL];
                }
                // 生成图片
                [_fileManager createFileAtPath:[self defaultCachePathForKey:key] contents:data attributes:nil];
            }
        });
    }
}

- (void)storeImage:(UIImage *)image forKey:(NSString *)key {
    [self storeImage:image recalculateFromImage:YES imageData:nil forKey:key toDisk:YES];
}

- (void)storeImage:(UIImage *)image forKey:(NSString *)key toDisk:(BOOL)toDisk {
    [self storeImage:image recalculateFromImage:YES imageData:nil forKey:key toDisk:toDisk];
}

#pragma mark - search

// 同步查询内存图片
- (UIImage *)imageFromMemoryCacheForKey:(NSString *)key {
    return [self.memCache objectForKey:key];
}

// 同步查询磁盘图片
- (UIImage *)diskImageForKey:(NSString *)key {
    NSData *data = [self diskImageDataBySearchingAllPathsForKey:key];
    if (data) {
        UIImage *image = [UIImage sd_imageWithData:data];
        image = [self scaledImageForKey:key image:image];
        image = [UIImage decodedImageWithImage:image];
        return image;
    } else {
        return nil;
    }
}

// 同步查询图片缓存包括内存和磁盘
- (UIImage *)imageFromDiskCacheForKey:(NSString *)key {
    // 首先查找内存缓存有没有
    UIImage *image = [self imageFromMemoryCacheForKey:key];
    if (image) {
        return image;
    }
    
    // 然后检查磁盘
    UIImage *diskImage = [self diskImageForKey:key];
    if (diskImage) {
        CGFloat cost = diskImage.size.height * diskImage.size.width * diskImage.scale * diskImage.scale;
        // 存入内存，方便下次取出
        [self.memCache setObject:diskImage forKey:key cost:cost];
    }
    
    return diskImage;
}

// 异步查询图片缓存包括内存和磁盘
- (NSOperation *)queryDiskCacheForKey:(NSString *)key done:(void (^)(UIImage *, SDImageCacheType))doneBlock {
    if (!doneBlock) {
        return nil;
    }
    
    if (!key) {
        doneBlock(nil, SDImageCacheTypeNone);
        return nil;
    }
    // 首先查找内存缓存有没有
    UIImage *image = [self imageFromMemoryCacheForKey:key];
    if (image) {
        doneBlock(image, SDImageCacheTypeMemory);
        return nil;
    }
    
    // 然后检查磁盘
    NSOperation *operation = [[NSOperation alloc] init];
    dispatch_async(self.ioQueue, ^{
        if (operation.isCancelled) {
            return;
        }
        
        @autoreleasepool {
            UIImage *diskImage = [self diskImageForKey:key];
            if (diskImage) {
                CGFloat cost = diskImage.size.height * diskImage.size.width * diskImage.scale * diskImage.scale;
                 // 存入内存，方便下次取出
                [self.memCache setObject:diskImage forKey:key cost:cost];
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                doneBlock(diskImage, SDImageCacheTypeDisk);
            });
        }
    });
    
    return operation;
}

// 查看磁盘上是否有相应key的缓存图片
- (BOOL)diskImageExistsWithKey:(NSString *)key {
    BOOL exists = NO;
    exists = [[NSFileManager defaultManager] fileExistsAtPath:[self defaultCachePathForKey:key]];
    
    return exists;
}

- (void)diskImageExistsWithKey:(NSString *)key completion:(void (^)(BOOL))completionBlock {
    dispatch_async(_ioQueue, ^{
        BOOL exists = [_fileManager fileExistsAtPath:[self defaultCachePathForKey:key]];
        if (completionBlock) {
            dispatch_async(dispatch_get_main_queue(), ^ {
                completionBlock(exists);
            });
        }
    });
}

#pragma mark search (private)
// 根据key搜索磁盘图片
- (NSData *)diskImageDataBySearchingAllPathsForKey:(NSString *)key {
    NSString *defaultPath = [self defaultCachePathForKey:key];
    NSData *data = [NSData dataWithContentsOfFile:defaultPath];
    if (data) {
        return data;
    }
    
    for (NSString *path in self.customPaths) {
        NSString *filePath = [self cachePathForKey:key inPath:path];
        NSData *imageData = [NSData dataWithContentsOfFile:filePath];
        if (imageData) {
            return imageData;
        }
    }
    
    return nil;
}

- (UIImage *)scaledImageForKey:(NSString *)key image:(UIImage *)image {
    return SDScaledImageForKey(key, image);
}

#pragma mark - remove
// 异步移除某个图片，包括内存或磁盘上的
- (void)removeImageForKey:(NSString *)key {
    [self removeImageForKey:key withCompletion:nil];
}

- (void)removeImageForKey:(NSString *)key withCompletion:(void (^)(void))completion {
    [self removeImageForKey:key fromDisk:YES withCompletion:completion];
}

- (void)removeImageForKey:(NSString *)key fromDisk:(BOOL)fromDisk {
    [self removeImageForKey:key fromDisk:fromDisk withCompletion:nil];
}

- (void)removeImageForKey:(NSString *)key fromDisk:(BOOL)fromDisk withCompletion:(void (^)(void))completion {
    if (key == nil) {
        return;
    }
    // 移除内存缓存
    [self.memCache removeObjectForKey:key];
    
    // 移除磁盘缓存
    if (fromDisk) {
        dispatch_async(self.ioQueue, ^{
            [_fileManager removeItemAtPath:[self defaultCachePathForKey:key] error:nil];
            
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion();
                });
            }
        });
    } else if (completion) {
        completion();
    }
}

// 清除内存中所有缓存的图片
- (void)clearMemory {
    [self.memCache removeAllObjects];
}

// 清除磁盘上所有缓存的图片
- (void)clearDisk {
    [self clearDiskOnCompletion:nil];
}

- (void)clearDiskOnCompletion:(void (^)(void))completion {
    dispatch_async(self.ioQueue, ^{
        // 递归删除文件夹中所有文件
        [_fileManager removeItemAtPath:self.diskCachePath error:nil];
        // 重新创建新的文件夹
        [_fileManager createDirectoryAtPath:self.diskCachePath withIntermediateDirectories:YES attributes:nil error:NULL];
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion();
            });
        }
    });
}


// 移除磁盘上所有过期的缓存图片
- (void)cleanDisk {
    [self cleanDiskWithCompletionBlock:nil];
}

- (void)cleanDiskWithCompletionBlock:(void (^)(void))completionBlock {
    dispatch_async(self.ioQueue, ^{
        NSURL *diskCacheURL = [NSURL fileURLWithPath:self.diskCachePath isDirectory:YES];
        NSArray *resourceKeys = @[NSURLIsDirectoryKey, NSURLContentModificationDateKey, NSURLTotalFileAllocatedSizeKey];
        
        NSDirectoryEnumerator *fileEnumerator = [_fileManager enumeratorAtURL:diskCacheURL includingPropertiesForKeys:resourceKeys options:NSDirectoryEnumerationSkipsHiddenFiles errorHandler:NULL];
        NSDate *expirationDate = [NSDate dateWithTimeIntervalSinceNow:-self.maxCacheAge];
        NSMutableDictionary *cacheFiles = [NSMutableDictionary dictionary];
        NSUInteger currentCacheSize = 0;
        
        NSMutableArray *urlsToDelegate = [[NSMutableArray alloc] init];
        for (NSURL *fileURL in fileEnumerator) {
            NSDictionary *resourceValues = [fileURL resourceValuesForKeys:resourceKeys error:NULL];
            
            if ([resourceValues[NSURLIsDirectoryKey] boolValue]) {
                continue;
            }
            
            NSDate *modificationDate = resourceValues[NSURLContentModificationDateKey];
            if ([[modificationDate laterDate:expirationDate] isEqualToDate:expirationDate]) {
                [urlsToDelegate addObject:fileURL];
                continue;
            }
            
            NSNumber *totalAllocatedSize = resourceValues[NSURLContentModificationDateKey];
            currentCacheSize += [totalAllocatedSize unsignedIntegerValue];
            [cacheFiles setObject:resourceValues forKey:fileURL];
        }
        
        for (NSURL *fileURL in urlsToDelegate) {
            [_fileManager removeItemAtURL:fileURL error:nil];
        }
        
        
        if (self.maxCacheSize > 0 && currentCacheSize > self.maxCacheSize) {
            const NSUInteger desiredCacheSize = self.maxCacheSize/2;
            
            NSArray *sortedFiles = [cacheFiles keysSortedByValueWithOptions:NSSortConcurrent usingComparator:
                ^NSComparisonResult(id obj1, id obj2) {
                        return [obj1[NSURLContentModificationDateKey] compare:obj2[NSURLContentModificationDateKey]];
                }];
            
            for (NSURL *fileURL in sortedFiles) {
                if ([_fileManager removeItemAtURL:fileURL error:nil]) {
                    NSDictionary *resourceValues = cacheFiles[fileURL];
                    NSNumber *totalAllocatedSize = resourceValues[NSURLTotalFileAllocatedSizeKey];
                    currentCacheSize -= [totalAllocatedSize unsignedIntegerValue];
                    
                    if (currentCacheSize < desiredCacheSize) {
                        break;
                    }
                }
            }
            
            if (completionBlock) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completionBlock();
                });
            }
        }
    });
}


// 后台清除所有过期的缓存图片
- (void)backgroundCleanDisk {
    UIApplication *application = [UIApplication sharedApplication];
    __block UIBackgroundTaskIdentifier bgTask = [application beginBackgroundTaskWithExpirationHandler:^{
        [application endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }];
    
    [self cleanDiskWithCompletionBlock:^{
        [application endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }];
}


#pragma mark - size

// 获取磁盘上所有缓存图片的大小，在后台队列中同步执行
- (NSUInteger)getSize {
    __block NSUInteger size = 0;
    dispatch_sync(self.ioQueue, ^{
        NSDirectoryEnumerator *fileEnumerator = [_fileManager enumeratorAtPath:self.diskCachePath];
        for (NSString *fileName in fileEnumerator) {
            NSString *filePath = [self.diskCachePath stringByAppendingPathComponent:fileName];
            NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil];
            size += [attrs fileSize];
        }
    });
    return size;
}

// 获取磁盘上所有缓存图片的数目，在后台队列中同步执行
- (NSUInteger)getDiskCount {
    __block NSUInteger count = 0;
    dispatch_sync(self.ioQueue, ^{
        NSDirectoryEnumerator *fileEnumerator = [_fileManager enumeratorAtPath:self.diskCachePath];
        count = [[fileEnumerator allObjects] count];
    });
    return count;
}

// 异步计算磁盘上缓存的数目和大小
- (void)calculateSizeWithCompletionBlock:(void (^)(NSUInteger, NSUInteger))completionBlock {
    NSURL *diskCacheURL = [NSURL fileURLWithPath:self.diskCachePath];
    
    dispatch_async(self.ioQueue, ^{
        NSUInteger fileCount = 0;
        NSUInteger totalSize = 0;
        // 枚举文件路径
        NSDirectoryEnumerator *fileEnumerator = [_fileManager enumeratorAtURL:diskCacheURL includingPropertiesForKeys:@[NSFileSize] options:NSDirectoryEnumerationSkipsHiddenFiles errorHandler:nil];
        // 遍历并计算
        for (NSURL *fileURL in fileEnumerator) {
            NSNumber *fileSize;
            [fileURL getResourceValue:&fileSize forKey:NSURLFileSizeKey error:NULL];
            totalSize += [fileSize unsignedIntegerValue];
            fileCount += 1;
        }
        
        if (completionBlock) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock(fileCount, totalSize);
            });
        }
    });
}

#pragma mark - path
// 获取某key对应的缓存路径（需要指定缓存根目录）
- (NSString *)cachePathForKey:(NSString *)key inPath:(NSString *)path {
    // 由key生成文件名并加密，key一般为url
    NSString *filename = [self cachedFileNameForKey:key];
    return [path stringByAppendingPathComponent:filename];
}

//  获取某key默认的缓存路径
- (NSString *)defaultCachePathForKey:(NSString *)key {
    return [self cachePathForKey:key inPath:self.diskCachePath];
}


#pragma mark path (private)
// 由key生成文件名并加密，key一般为url
- (NSString *)cachedFileNameForKey:(NSString *)key {
    const char *str = [key UTF8String];
    if (str == NULL) {
        str = "";
    }
    // depend on <CommonCrypto/CommonDigest.h>
    unsigned char r[CC_MD5_DIGEST_LENGTH];
    CC_MD5(str, (CC_LONG)strlen(str), r);
    // 以16进制输出
    NSString *filename = [NSString stringWithFormat:@"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
                          r[0], r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9], r[10], r[11], r[12], r[13], r[14], r[15]];
    
    return filename;
}

@end
