//
//  ProHTTPConnection.m
//  ProPresenter6
//
//  Created by Greg Harris on 2/21/14.
//  Copyright (c) 2014 Renewed Vision. All rights reserved.
//


#import "ProHTTPConnection.h"
#import "ProNetworkController.h"

#import "RVHTTPResponse.h"
#import "HTTPMessage.h"
#import "HTTPDataResponse.h"
#import "HTTPFileResponse.h"
#import "HTTPAsyncFileResponse.h"
#import "HTTPLogging.h"
#import "DDKeychain.h"
#import "RVWebSocket.h"

#import "ProHTTPConstants.h"
#import "NSString+URLEncoding.h"


// copied from DAVConnection.m, so we don't have to modify
#define HTTP_ASYNC_FILE_RESPONSE_THRESHOLD (16 * 1024 * 1024)

// Log levels: off, error, warn, info, verbose
// Other flags: trace
//static const int httpLogLevel = HTTP_LOG_LEVEL_VERBOSE | HTTP_LOG_FLAG_TRACE;


@implementation ProHTTPConnection

- (id)initWithAsyncSocket:(GCDAsyncSocket *)newSocket configuration:(HTTPConfig *)aConfig {
	self = [super initWithAsyncSocket:newSocket configuration:aConfig];
	return self;
}

- (NSObject<HTTPResponse> *)httpResponseForMethod:(NSString *)method webUIRelativePath:(NSString *)path {
	NSString *htmlDirectoryPath = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"/Contents/Resources/html"];
	if ([method isEqualToString:@"GET"]) {
		if ([path isEqualToString:@""] || [path isEqualToString:@"/"]) {
			NSString *indexFilePath = [htmlDirectoryPath stringByAppendingPathComponent:@"index.html"];
			return [[HTTPFileResponse alloc] initWithFilePath:indexFilePath forConnection:self];
		} else {
			return [[HTTPFileResponse alloc] initWithFilePath:[htmlDirectoryPath stringByAppendingPathComponent:path] forConnection:self];
		}
	}
	return [[RVHTTPResponse alloc] initWithStatus:404];
}


- (NSObject<HTTPResponse>*)dataReturnedFromHTML:(NSString*)html {
	NSData *htmlData = [html dataUsingEncoding:NSUTF8StringEncoding];
	if (htmlData.length) {
		return [[HTTPDataResponse alloc] initWithData:htmlData];
	}
	return [[RVHTTPResponse alloc] initWithStatus:500];
}

