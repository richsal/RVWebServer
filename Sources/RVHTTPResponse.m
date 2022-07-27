//
//  RVHTTPResponse.m
//  ProVideoPlayer 2
//
//  Created by Greg Harris on 12/10/12.
//  Copyright (c) 2012 Renewed Vision. All rights reserved.
//

#import "RVHTTPResponse.h"
#import "HTTPLogging.h"

// Log levels: off, error, warn, info, verbose
// Other flags: trace
//static const int httpLogLevel = HTTP_LOG_LEVEL_WARN; // | HTTP_LOG_FLAG_TRACE;

@implementation RVHTTPResponse

- (id)init {
	return [self initWithStatus:200];
}

- (id)initWithStatus:(NSInteger)statusCode {
	self = [super init];
	if (self) {
		_status = statusCode;
	}

	return self;
}

- (UInt64)contentLength {
	return 0;
}

- (UInt64)offset {
	return 0;
}

- (void)setOffset:(UInt64)offset {
	// Nothing to do
}

- (NSData *)readDataOfLength:(NSUInteger)length {
	return [NSData data];
}

- (BOOL)isDone {
	return YES;
}

- (NSInteger)status {
//	HTTPLogTrace();
	return _status;
}

@end
