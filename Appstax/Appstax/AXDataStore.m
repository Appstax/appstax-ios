
#import "AXDataStore.h"
#import "AXQuery.h"
#import "AppstaxInternals.h"
#import <Appstax/Appstax-Swift.h>

@interface AXDataStore()
@property AXApiClient *apiClient;
@end

@implementation AXDataStore

- (instancetype)initWithApiClient:(AXApiClient *)apiClient {
    self = [super init];
    if(self) {
        _apiClient = apiClient;
    }
    return self;
}

- (AXObject *)create:(NSString *)collectionName {
    return [self create:collectionName properties:nil status:AXObjectStatusNew];
}

- (AXObject *)create:(NSString *)collectionName properties:(NSDictionary *)properties {
    return [self create:collectionName properties:properties status:AXObjectStatusNew];
}

- (AXObject *)create:(NSString *)collectionName properties:(NSDictionary *)properties status:(AXObjectStatus)status {
    return [[AXObject alloc] initWithCollectionName:collectionName properties:properties status:status];
}


- (void)save:(AXObject *)object completion:(void(^)(AXObject *, NSError*))completion {
    object.status = AXObjectStatusSaving;
    if(object.objectID == nil) {
        if(object.hasUnsavedFiles) {
            [self saveNewObjectWithFiles:object completion:completion];
        } else {
            [self saveNewObjectWithoutFiles:object completion:completion];
        }
    } else {
        [self updateObject:object completion:completion];
    }
}

- (void)updateObject:(AXObject *)object completion:(void(^)(AXObject *, NSError*))completion {
    NSURL *url = [_apiClient urlByConcatenatingStrings:@[@"objects/", object.collectionName, @"/", object.objectID]];
    [_apiClient putDictionary:object.allPropertiesForSaving toUrl:url completion:^(NSDictionary *dictionary, NSError *error) {
        if(!error) {
            [[[Appstax defaultContext] fileService] saveFilesForObject:object completion:^(NSError *error) {
                object.status = error ? AXObjectStatusModified : AXObjectStatusSaved;
                if(completion != nil) {
                    completion(object, error);
                }
            }];
        } else if(error && completion) {
            completion(nil, error);
        }
    }];
}

- (void)saveNewObjectWithoutFiles:(AXObject *)object completion:(void(^)(AXObject *, NSError*))completion {
    NSURL *url = [_apiClient urlByConcatenatingStrings:@[@"objects/", object.collectionName]];
    [_apiClient postDictionary:object.allPropertiesForSaving toUrl:url completion:^(NSDictionary *dictionary, NSError *error) {
        object.status = error ? AXObjectStatusModified : AXObjectStatusSaved;
        if(!error) {
            if([dictionary.allKeys containsObject:@"sysObjectId"]) {
                [object overrideObjectID:dictionary[@"sysObjectId"]];
            }
            completion(object, nil);
        } else if(error && completion) {
            completion(nil, error);
        }
    }];
}

- (void)saveNewObjectWithFiles:(AXObject *)object completion:(void(^)(AXObject *, NSError*))completion {
    AXFileService *fileService = [[Appstax defaultContext] fileService];
    NSURL *url = [_apiClient urlByConcatenatingStrings:@[@"objects/", object.collectionName]];
    NSMutableDictionary *multipart = [NSMutableDictionary dictionary];
    
    for(NSString *key in object.allFileProperties.keyEnumerator) {
        AXFile *file = object[key];
        file.status = AXFileStatusSaving;
        multipart[key] = @{@"data":[fileService dataForFile:file],
                           @"mimeType":file.mimeType,
                           @"filename":file.filename };
    }
    multipart[@"sysObjectData"] = @{@"data":[_apiClient serializeDictionary:object.allPropertiesForSaving]};
    
    [_apiClient sendMultipartFormData:multipart
                                toUrl:url
                               method:@"POST"
                           completion:^(NSDictionary *dictionary, NSError *error) {
                               object.status = error ? AXObjectStatusModified : AXObjectStatusSaved;
                               if(!error) {
                                   if([dictionary.allKeys containsObject:@"sysObjectId"]) {
                                       [object overrideObjectID:dictionary[@"sysObjectId"]];
                                   }
                                   for(NSString *key in object.allFileProperties.keyEnumerator) {
                                       AXFile *file = object[key];
                                       file.status = AXFileStatusSaved;
                                       file.url = [fileService urlForFileName:file.filename objectID:object.objectID propertyName:key collectionName:object.collectionName];
                                   }
                               }
                               if(completion) {
                                   completion(object, error);
                               }
                           }];
}

