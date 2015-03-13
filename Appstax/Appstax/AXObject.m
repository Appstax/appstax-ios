
#import "AppstaxInternals.h"
#import "AXObject.h"
#import "AXDataStore.h"

@class AXDataStore;

@interface AXObject()
@property AXDataStore *dataStore;
@property AXPermissionsService *permissionsService;
@property NSMutableDictionary *properties;
@property NSString *collectionName;
@property NSString *objectID;
@property NSMutableArray *permissionGrants;
@property NSMutableArray *permissionRevokes;
@end

@implementation AXObject

- (instancetype)initWithCollectionName:(NSString *)collectionName {
    return [[AXObject alloc] initWithCollectionName:collectionName properties:nil status:AXObjectStatusNew];
}

- (instancetype)initWithCollectionName:(NSString *)collectionName properties:(NSDictionary *)properties status:(AXObjectStatus)status {
    self = [super init];
    if(self) {
        _dataStore = [[Appstax defaultContext] dataStore];
        _permissionsService = [[Appstax defaultContext] permissionsService];
        _collectionName = collectionName;
        _properties = [NSMutableDictionary dictionaryWithDictionary:properties];
        _objectID = _properties[@"sysObjectId"];
        _status = status;
        _permissionGrants = [NSMutableArray array];
        _permissionRevokes = [NSMutableArray array];
        [self setupInitialFileProperties];
    }
    return self;
}

- (void)setupInitialFileProperties {
    AXFileService *fileService = [[Appstax defaultContext] fileService];
    NSMutableDictionary *files = [NSMutableDictionary dictionary];
    for(NSString *key in _properties.keyEnumerator) {
        if([_properties[key] isKindOfClass:[NSDictionary class]] &&
           [_properties[key][@"sysDatatype"] isEqualToString:@"file"]) {
            NSString *filename = _properties[key][@"filename"];
            NSURL *url = [fileService urlForFileName:filename objectID:_objectID propertyName:key collectionName:_collectionName];
            files[key] = [AXFile fileWithUrl:url name:filename status:AXFileStatusSaved];
        }
    }
    for(NSString *key in files.keyEnumerator) {
        _properties[key] = files[key];
    }
}

- (void)overrideObjectID:(NSString *)objectID {
    if(objectID != nil) {
        self.objectID = objectID;
        self.properties[@"sysObjectId"] = objectID;
    }
}

- (id)objectForKeyedSubscript:(id <NSCopying>)key {
    return _properties[key];
}

- (void)setObject:(id)obj forKeyedSubscript:(id <NSCopying>)key {
    _status = AXObjectStatusModified;
    _properties[key] = obj;
}

- (NSDictionary *)allProperties {
    return [NSDictionary dictionaryWithDictionary:_properties];
}

- (NSDictionary *)allPropertiesForSaving {
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    for(NSString *key in _properties.keyEnumerator) {
        id value = _properties[key];
        if([value isKindOfClass:[AXFile class]]) {
            AXFile *file = (AXFile *)value;
            value = @{@"sysDatatype": @"file",
                      @"filename": file.filename};
        }
        result[key] = value;
    }
    return result;
}

- (NSString *)description {
    return [_collectionName stringByAppendingString:_properties.description];
}

- (void)grant:(id)who permissions:(NSArray *)permissions {
    NSArray *usernames = [self usernamesFromWho:who];
    for(NSString *username in usernames) {
        [_permissionGrants addObject:@{@"username":username,
                                       @"permissions":permissions}];
    }
}

- (void)revoke:(id)who permissions:(NSArray *)permissions {
    NSArray *usernames = [self usernamesFromWho:who];
    for(NSString *username in usernames) {
        [_permissionRevokes addObject:@{@"username":username,
                                        @"permissions":permissions}];
    }
}

- (void)grantPublic:(NSArray *)permissions {
    [self grant:@"*" permissions:permissions];
}

- (void)revokePublic:(NSArray *)permissions {
    [self revoke:@"*" permissions:permissions];
}

- (NSArray *)usernamesFromWho:(id)who {
    NSMutableArray *usernames = [NSMutableArray array];
    if([who isKindOfClass:[NSArray class]]) {
        [usernames addObjectsFromArray:who];
    } else if([who isKindOfClass:[NSString class]]) {
        [usernames addObject:who];
    }
    return usernames;
}

