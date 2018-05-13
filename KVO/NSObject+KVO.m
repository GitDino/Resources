//
//  NSObject+KVO.m
//  TestDemo
//
//  Created by 魏欣宇 on 2018/5/13.
//  Copyright © 2018年 Dino. All rights reserved.
//

#import <objc/message.h>
#import "NSObject+KVO.h"

NSString *const kDOKVOClassPrefix = @"DOKVOClassPrefix_";
NSString *const kDOKVOAssociatedObservers = @"DOKVOAssociatedObservers";

#pragma mark - DOObservationInfo
@interface DOObservationInfo : NSObject

@property (nonatomic, weak) NSObject *observer;
@property (nonatomic, copy) NSString *key;
@property (nonatomic, copy) DOObservingBlock block;

@end

@implementation DOObservationInfo

- (instancetype)initWithObserver:(NSObject *) observer key:(NSString *) key block:(DOObservingBlock) block
{
    if (self = [super init])
    {
        _observer = observer;
        _key = key;
        _block = block;
    }
    return self;
}

@end

#pragma mark - Help Cycle
static NSString * getterForSetter(NSString *setter)
{
    if (setter.length <= 0 || ![setter hasPrefix:@"set"] || ![setter hasSuffix:@":"])
    {
        return nil;
    }
    
    NSRange range = NSMakeRange(3, setter.length - 4);
    NSString *key = [setter substringWithRange:range];
    
    NSString *first_letter = [[key substringToIndex:1] lowercaseString];
    key = [key stringByReplacingCharactersInRange:NSMakeRange(0, 1)
                                       withString:first_letter];
    
    return key;
}

static NSString *setterForGetter(NSString *getter)
{
    if (getter.length <= 0)
    {
        return nil;
    }
    
    NSString *first_letter = [[getter substringToIndex:1] uppercaseString];
    NSString *remaining_letters = [getter substringFromIndex:1];
    
    NSString *setter = [NSString stringWithFormat:@"set%@%@:", first_letter, remaining_letters];
    
    return setter;
}

static void kvo_setter(id self, SEL _cmd, id new_value)
{
    NSString *setter_name = NSStringFromSelector(_cmd);
    NSString *getter_name = getterForSetter(setter_name);
    
    if (!getter_name)
    {
        NSString *reason = [NSString stringWithFormat:@"对象%@不存在%@的set方法", self, setter_name];
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:reason userInfo:nil];
        return;
    }
    
    id old_value = [self valueForKey:getter_name];
    
    struct objc_super super_class = {
        .receiver = self,
        .super_class = class_getSuperclass(object_getClass(self))
    };
    
    void (*objc_msgSendSuperCasted)(void *, SEL, id) = (void *)objc_msgSendSuper;
    
    objc_msgSendSuperCasted(&super_class, _cmd, new_value);
    
    NSMutableArray *observers = objc_getAssociatedObject(self, (__bridge const void *)(kDOKVOAssociatedObservers));
    for (DOObservationInfo *info in observers)
    {
        if ([info.key isEqualToString:getter_name])
        {
            dispatch_async(dispatch_get_global_queue(0, 0), ^{
                info.block(self, getter_name, old_value, new_value);
            });
        }
    }
}

static Class kvoClass(id self, SEL _cmd)
{
    return class_getSuperclass(object_getClass(self));
}

@implementation NSObject (KVO)

#pragma mark - Public Cycle
- (void)DO_addObserver:(NSObject *) observer forKey:(NSString *) key withBlock:(DOObservingBlock) block
{
    SEL setter_selector = NSSelectorFromString(setterForGetter(key));
    Method setter_method = class_getInstanceMethod([self class], setter_selector);
    if (!setter_method)
    {
        NSString *reason = [NSString stringWithFormat:@"对象%@不存在%@的set方法", self, key];
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:reason userInfo:nil];
        return;
    }
    
    Class class = object_getClass(self);
    NSString *class_name = NSStringFromClass(class);
    
    if (![class_name hasPrefix:kDOKVOClassPrefix])
    {
        class = [self makeKVOClassWithOriginalClassName:class_name];
        object_setClass(self, class);
    }
    
    if (![self hasSelector:setter_selector])
    {
        const char *types = method_getTypeEncoding(setter_method);
        class_addMethod(class, setter_selector, (IMP)kvo_setter, types);
    }
    
    DOObservationInfo *info = [[DOObservationInfo alloc] initWithObserver:observer key:key block:block];
    NSMutableArray *observers = objc_getAssociatedObject(self, (__bridge const void *)(kDOKVOAssociatedObservers));
    if (!observers)
    {
        observers = [NSMutableArray array];
        objc_setAssociatedObject(self, (__bridge const void *)(kDOKVOAssociatedObservers), observers, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    [observers addObject:info];
}

- (void)DO_removeObserver:(NSObject *) observer forKey:(NSString *) key
{
    NSMutableArray *observers = objc_getAssociatedObject(self, (__bridge const void *)(kDOKVOAssociatedObservers));
    
    DOObservationInfo *remove_info;
    for (DOObservationInfo *info in observers)
    {
        if (info.observer == observer && [info.key isEqual:key])
        {
            remove_info = info;
            break;
        }
    }
    [observers removeObject:remove_info];
}

#pragma mark - Private Cycle
- (Class)makeKVOClassWithOriginalClassName:(NSString *) originalClass_name
{
    NSString *KVOClass_name = [kDOKVOClassPrefix stringByAppendingString:originalClass_name];
    Class class = NSClassFromString(KVOClass_name);
    
    if (class)
    {
        return class;
    }
    
    Class original_class = object_getClass(self);
    Class kvo_class = objc_allocateClassPair(original_class, KVOClass_name.UTF8String, 0);
    
    Method class_method = class_getInstanceMethod(original_class, @selector(class));
    const char *types = method_getTypeEncoding(class_method);
    class_addMethod(kvo_class, @selector(class), (IMP)kvoClass, types);
    
    objc_registerClassPair(kvo_class);
    
    return kvo_class;
}

- (BOOL)hasSelector:(SEL) selector
{
    Class class = object_getClass(self);
    unsigned int methodCount = 0;
    Method *method_lists = class_copyMethodList(class, &methodCount);
    for (unsigned int i = 0; i < methodCount; i ++)
    {
        SEL this_selector = method_getName(method_lists[i]);
        if (this_selector == selector)
        {
            return YES;
        }
    }
    return NO;
}

@end
