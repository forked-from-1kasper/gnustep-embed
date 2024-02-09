#import <Foundation/Foundation.h>

@interface Invocation : NSObject
{
    BOOL _fireproof; SEL _sel;
    id _target, _obj1, _obj2;
}

+ (id) new:(SEL) sel;

+ (id) new:(SEL) sel withObject:(id) obj1;

+ (id) new:(SEL) sel withObject:(id) obj1
                     withObject:(id) obj2;

+ (id) new:(SEL) sel withTarget:(id) target;

+ (id) new:(SEL) sel withTarget:(id) target
                     withObject:(id) obj1;

+ (id) new:(SEL) sel withTarget:(id) target
                     withObject:(id) obj1
                     withObject:(id) obj2;

- (id) setFireproof;

- (id) fire;
- (id) fire:(id) sender;
@end
