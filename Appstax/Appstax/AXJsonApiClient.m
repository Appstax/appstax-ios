
#import "AXJsonApiClient.h"

@interface AXJsonApiClient()
@property NSString *appKey;
@property NSString *baseUrl;
@property NSURLSession *urlSession;
@property NSString *sessionID;
@end

@implementation AXJsonApiClient

- (instancetype)initWithAppKey:(NSString *)appKey baseUrl:(NSString *)baseUrl {
    self = [super init];
    if(self) {
        _appKey = appKey;
        _baseUrl = baseUrl;
        [self setupUrlSession];
    }
    return self;
}

- (void)setupUrlSession {
    _urlSession = [NSURLSession sharedSession];
}

- (void)postDictionary:(NSDictionary *)dictionary toUrl:(NSURL *)url completion:(void(^)(NSDictionary *, NSError*))completion {
    [self sendHttpBody:[self serializeDictionary:dictionary]
                 toUrl:url
                method:@"POST"
               headers:nil
            completion:^(NSData *responseData, NSError *error) {
                if(completion) {
                    completion([self deserializeDictionary:responseData], error);
                }
            }];
}

- (void)putDictionary:(NSDictionary *)dictionary toUrl:(NSURL *)url completion:(void(^)(NSDictionary *, NSError*))completion {
    [self sendHttpBody:[self serializeDictionary:dictionary]
                 toUrl:url
                method:@"PUT"
               headers:nil
            completion:^(NSData *responseData, NSError *error) {
                if(completion) {
                    completion([self deserializeDictionary:responseData], error);
                }
            }];
}

- (void)sendMultipartFormData:(NSDictionary *)dataParts toUrl:(NSURL *)url method:(NSString *)method completion:(void(^)(NSDictionary *dictionary, NSError *error))completion {
    NSString *boundary = [NSString stringWithFormat:@"Boundary-%@", [[NSUUID UUID] UUIDString]];
    NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary];
    NSMutableData *body = [NSMutableData data];
    
    for(NSString *partName in dataParts.keyEnumerator) {
        NSDictionary *part = dataParts[partName];
        NSString *filename = part[@"filename"];
        NSString *mimetype = part[@"mimeType"];
        NSData *data = part[@"data"];
        [body appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"; filename=\"%@\"\r\n", partName, filename] dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:[[NSString stringWithFormat:@"Content-Type: %@\r\n\r\n", mimetype] dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:data];
        [body appendData:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
    }
    [body appendData:[[NSString stringWithFormat:@"--%@--\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    
    [self sendHttpBody:body
                 toUrl:url
                method:@"PUT"
               headers:@{@"Content-Type":contentType}
            completion:^(NSData *responseData, NSError *error) {
                if(completion) {
                    completion([self deserializeDictionary:responseData], error);
                }
            }];
}

- (void)sendHttpBody:(NSData *)httpBody toUrl:(NSURL *)url method:(NSString *)method headers:(NSDictionary *)headers completion:(void(^)(NSData *responseData, NSError *error))completion {
    NSMutableURLRequest *request = [self makeRequestWithMethod:method url:url headers:headers];
    [request setHTTPBody:httpBody];
    [NSURLProtocol setProperty:request.HTTPBody forKey:@"HTTPBody" inRequest:request];
    id taskCompletionHandler = ^(NSData *data, NSURLResponse *response, NSError *error) {
        [self logResponse:response data:data error:error];
        if(!completion) { return; }
        if(!error) {
            error = [self errorFromResponse:response data:data];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(error ? nil : data, error);
        });
    };
    [self logRequest:request];
    [[_urlSession uploadTaskWithRequest:request
                               fromData:nil
                      completionHandler:taskCompletionHandler] resume];
}

- (void)arrayFromUrl:(NSURL *)url completion:(void(^)(NSArray*, NSError*))completion {
    [self dataFromUrl:url completion:^(NSData *data, NSError *error) {
        if(completion) {
            completion([self deserializeArray:data], error);
        }
    }];
}

- (void)dictionaryFromUrl:(NSURL *)url completion:(void(^)(NSDictionary*, NSError*))completion {
    [self dataFromUrl:url completion:^(NSData *data, NSError *error) {
        if(completion) {
            completion([self deserializeDictionary:data], error);
        }
    }];
}

- (void)dataFromUrl:(NSURL *)url completion:(void(^)(NSData *data, NSError *error))completion {
    NSMutableURLRequest *request = [self makeRequestWithMethod:@"GET" url:url headers:nil];
    id taskCompletionHandler = ^(NSData *data, NSURLResponse *response, NSError *error) {
        [self logResponse:response data:data error:error];
        if(!completion) { return; }
        if(!error) {
            error = [self errorFromResponse:response data:data];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(error ? nil : data, error);
        });
    };
    [self logRequest:request];
    [[_urlSession dataTaskWithRequest:request
                    completionHandler:taskCompletionHandler] resume];
}

- (void)deleteUrl:(NSURL *)url completion:(void(^)(NSError *error))completion {
    NSMutableURLRequest *request = [self makeRequestWithMethod:@"DELETE" url:url headers:nil];
    id taskCompletionHandler = ^(NSData *data, NSURLResponse *response, NSError *error) {
        [self logResponse:response data:data error:error];
        if(!completion) { return; }
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(error);
        });
    };
    [self logRequest:request];
    [[_urlSession dataTaskWithRequest:request
                    completionHandler:taskCompletionHandler] resume];
}

