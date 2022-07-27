//
//  ProNetworkController.h
//  ProPresenter6
//
//  Created by Greg Harris on 2/21/14.
//  Copyright (c) 2014 Renewed Vision. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "RVWebServer.h"

@class RVHTTPServer;

@protocol HTMLCodeGenerator <NSObject>
- (NSString *)htmlForCustomController:(NSDictionary *)scores groupIndex:(NSInteger) index;
@end

@protocol ScoresDataSource <NSObject>
- (NSDictionary *)sportsScores;
- (NSString *)sportsControllerAction:(NSString *)action withArgumentString:(NSString *)arguement;
@end


@interface ProNetworkController : NSObject

@property (readonly) RVHTTPServer *httpServer;
@property (readonly) BOOL servingHTTPUsesSSL;
@property (copy) NSString *servingHTTPUser, *servingHTTPPassword;
@property (strong) NSString *webRemotePath;
@property (weak) id <HTMLCodeGenerator> codeSource;
@property (weak) id <ScoresDataSource> dataSource;


+ (ProNetworkController *)sharedNetworkController;

- (NSURL *)servingURL; // base URL

- (NSView *)generalNetworkPreferencesView;

- (void)setSportsName:(NSString*)name;

- (IBAction)openWebRemote:(id)sender;

@end