- (void)saveObjects:(NSArray *)objects completion:(void(^)(NSError *error))completion {
    __block NSUInteger objectCount = objects.count;
    __block NSUInteger completionCount = 0;
    __block NSError *firstError;
    for(AXObject *object in objects) {
        [self save:object completion:^(AXObject *object, NSError *error) {
            completionCount++;
            if(firstError == nil && error != nil) {
                firstError = error;
            }
            if(completionCount == objectCount) {
                completion(firstError);
            }
        }];
    }
}

- (void)delete:(AXObject *)object completion:(void(^)(NSError *error))completion {
    NSURL *url = [_apiClient urlByConcatenatingStrings:@[@"objects/", object.collectionName, @"/", object.objectID]];
    [_apiClient deleteUrl:url completion:^(NSError *error) {
        completion(error);
    }];
}

- (void)findAll:(NSString *)collectionName completion:(void(^)(NSArray*, NSError*))completion {
    NSURL *url = [_apiClient urlByConcatenatingStrings:@[@"objects/", collectionName]];
    [_apiClient dictionaryFromUrl:url completion:^(NSDictionary *dictionary, NSError *error) {
        NSArray *objects = dictionary[@"objects"];
        NSMutableArray *axObjects = [NSMutableArray arrayWithCapacity:objects.count];
        for(NSDictionary *object in objects) {
            [axObjects addObject:[self create:collectionName properties:object status:AXObjectStatusSaved]];
        }
        completion([NSArray arrayWithArray:axObjects], error);
    }];
}

- (void)find:(NSString *)collectionName withId:(NSString *)objectID completion:(void(^)(AXObject *, NSError*))completion {
    NSURL *url = [_apiClient urlByConcatenatingStrings:@[@"objects/", collectionName, @"/", objectID]];
    [_apiClient dictionaryFromUrl:url completion:^(NSDictionary *object, NSError *error) {
        if(completion != nil) {
            AXObject *axObject = [self create:collectionName properties:object status:AXObjectStatusSaved];
            completion(axObject, error);
        }
    }];
}

- (void)find:(NSString *)collectionName with:(NSDictionary *)propertyValues completion:(void(^)(NSArray *objects, NSError *error))completion {
    AXQuery *query = [AXQuery query];
    NSArray *keys = [propertyValues.allKeys sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    for(NSString *key in keys) {
        [query string:key equals:propertyValues[key]];
    }
    [self find:collectionName queryString:query.queryString completion:completion];
}

- (void)find:(NSString *)collectionName search:(NSDictionary *)propertyValues completion:(void(^)(NSArray *objects, NSError *error))completion {
    AXQuery *query = [AXQuery query];
    [query setLogicalOperator:@"or"];
    for(NSString *property in propertyValues.keyEnumerator) {
        [query string:property contains:propertyValues[property]];
    }
    [self find:collectionName queryString:query.queryString completion:completion];
}

- (void)find:(NSString *)collectionName search:(NSString *)searchString properties:(NSArray *)searchProperties completion:(void(^)(NSArray *objects, NSError *error))completion {
    NSMutableDictionary *propertyValues = [NSMutableDictionary dictionary];
    for(NSString *property in searchProperties) {
        propertyValues[property] = searchString;
    }
    [self find:collectionName search:propertyValues completion:completion];
}

- (void)find:(NSString *)collectionName query:(void(^)(AXQuery *query))queryBlock completion:(void(^)(NSArray *objects, NSError *error))completion {
    AXQuery *query = [AXQuery query];
    queryBlock(query);
    [self find:collectionName queryString:query.queryString completion:completion];
}

- (void)find:(NSString *)collectionName queryString:(NSString *)queryString completion:(void(^)(NSArray *objects, NSError *error))completion {
    AXQuery *query = [[AXQuery alloc] initWithQueryString:queryString];
    NSURL *url = [_apiClient urlFromTemplate:@"/objects/:collection?filter=:filter"
                                  parameters:@{@"collection":collectionName,
                                               @"filter":query.queryString}];
    [_apiClient dictionaryFromUrl:url completion:^(NSDictionary *dictionary, NSError *error) {
        if(!completion) { return; }
        NSArray *objects = dictionary[@"objects"];
        NSMutableArray *axObjects = [NSMutableArray arrayWithCapacity:objects.count];
        for(NSDictionary *object in objects) {
            [axObjects addObject:[self create:collectionName properties:object status:AXObjectStatusSaved]];
        }
        completion([NSArray arrayWithArray:axObjects], error);
    }];
}

#pragma mark - Notifications

@end
