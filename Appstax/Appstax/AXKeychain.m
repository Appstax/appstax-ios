
#import "AXKeychain.h"
#import <Security/Security.h>

@interface AXKeychain ()
@property NSString *service;
@end

@implementation AXKeychain

- (instancetype)init {
    NSString *service = [[NSBundle mainBundle] bundleIdentifier];
    if(service == nil) {
        service = @"com.appstax.keychain";
    }
    return [self initWithService:service];
}

- (instancetype)initWithService:(NSString *)service {
    self = [super init];
    if(self) {
        _service = service;
    }
    return self;
}

- (id)objectForKeyedSubscript:(id <NSCopying>)key {
    _error = nil;
    NSMutableDictionary *attributes = [self attributesWithKey:key value:nil];
    attributes[(__bridge id)kSecReturnData] = (__bridge id)kCFBooleanTrue;
    attributes[(__bridge id)kSecMatchLimit] = (__bridge id)kSecMatchLimitOne;
    CFTypeRef result = nil;
    SecItemCopyMatching((__bridge CFDictionaryRef)attributes, &result);
    if (result) {
        NSData *data = [NSData dataWithData:(__bridge NSData *)result];
        CFRelease(result);
        return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    } else {
        return nil;
    }
}

- (void)setObject:(NSString *)value forKeyedSubscript:(NSString *)key {
    _error = nil;
    if(value == nil) {
        [self removeValueForKey:key];
    } else if([self containsValueForKey:key]) {
        [self updateValue:value forKey:key];
    } else {
        NSMutableDictionary *attributes = [self attributesWithKey:key value:value];
        OSStatus err = SecItemAdd((__bridge CFDictionaryRef)attributes, NULL);
        if (err != errSecSuccess) {
            _error = @"Failed to store value";
        }
    }
}

- (void)updateValue:(NSString *)value forKey:(NSString *)key {
    NSMutableDictionary *attributes = [self attributesWithKey:key value:nil];
    NSMutableDictionary *update = [NSMutableDictionary dictionary];
    update[(__bridge id)kSecValueData] = [value dataUsingEncoding:NSUTF8StringEncoding];
    OSStatus err = SecItemUpdate((__bridge CFDictionaryRef)attributes, (__bridge CFDictionaryRef)update);
    if (err != errSecSuccess) {
        _error = @"Failed to update value";
    }
}

- (void)removeValueForKey:(NSString *)key {
    _error = nil;
    NSMutableDictionary *attributes = [self attributesWithKey:key value:nil];
    SecItemDelete((__bridge CFDictionaryRef)attributes);
}

- (BOOL)containsValueForKey:(NSString *)key {
    _error = nil;
    NSMutableDictionary *attributes = [self attributesWithKey:key value:nil];
    OSStatus err = SecItemCopyMatching((__bridge CFDictionaryRef)attributes, NULL);
    return err == errSecSuccess;
}

- (void)clear {
    _error = nil;
    NSMutableDictionary *attributes = [self attributesWithKey:nil value:nil];
    SecItemDelete((__bridge CFDictionaryRef)attributes);
}

- (NSMutableDictionary *)attributesWithKey:(id <NSCopying>)key value:(NSString *)value {
    NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
    attributes[(__bridge id)kSecClass] = (__bridge id)kSecClassGenericPassword;
    attributes[(__bridge id)kSecAttrService] = _service;
    if(key != nil) {
        attributes[(__bridge id)kSecAttrAccount] = key;
        attributes[(__bridge id)kSecAttrGeneric] = key;
    }
    if(value != nil) {
        NSData *data = [value dataUsingEncoding:NSUTF8StringEncoding];
        attributes[(__bridge id)kSecValueData] = data;
        attributes[(__bridge id)kSecAttrAccessible] = (__bridge id)kSecAttrAccessibleAfterFirstUnlock;
    }
    return attributes;
}

@end
