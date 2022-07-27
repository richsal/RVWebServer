//
//  RVWebSocket.h
//  ProVideoPlayer 2
//
//  Created by Greg Harris on 12/14/12.
//  Copyright (c) 2012 Renewed Vision. All rights reserved.
//

#import "WebSocket.h"
#import "ProNetworkController.h"

typedef enum : NSUInteger {
	RVWebSocketTypeNone = 0,
	RVWebSocketTypeMasterControl,
	RVWebSocketTypeTextStream,
	RVWebSocketTypeRemote,
	RVWebSocketTypeLiveStream,
	RVWebSocketTypeStageDisplay
} RVWebSocketType;


@interface RVWebSocket : WebSocket
@property (assign) RVWebSocketType type;
@property (weak) ProNetworkController *networkController;


- (NSString *)remoteHostName;
- (NSUInteger)remoteHostPort;
- (NSString *)remoteHostNameAndPort;

@end
