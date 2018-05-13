//
//  NSObject+KVO.h
//  TestDemo
//
//  Created by 魏欣宇 on 2018/5/13.
//  Copyright © 2018年 Dino. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void(^DOObservingBlock)(id observed_object, NSString *observed_key, id old_value, id new_value);

@interface NSObject (KVO)

/**
 添加 KVO 监听
 */
- (void)DO_addObserver:(NSObject *) observer forKey:(NSString *) key withBlock:(DOObservingBlock) block;

/**
 移除 KVO 监听
 */
- (void)DO_removeObserver:(NSObject *) observer forKey:(NSString *) key;

@end
