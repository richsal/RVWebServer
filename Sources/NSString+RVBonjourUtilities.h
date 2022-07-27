//
//  NSString+RVBonjourUtilities.h
//  ProPresenter6
//
//  Created by Greg Harris on 5/6/14.
//  Copyright (c) 2014 Renewed Vision. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (RVBonjourUtilities)
- (NSString *)stringByRemovingBonjourSuffixFromName;
- (NSString *)stringByRemovingBonjourSuffixFromHostName;
- (NSString *)bonjourBaseName;
- (NSNumber *)bonjourSuffixNumber;
- (NSString *)urlSafeHostNameForBonjourName;
@end
