
#import <UIKit/UIKit.h>

FOUNDATION_EXPORT double AppstaxVersionNumber;
FOUNDATION_EXPORT const unsigned char AppstaxVersionString[];

#import <Foundation/Foundation.h>
#import "AXObject.h"
#import "AXUser.h"
#import "AXFile.h"
#import "AXImageView.h"

@interface Appstax : NSObject

+ (void)setAppKey:(NSString *)appKey;
+ (NSBundle *)frameworkBundle;

@end
