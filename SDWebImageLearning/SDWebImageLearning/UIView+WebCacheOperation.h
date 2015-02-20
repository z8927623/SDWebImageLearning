//
//  UIView+WebCacheOperation.h
//  SDWebImageLearning
//
//  Created by wildyao on 15/2/20.
//  Copyright (c) 2015年 wildyao. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SDWebImageManager.h"

@interface UIView (WebCacheOperation)

- (void)sd_setImageLoadOperation:(id)operation forKey:(NSString *)key;

- (void)sd_cancelImageLoadOperationWithKey:(NSString *)key;

- (void)sd_removeImageLoadOperationWithKey:(NSString *)key;

@end
