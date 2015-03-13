
#import <Foundation/Foundation.h>
#import "AXQuery.h"

typedef enum {
    AXObjectStatusSaved,
    AXObjectStatusSaving,
    AXObjectStatusNew,
    AXObjectStatusModified
} AXObjectStatus;

@interface AXObject : NSObject

@property (readonly) NSString *collectionName;
@property (readonly) NSString *objectID;
@property (readonly) AXObjectStatus status;

+ (AXObject *)create:(NSString *)collectionName;
+ (AXObject *)create:(NSString *)collectionName properties:(NSDictionary *)properties;

- (void)save;
- (void)save:(void(^)(NSError *error))completion;
+ (void)saveObjects:(NSArray *)objects completion:(void(^)(NSError *error))completion;
+ (void)findAll:(NSString *)collectionName completion:(void(^)(NSArray *objects, NSError *error))completion;
+ (void)find:(NSString *)collectionName withId:(NSString *)objectID completion:(void(^)(AXObject *object, NSError *error))completion;
+ (void)find:(NSString *)collectionName with:(NSDictionary *)propertyValues completion:(void(^)(NSArray *objects, NSError *error))completion;
+ (void)find:(NSString *)collectionName search:(NSDictionary *)propertyValues completion:(void(^)(NSArray *objects, NSError *error))completion;
+ (void)find:(NSString *)collectionName search:(NSString *)searchString properties:(NSArray *)searchProperties completion:(void(^)(NSArray *objects, NSError *error))completion;
+ (void)find:(NSString *)collectionName query:(void(^)(AXQuery *query))queryBlock completion:(void(^)(NSArray *objects, NSError *error))completion;

+ (void)find:(NSString *)collectionName queryString:(NSString *)queryString completion:(void(^)(NSArray *objects, NSError *error))completion;
- (void)refresh:(void(^)(NSError *error))completion;
- (void)remove;
- (void)remove:(void(^)(NSError *error))completion;

- (void)delete __attribute__((deprecated("use method remove instead")));
- (void)delete:(void(^)(NSError *error))completion __attribute__((deprecated("use method remove: instead")));

- (void)grant:(id)who permissions:(NSArray *)permissions;
- (void)revoke:(id)who permissions:(NSArray *)permissions;
- (void)grantPublic:(NSArray *)permissions;
- (void)revokePublic:(NSArray *)permissions;

- (id)objectForKeyedSubscript:(id <NSCopying>)key;
- (void)setObject:(id)obj forKeyedSubscript:(id <NSCopying>)key;

@end