- (NSObject<HTTPResponse> *)httpResponseForMethod:(NSString *)method URI:(NSString *)path {
//	HTTPLogTrace();

	if ([path hasPrefix:RVHTTPURI_html]) {
		return [self httpResponseForMethod:method
						 webUIRelativePath:[path substringFromIndex:[RVHTTPURI_html length]]];
	}

	path = [path URLDecodedString];

	NSArray *pathComps = [path componentsSeparatedByString:@"/"];
	NSEnumerator *pathEnumerator = [pathComps objectEnumerator];
	NSString *pathPart;
	do
		pathPart = pathEnumerator.nextObject;
	while (pathPart && pathPart.length == 0);
    
    NSDictionary *sportsScores = [[[ProNetworkController sharedNetworkController] dataSource] sportsScores];

	if ([method isEqualToString:@"HEAD"] || [method isEqualToString:@"GET"]) {
		if ([pathPart isEqualToString:RVHTTPURI_xml]) {
			do
				pathPart = pathEnumerator.nextObject;
			while (pathPart && pathPart.length == 0);

			if ([pathPart isEqualToString:RVHTTPURI_presentation]) {
				return [[RVHTTPResponse alloc] initWithStatus:500];
			}

		} else if ([pathPart isEqualToString:RVHTTPURI_html]) {
			do
				pathPart = pathEnumerator.nextObject;
			while (pathPart && pathPart.length == 0);

                if ([pathPart containsString:RVHTTPURI_custom]){
				NSURLComponents *comps = [[NSURLComponents alloc] initWithString: path];
				NSInteger page = -1;
				if (comps.query){
					NSURLQueryItem *item = comps.queryItems.firstObject;
					if ([item.name isEqualToString: @"group"]) {
						page = [item.value integerValue]-1;
					}
				}
                NSString *html = [[[ProNetworkController sharedNetworkController] codeSource] htmlForCustomController: sportsScores groupIndex: page];
				return [self dataReturnedFromHTML:html];
			} else if ([pathPart isEqualToString:RVHTTPURI_resource]) {
				do
					pathPart = pathEnumerator.nextObject;
				while (pathPart && pathPart.length == 0);
				if (pathPart == nil || pathPart.length == 0) {
					return [[RVHTTPResponse alloc] initWithStatus:400]; // bad request, there's no presentation specified
				}

				NSString *pathForResource;
				NSString *path = [[NSString stringWithFormat: @"~/Library/Application Support/RenewedVision/ProPresenter-Scoreboard/%@", pathPart] stringByExpandingTildeInPath];
				// check for custom override
				if ([[NSFileManager defaultManager] fileExistsAtPath: path] ) {
					pathForResource = path;
				} else {
					pathForResource = [[NSBundle mainBundle] pathForResource: pathPart ofType:nil];
				}
				
				if (!pathForResource.length){
					return [[RVHTTPResponse alloc] initWithStatus:404];
				}
				return [[HTTPFileResponse alloc] initWithFilePath:pathForResource forConnection:self];
			}
			return [[RVHTTPResponse alloc] initWithStatus:500];

		}


	} else if ([method isEqualToString:@"POST"]) {
		if ([pathPart isEqualToString:RVHTTPURI_html]) {
			do
				pathPart = pathEnumerator.nextObject;
			while (pathPart && pathPart.length == 0);
			 if ([pathPart isEqualToString:RVHTTPURI_custom]) { // this could be generic for scoreboards in general){
				do
					pathPart = pathEnumerator.nextObject;
				while (pathPart && pathPart.length == 0);

				NSString *postString = [[[NSString alloc] initWithData:requestContentBody encoding:NSUTF8StringEncoding] URLDecodedString];

				if (!postString.length)
					return [[RVHTTPResponse alloc] initWithStatus:400]; // bad request

				NSArray *comps = [postString componentsSeparatedByString:@"+"];
				NSString *action = nil;
				NSString *arguements = nil;
				for (NSString *eachString in comps) {
					NSArray *pair = [eachString componentsSeparatedByString:@"="];
					if (pair.count != 2)
						continue;
					if ([pair[1] isEqualToString:@"null"])
						continue;

					if ([pair[0] isEqualToString:RVHTTPURI_action]) {
						action = pair[1];
						continue;
					}

					if ([pair[0] isEqualToString:RVHTTPURI_tag]) {
						arguements = pair[1];
						continue;
					}
				}

				if (!action)
					return [[RVHTTPResponse alloc] initWithStatus:400]; // bad request

                 NSString *newValue = [[[ProNetworkController sharedNetworkController] dataSource] sportsControllerAction:action withArgumentString:arguements];
				return [[HTTPDataResponse alloc] initWithData:[newValue dataUsingEncoding:NSUTF8StringEncoding]]; // OK
			}
		}
	}

	return [super httpResponseForMethod:method URI:path];
}

- (BOOL)supportsMethod:(NSString *)method atPath:(NSString *)path {
	if ([method isEqualToString:@"POST"]) {
		if ([path rangeOfString:RVHTTPURI_message].location != NSNotFound ||
            [path rangeOfString:RVHTTPURI_scoreBoard].location != NSNotFound ||
            [path rangeOfString:RVHTTPURI_custom].location != NSNotFound ||
			[path rangeOfString:RVHTTPURI_lacrosse].location != NSNotFound ||
			[path rangeOfString:RVHTTPURI_soccer].location != NSNotFound ||
			[path rangeOfString:RVHTTPURI_footballClock].location != NSNotFound) {
			return YES;
		}
	} else if ([method isEqualToString:@"DELETE"]) {
	}
	return [super supportsMethod:method atPath:path];
}

