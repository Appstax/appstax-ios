
#import "AXStubs.h"

@implementation AXStubs

+ (void)method:(NSString *)method urlPath:(NSString *)urlPath response:(id)responseObject statusCode:(int)statusCode {
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [[request.URL path] isEqualToString:urlPath] &&
        [request.HTTPMethod isEqualToString:method];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        return [OHHTTPStubsResponse responseWithJSONObject:responseObject
                                                statusCode:statusCode headers:nil];
    }];
}

+ (void)method:(NSString *)method urlPath:(NSString *)urlPath responding:(OHHTTPStubsResponseBlock)responseBlock {
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [[request.URL path] isEqualToString:urlPath] &&
        [request.HTTPMethod isEqualToString:method];
    } withStubResponse:responseBlock];
}

@end
