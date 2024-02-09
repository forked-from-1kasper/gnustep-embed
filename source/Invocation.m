#import <Invocation.h>

@implementation Invocation
+ (id) new:(SEL) sel
{
    Invocation * object = [Invocation alloc];

    object->_fireproof = NO;
    object->_sel       = sel;
    object->_target    = nil;
    object->_obj1      = nil;
    object->_obj2      = nil;

    return object;
}

+ (id) new:(SEL) sel withObject:(id) obj1
{
    Invocation * object = [Invocation alloc];

    object->_fireproof = NO;
    object->_sel       = sel;
    object->_target    = nil;
    object->_obj1      = obj1;
    object->_obj2      = nil;

    return object;
}

+ (id) new:(SEL) sel withObject:(id) obj1
                     withObject:(id) obj2
{
    Invocation * object = [Invocation alloc];

    object->_fireproof = NO;
    object->_sel       = sel;
    object->_target    = nil;
    object->_obj1      = obj1;
    object->_obj2      = obj2;

    return object;
}

+ (id) new:(SEL) sel withTarget:(id) target
{
    Invocation * object = [Invocation alloc];

    object->_fireproof = NO;
    object->_sel       = sel;
    object->_target    = target;
    object->_obj1      = nil;
    object->_obj2      = nil;

    return object;
}

+ (id) new:(SEL) sel withTarget:(id) target
                     withObject:(id) obj1
{
    Invocation * object = [Invocation alloc];

    object->_fireproof = NO;
    object->_sel       = sel;
    object->_target    = target;
    object->_obj1      = obj1;
    object->_obj2      = nil;

    return object;
}

+ (id) new:(SEL) sel withTarget:(id) target
                     withObject:(id) obj1
                     withObject:(id) obj2
{
    Invocation * object = [Invocation alloc];

    object->_fireproof = NO;
    object->_sel       = sel;
    object->_target    = target;
    object->_obj1      = obj1;
    object->_obj2      = obj2;

    return object;
}

- (id) setFireproof
{
    _fireproof = YES;
    return self;
}

- (id) fire
{
    return [self fire:nil];
}

- (id) fire:(id) sender
{
    id target = _target == nil ? sender : _target;
    if (![target respondsToSelector:_sel]) return nil;

    id retval = _obj2 != nil ? [target performSelector:_sel withObject:_obj1 withObject:_obj2] :
                _obj1 != nil ? [target performSelector:_sel withObject:_obj1] :
                               [target performSelector:_sel];

    if (!_fireproof) RELEASE(self);

    return retval;
}
@end