
#import "NoteColors.h"

@implementation NoteColors

+ (UIColor *)defaultColor {
    return [self allColors][0];
}

+ (NSArray *)allColors {
    return @[[self colorFromRGBString:@"24,73,128"],
             [self colorFromRGBString:@"24,171,172"],
             [self colorFromRGBString:@"65,143,43"],
             [self colorFromRGBString:@"113,83,153"],
             [self colorFromRGBString:@"165,62,151"],
             [self colorFromRGBString:@"216,176,109"],
             [self colorFromRGBString:@"241,142,24"],
             [self colorFromRGBString:@"240,73,23"],
             [self colorFromRGBString:@"219,24,23"],
             [self colorFromRGBString:@"132,23,24"],
             [self colorFromRGBString:@"25,143,242"],
             [self colorFromRGBString:@"24,210,212"],
             [self colorFromRGBString:@"128,241,65"],
             [self colorFromRGBString:@"172,125,241"],
             [self colorFromRGBString:@"241,82,217"],
             [self colorFromRGBString:@"242,215,25"],
             [self colorFromRGBString:@"0,196,103"],
             ];
}

+ (UIColor *)colorFromRGBString:(NSString *)rgb {
    NSArray *comp = [rgb componentsSeparatedByString:@","];
    return [UIColor colorWithRed:[comp[0] intValue] / 255.0
                           green:[comp[1] intValue] / 255.0
                            blue:[comp[2] intValue] / 255.0
                           alpha:1];
}

@end