#pragma mark - Convenience instance methods

- (void)save {
    [self save:nil];
}

- (void)save:(void(^)(NSError *error))completion {
    [_dataStore save:self completion:^(AXObject *object, NSError *error) {
        if(error) {
            if(completion) {
                completion(error);
            }
        } else {
            [self savePermissionChanges:^(NSError *error) {
                if(completion) {
                    completion(error);
                }
            }];
        }
    }];
}

- (void)savePermissionChanges:(void(^)(NSError *error))completion {
    if(_permissionGrants.count + _permissionRevokes.count == 0) {
        completion(nil);
        return;
    }
    [_permissionsService grant:_permissionGrants
                        revoke:_permissionRevokes
                      objectID:_objectID
                    completion:completion];
    [_permissionGrants removeAllObjects];
    [_permissionRevokes removeAllObjects];
}

- (void)remove {
    [self remove:nil];
}


- (void)remove:(void(^)(NSError *error))completion {
    [_dataStore delete:self completion:^(NSError *error) {
        if(completion) {
            completion(error);
        }
    }];
}

- (void)delete {
    [self remove];
}

- (void)delete:(void(^)(NSError *error))completion {
    [self remove:completion];
}

- (void)refresh {
    [self refresh:nil];
}

- (void)refresh:(void(^)(NSError *error))completion {
    if(_objectID) {
        [AXObject find:_collectionName
                withId:_objectID
            completion:^(AXObject *object, NSError *error) {
                [_properties addEntriesFromDictionary:object.allProperties];
                if(completion) {
                    completion(error);
                }
            }];
    } else {
        if(completion) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                completion(nil);
            });
        }
    }
}


#pragma mark - Convenience class methods

+ (AXObject *)create:(NSString *)collectionName {
    return [[[Appstax defaultContext] dataStore] create:collectionName];
}

+ (AXObject *)create:(NSString *)collectionName properties:(NSDictionary *)properties {
    return [[[Appstax defaultContext] dataStore] create:collectionName properties:properties];
}

+ (void)saveObjects:(NSArray *)objects completion:(void(^)(NSError *error))completion {
    [[[Appstax defaultContext] dataStore] saveObjects:objects completion:completion];
}

+ (void)findAll:(NSString *)collectionName completion:(void(^)(NSArray*, NSError*))completion {
    [[[Appstax defaultContext] dataStore] findAll:collectionName completion:completion];
}

+ (void)find:(NSString *)collectionName withId:(NSString *)objectID completion:(void(^)(AXObject *, NSError*))completion {
    [[[Appstax defaultContext] dataStore] find:collectionName withId:objectID completion:completion];
}

+ (void)find:(NSString *)collectionName with:(NSDictionary *)propertyValues completion:(void(^)(NSArray *objects, NSError *error))completion {
    [[[Appstax defaultContext] dataStore] find:collectionName
                                          with:propertyValues
                                    completion:completion];
}

+ (void)find:(NSString *)collectionName search:(NSDictionary *)propertyValues completion:(void(^)(NSArray *objects, NSError *error))completion {
    [[[Appstax defaultContext] dataStore] find:collectionName
                                        search:propertyValues
                                    completion:completion];
}

+ (void)find:(NSString *)collectionName search:(NSString *)searchString properties:(NSArray *)searchProperties completion:(void(^)(NSArray *objects, NSError *error))completion {
    [[[Appstax defaultContext] dataStore] find:collectionName search:searchString properties:searchProperties completion:completion];
}

+ (void)find:(NSString *)collectionName query:(void(^)(AXQuery *query))queryBlock completion:(void(^)(NSArray *objects, NSError *error))completion {
    [[[Appstax defaultContext] dataStore] find:collectionName
                                         query:queryBlock
                                    completion:completion];
}

+ (void)find:(NSString *)collectionName queryString:(NSString *)queryString completion:(void(^)(NSArray *objects, NSError *error))completion {
    [[[Appstax defaultContext] dataStore] find:collectionName
                                   queryString:queryString
                                    completion:completion];
}

@end
