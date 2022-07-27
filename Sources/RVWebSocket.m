//
//  RVWebSocket.m
//  ProVideoPlayer 2
//
//  Created by Greg Harris on 12/14/12.
//  Copyright (c) 2012 Renewed Vision. All rights reserved.
//

#import "RVWebSocket.h"
@import CocoaAsyncSocket;

#import "HTTPLogging.h"

//static const int httpLogLevel = HTTP_LOG_LEVEL_VERBOSE | HTTP_LOG_FLAG_TRACE;

@implementation RVWebSocket {
	dispatch_source_t heartbeatTimer;
}

- (NSString *)remoteHostName {
	if ([asyncSocket isConnected]) {
		return [NSString stringWithFormat:@"%@", [asyncSocket connectedHost]];
	}
	return nil;
}

- (NSUInteger)remoteHostPort {
	if ([asyncSocket isConnected]) {
		return [asyncSocket connectedPort];
	}
	return 0;
}

- (NSString *)remoteHostNameAndPort {
	if ([asyncSocket isConnected]) {
		NSString *host = nil;
		UInt16 port = 0;
		[GCDAsyncSocket getHost:&host
						   port:&port
					fromAddress:asyncSocket.connectedAddress];
		return [NSString stringWithFormat:@"%@:%d", host, port];
	}
	return nil;
}

- (void)didOpen {
	[super didOpen];

	BOOL disablePing = [[NSUserDefaults standardUserDefaults] boolForKey:@"RVDisableWebSocketHeartbeatPing"];
	if (!disablePing && !heartbeatTimer) {
		heartbeatTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
		if (heartbeatTimer) {
			UInt8 bang = 0x21; // just some random data, it appears that the CocoaHTTPServer WebSocket implementation doesn't read a ping with no data properly. 0x21 => '!'
			NSData *heartbeatPingData = [NSData dataWithBytes:&bang length:1];
			dispatch_source_set_timer(heartbeatTimer, dispatch_time(DISPATCH_TIME_NOW, 0), 10 * NSEC_PER_SEC, (1ull * NSEC_PER_SEC) / 10);
			dispatch_source_set_event_handler(heartbeatTimer, ^{
				[self sendPingData:heartbeatPingData
					   withTimeout:8.0
					  timeoutBlock:^{
						  NSLog(@"Socket ping timed out, disconnecting...");
						  [self stop];
					  }];
			});
			dispatch_resume(heartbeatTimer);
		}
	}
}

- (void)didClose {
	[super didClose];

	if (heartbeatTimer) {
		dispatch_source_cancel(heartbeatTimer);
		heartbeatTimer = nil;
	}
}


@end
