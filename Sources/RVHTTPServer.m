//
//  RVHTTPServer.m
//  ProVideoPlayer 2
//
//  Created by Greg Harris on 12/13/12.
//  Copyright (c) 2012 Renewed Vision. All rights reserved.
//

#import "RVHTTPServer.h"
#import "HTTPLogging.h"
@import CocoaAsyncSocket;

#import "ProNetworkController.h"

// Log levels: off, error, warn, info, verbose
// Other flags: trace
//static const int httpLogLevel = HTTP_LOG_LEVEL_VERBOSE | HTTP_LOG_FLAG_TRACE;

@interface ProNetworkController (RVHTTPServerPrivate)
+ (ProNetworkController *)sharedNetworkController;
- (void)updateUIForBonjourDidPublish;
- (void)httpServerBonjourDidNotPublish;
@end

@interface HTTPServer (private)
- (void)unpublishBonjour;
- (void)publishBonjour;

+ (void)startBonjourThreadIfNeeded;
+ (void)performBonjourBlock:(dispatch_block_t)block;
@end

@interface RVHTTPServer ()
@end

@implementation RVHTTPServer

- (void)netServiceDidPublish:(NSNetService *)ns {
	[super netServiceDidPublish:ns];
	dispatch_async(dispatch_get_main_queue(), ^{
		[[ProNetworkController sharedNetworkController] updateUIForBonjourDidPublish];
	});
}

- (void)netService:(NSNetService *)ns didNotPublish:(NSDictionary *)errorDict {
	[super netService:ns didNotPublish:errorDict];
	[[ProNetworkController sharedNetworkController] httpServerBonjourDidNotPublish];
}

- (void)publishBonjour {
//	HTTPLogTrace();

	NSAssert(dispatch_get_specific(IsOnServerQueueKey) != NULL, @"Must be on serverQueue");

	if (type) {
		netService = [[NSNetService alloc] initWithDomain:domain type:type name:name port:[asyncSocket localPort]];
		[netService setDelegate:self];

		NSNetService *theNetService = netService;
		NSData *txtRecordData = nil;
		if (txtRecordDictionary)
			txtRecordData = [NSNetService dataFromTXTRecordDictionary:txtRecordDictionary];

		dispatch_block_t bonjourBlock = ^{

			[theNetService removeFromRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
			[theNetService scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
			[theNetService publishWithOptions:0];

			// Do not set the txtRecordDictionary prior to publishing!!!
			// This will cause the OS to crash!!!
			if (txtRecordData) {
				[theNetService setTXTRecordData:txtRecordData];
			}
		};

		[[self class] startBonjourThreadIfNeeded];
		[[self class] performBonjourBlock:bonjourBlock];
	}
}

- (NSString *)publishedHostname {
	__block NSString *result;

	dispatch_sync(serverQueue, ^{

		if (self->netService == nil) {
			result = nil;
		} else {

			dispatch_block_t bonjourBlock = ^{
				result = [[self->netService hostName] copy];
			};

			[[self class] performBonjourBlock:bonjourBlock];
		}
	});

	return result;
}

@end