- (void)logRequest:(NSURLRequest *)request {
    //NSLog(@"API Request: %@", request);
}

- (void)logResponse:(NSURLResponse *)response data:(NSData *)data error:(NSError *)error {
    //NSLog(@"API Response: %@", response);
    //NSLog(@"API Response body \n%@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
    if(!error) {
        error = [self errorFromResponse:response data:data];
    }
    if(error) {
        NSLog(@"Appstax error: %@", error);
    }
}

- (NSMutableURLRequest *)makeRequestWithMethod:(NSString *)method url:(NSURL *)url headers:(NSDictionary *)headers {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:method];
    [request setValue:_appKey forHTTPHeaderField:@"x-appstax-appkey"];
    [request setValue:_sessionID forHTTPHeaderField:@"x-appstax-sessionid"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    for(NSString *key in headers.keyEnumerator) {
        [request setValue:headers[key] forHTTPHeaderField:key];
    }
    return request;
}

- (NSError *)errorFromResponse:(NSURLResponse *)response data:(NSData *)data {
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;

    NSError *error;
    if(httpResponse.statusCode / 100 != 2) {
        error = [NSError errorWithDomain:@"AXJsonApiClientHttpError"
                                    code:httpResponse.statusCode
                                userInfo:@{@"errorMessage":[self errorMessageFromData:data]}];
    }
    
    return error;
}

- (NSString *)errorMessageFromData:(NSData *)data {
    NSString *message = [self deserializeDictionary:data][@"errorMessage"];
    if(message == nil) {
        message = @"";
    }
    return message;
}

- (NSURL *)urlByConcatenatingStrings:(NSArray *)strings {
    NSArray *full = [@[_baseUrl] arrayByAddingObjectsFromArray:strings];
    return [NSURL URLWithString:[full componentsJoinedByString:@""]];
}

- (NSURL *)urlFromTemplate:(NSString *)template parameters:(NSDictionary *)parameters {
    NSMutableString *url = [NSMutableString stringWithString:template];
    if([url hasPrefix:@"/"]) {
        [url replaceCharactersInRange:NSMakeRange(0, 1) withString:@""];
        [url insertString:_baseUrl atIndex:0];
    }
    for(NSString *key in parameters.keyEnumerator) {
        [url replaceOccurrencesOfString:[@":" stringByAppendingString:key]
                             withString:[self urlEncode:parameters[key]]
                                options:NSLiteralSearch
                                  range:NSMakeRange(0, url.length)];
    }
    return [NSURL URLWithString:url];
}

- (NSString *)urlEncode:(NSString *)string {
    // From http://stackoverflow.com/questions/3423545/objective-c-iphone-percent-encode-a-string/3426140#3426140
    NSMutableString * output = [NSMutableString string];
    const unsigned char * source = (const unsigned char *)[string UTF8String];
    unsigned long sourceLen = strlen((const char *)source);
    for (int i = 0; i < sourceLen; ++i) {
        const unsigned char thisChar = source[i];
        if (thisChar == ' '){
            [output appendString:@"+"];
        } else if (thisChar == '.' || thisChar == '-' || thisChar == '_' || thisChar == '~' ||
                   (thisChar >= 'a' && thisChar <= 'z') ||
                   (thisChar >= 'A' && thisChar <= 'Z') ||
                   (thisChar >= '0' && thisChar <= '9')) {
            [output appendFormat:@"%c", thisChar];
        } else {
            [output appendFormat:@"%%%02X", thisChar];
        }
    }
    return output;
}

- (NSData *)serializeDictionary:(NSDictionary *)dictionary {
    if(dictionary == nil) {
        return nil;
    }
    NSError *error;
    return [NSJSONSerialization dataWithJSONObject:dictionary options:0 error:&error];
}

- (NSDictionary *)deserializeDictionary:(NSData *)data {
    if(data == nil) {
        return nil;
    }
    NSError *error;
    return [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
}

- (NSArray *)deserializeArray:(NSData *)data {
    if(data == nil) {
        return nil;
    }
    NSError *error;
    return [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
}



@end
