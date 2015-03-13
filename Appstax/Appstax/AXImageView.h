
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "AXFile.h"

@interface AXImageView : UIImageView

+ (instancetype)viewWithFile:(AXFile *)file;
+ (instancetype)viewWithFile:(AXFile *)file size:(CGSize)size crop:(BOOL)crop;

- (void)loadFile:(AXFile *)file;
- (void)loadFile:(AXFile *)file size:(CGSize)size crop:(BOOL)crop;

@end
