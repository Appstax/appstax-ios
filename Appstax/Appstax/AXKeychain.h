
#import <Foundation/Foundation.h>

@interface AXKeychain : NSObject

@property (readonly) NSString *error;

- (instancetype)initWithService:(NSString *)service;
- (void)clear;
- (id)objectForKeyedSubscript:(NSString *)key;
- (void)setObject:(NSString *)obj forKeyedSubscript:(NSString *)key;
- (BOOL)containsValueForKey:(id <NSCopying>)key;

@end
