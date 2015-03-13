
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface AXFile : NSObject

@property (readonly) NSString *filename;
@property (readonly) NSData *data;
@property (readonly) NSString *dataPath;
@property (readonly) NSString *mimeType;

+ (instancetype)fileWithData:(NSData *)data name:(NSString *)name;
+ (instancetype)fileWithImage:(UIImage *)image name:(NSString *)name;
+ (instancetype)fileWithPath:(NSString *)path;

- (void)load:(void(^)(NSError *error))completion;
- (void)loadImageSize:(CGSize)size crop:(BOOL)crop completion:(void(^)(NSError *error))completion;
- (void)unload;

@end
