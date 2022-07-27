//
//  NSString+RVBonjourUtilities.m
//  ProPresenter6
//
//  Created by Greg Harris on 5/6/14.
//  Copyright (c) 2014 Renewed Vision. All rights reserved.
//

#import "NSString+RVBonjourUtilities.h"

@implementation NSString (RVBonjourUtilities)

// There are two forms of a Bonjour name with a suffix, "GBH-2" and "GBH (2)". The one with a dash is the form used in a URL, the one with paranthesis is the display name.
- (NSString *)stringByRemovingBonjourSuffixFromName {
	NSString *trimmedSelf = [self stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	NSError *e = nil;
	NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@" \\(\\d+\\)$" options:NSRegularExpressionAnchorsMatchLines error:&e];
	NSRange range = [regex rangeOfFirstMatchInString:trimmedSelf options:0 range:NSMakeRange(0, trimmedSelf.length)];
	if (range.location != NSNotFound) {
		trimmedSelf = [trimmedSelf stringByReplacingCharactersInRange:range withString:@""];
	}
	return trimmedSelf;
}

- (NSString *)stringByRemovingBonjourSuffixFromHostName {
	NSArray *comps = [self componentsSeparatedByString:@"-"];
	NSUInteger count = [comps count];
	if (count > 1) {
		NSString *lastNumString = [comps objectAtIndex:count - 1];
		if ([lastNumString respondsToSelector:@selector(integerValue)] && [lastNumString integerValue] > 0) {
			NSMutableArray *mutableComps = [comps mutableCopy];
			[mutableComps removeLastObject];
			return [mutableComps componentsJoinedByString:@"-"];
		}
	}
	return self;
}

- (NSString *)bonjourBaseName {
	NSString *temp = self;
	if ([temp rangeOfString:@":"].location != NSNotFound) {
		temp = [temp substringToIndex:[temp rangeOfString:@":"].location];
	}
	if ([temp rangeOfString:@".local"].location != NSNotFound) {
		temp = [temp substringToIndex:[temp rangeOfString:@".local"].location];
	}
	if ([temp hasSuffix:@")"]) {
		return [temp stringByRemovingBonjourSuffixFromName];
	}
	return [temp stringByRemovingBonjourSuffixFromHostName];
}

- (NSNumber *)bonjourSuffixNumber {
	NSString *baseName = [self bonjourBaseName];
	NSString *theRest = [self substringFromIndex:baseName.length];
	if (theRest.length) {
		NSScanner *s = [NSScanner scannerWithString:theRest];
		[s scanUpToCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet] intoString:nil];
		NSInteger i = 0;
		if ([s scanInteger:&i]) {
			return @(i);
		}
	}
	return nil;
}


- (NSString *)urlSafeHostNameForBonjourName {
	// what about stripping out special characters? I know that apostrophes are stripped out for a URL host name. I can't find a spec for how that's handled.
	NSString *base = [self bonjourBaseName];
	NSNumber *suff = [self bonjourSuffixNumber];
	if (suff) {
		return [NSString stringWithFormat:@"%@-%ld", base, suff.integerValue];
	}
	return base;
}

@end
