//
//  UIViewController+DOAnalytics.m
//  AnalyticsDemo
//
//  Created by 魏欣宇 on 2018/5/13.
//  Copyright © 2018年 Dino. All rights reserved.
//

#import <objc/runtime.h>
#import "UIViewController+DOAnalytics.h"

@implementation UIViewController (DOAnalytics)

+ (void)load
{
    do_changeMethod([self class], @selector(viewWillAppear:), @selector(do_viewWillAppear:));
    do_changeMethod([self class], @selector(viewWillDisappear:), @selector(do_viewWillDisappear:));
}

/**
 互换方法实现

 @param class 类
 @param original_sel 原来的方法
 @param custom_sel 自定义方法
 */
void do_changeMethod(Class class, SEL original_sel, SEL custom_sel)
{
    Method original_method = class_getInstanceMethod(class, original_sel);
    
    Method do_method = class_getInstanceMethod(class, custom_sel);
    
    BOOL isSuccess = class_addMethod(class, original_sel, method_getImplementation(do_method), method_getTypeEncoding(do_method));
    
    if (isSuccess)
    {
        class_addMethod(class, custom_sel, method_getImplementation(original_method), method_getTypeEncoding(original_method));
    }
    else
    {
        method_exchangeImplementations(original_method, do_method);
    }
}

/**
 自定义 viewWillAppear 方法
 */
- (void)do_viewWillAppear:(BOOL)animated
{
    [self do_viewWillAppear:animated];
    
    NSLog(@"开始统计：--- %@ --- %@ ---", self.title, NSStringFromClass([self class]));
}

/**
 自定义 viewWillDisappear 方法
 */
- (void)do_viewWillDisappear:(BOOL)animated
{
    [self do_viewWillDisappear:animated];
    
    NSLog(@"结束统计：--- %@ --- %@ ---", self.title, NSStringFromClass([self class]));
}

@end