- (BOOL)expectsRequestBodyFromMethod:(NSString *)method atPath:(NSString *)path {
	// PUT or POST Response
	if ([method isEqualToString:@"PUT"] || [method isEqualToString:@"POST"]) {
		return YES;
	}

	// DAV Response
	if ([method isEqual:@"PROPFIND"] || [method isEqual:@"MKCOL"]) {
		return [request headerField:@"Content-Length"] ? YES : NO;
	}
	if ([method isEqual:@"LOCK"]) {
		return YES;
	}

	return NO;
}

- (NSString *)filePathForURI:(NSString *)path allowDirectory:(BOOL)allowDirectory {
//	HTTPLogTrace();
	return [super filePathForURI:path allowDirectory:allowDirectory];
}

// fix a bug in super's implementation where parameters without a value are ignored, instead put them in the dictionary with an NSNull value
- (NSDictionary *)parseParams:(NSString *)query {
	NSArray *components = [query componentsSeparatedByString:@"&"];
	NSMutableDictionary *result = [NSMutableDictionary dictionaryWithCapacity:[components count]];
	NSUInteger i;
	for (i = 0; i < [components count]; i++) {
		NSString *component = [components objectAtIndex:i];
		if ([component length] > 0) {
			NSString *key = nil;
			NSString *value = nil;
			NSRange range = [component rangeOfString:@"="];
			if (range.location != NSNotFound) {
				NSString *escapedKey = [component substringToIndex:(range.location + 0)];
				NSString *escapedValue = [component substringFromIndex:(range.location + 1)];
				if ([escapedKey length] > 0) {
					CFStringRef k, v;
					k = CFURLCreateStringByReplacingPercentEscapes(NULL, (__bridge CFStringRef)escapedKey, CFSTR(""));
					v = CFURLCreateStringByReplacingPercentEscapes(NULL, (__bridge CFStringRef)escapedValue, CFSTR(""));
					key = (__bridge_transfer NSString *)k;
					value = (__bridge_transfer NSString *)v;
				}
			} else { // the whole component is a key and there's no value
				CFStringRef k;
				k = CFURLCreateStringByReplacingPercentEscapes(NULL, (__bridge CFStringRef)component, CFSTR(""));
				key = (__bridge_transfer NSString *)k;
			}
			if (key) {
				if (value) {
					[result setObject:value forKey:key];
				} else {
					[result setObject:[NSNull null] forKey:key];
				}
			}
		}
	}
	return result;
}

- (WebSocket *)webSocketForURI:(NSString *)path {
//	HTTPLogTrace2(@"%@[%p]: webSocketForURI: %@", THIS_FILE, self, path);
	if ([path isEqualToString:@"/" ProHTTPURI_remote]) {

	} else if ([path isEqualToString:@"/" ProHTTPURI_mastercontrol]) {
		
	} else if ([path isEqualToString:@"/" ProHTTPURI_textstream]) {
		
	} else if ([path isEqualToString:@"/" ProHTTPURI_livestream]) {
	
	}
	return nil;
}

- (BOOL)isSecureServer {
//	HTTPLogTrace();
	return [[ProNetworkController sharedNetworkController] servingHTTPUsesSSL];
}

- (BOOL)isPasswordProtected:(NSString *)path {
//	HTTPLogTrace();
	ProNetworkController *nc = [ProNetworkController sharedNetworkController];
	return nc.servingHTTPUser && nc.servingHTTPPassword;
}

- (BOOL)useDigestAccessAuthentication {
//	HTTPLogTrace();
	return YES;
}

- (NSString *)passwordForUser:(NSString *)username {
//	HTTPLogTrace();
	return [DDKeychain passwordForHTTPServerWithUsername:username];
}


@end
