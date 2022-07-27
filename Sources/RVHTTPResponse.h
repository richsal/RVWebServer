//
//  RVHTTPResponse.h
//  ProVideoPlayer 2
//
//  Created by Greg Harris on 12/10/12.
//  Copyright (c) 2012 Renewed Vision. All rights reserved.
//

#import "HTTPResponse.h"

@interface RVHTTPResponse : NSObject <HTTPResponse>

@property (nonatomic, assign) NSInteger status;

- (id)initWithStatus:(NSInteger)statusCode;

@end
