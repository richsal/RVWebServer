//
//  ProNetworkController.m
//  ProPresenter6
//
//  Created by Greg Harris on 2/21/14.
//  Copyright (c) 2014 Renewed Vision. All rights reserved.
//

#import "ProNetworkController.h"
#import "NSString+RVBonjourUtilities.h"
#import "RVHTTPServer.h"
#import "ProHTTPConnection.h"
#import "RVWebSocket.h"
#import "RVStatic.h"

#define RVBonjourLocalDomain @"local."


static void *RVHTTPServerEnabledPrefObservationContext = &RVHTTPServerEnabledPrefObservationContext;

static ProNetworkController *sharedNetworkController = nil;

@interface ProNetworkController () <NSNetServiceBrowserDelegate, NSNetServiceDelegate, NSTableViewDataSource, NSTableViewDelegate> {
	IBOutlet NSView *generalNetworkPreferencesView;
	IBOutlet NSTextField *httpServerNameField, *httpServerPortField;
	IBOutlet NSButton *enableNetworkButton;
	NSNetServiceBrowser *pro6ServiceBrowser, *masterControlServiceBrowser;
	NSString *_sportsName;
}
@property (assign) BOOL httpServerIsPublished;
@end


#pragma mark -
@implementation ProNetworkController

+ (ProNetworkController *)sharedNetworkController {
	@synchronized(self) {
		if (sharedNetworkController == nil) {
			sharedNetworkController = [[self alloc] init];
		}
	}
	return sharedNetworkController;
}

+ (id)allocWithZone:(NSZone *)zone {
	@synchronized(self) {
		if (sharedNetworkController == nil) {
			return [super allocWithZone:zone];
		}
	}
	return sharedNetworkController;
}

- (id)copyWithZone:(NSZone *)zone {
	return self;
}

- (id)init {
	Class myClass = [self class];
	@synchronized(myClass) {
		if (sharedNetworkController == nil) {
			if ((self = [super init])) {
				NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
				NSUserDefaultsController *udc = [NSUserDefaultsController sharedUserDefaultsController];
				sharedNetworkController = self;
				_httpServerIsPublished = NO;

				_httpServer = [RVHTTPServer new];
				[self _configureHTTPServer];

				// make sure there's a value, default to YES
				if ([ud valueForKey:RVPrefKeyHTTPServerEnabled] == nil) { // note this checks for the existence of the NSNumber pref object, not the YES/NO value
					[ud setBool:YES forKey:RVPrefKeyHTTPServerEnabled];
				}

				pro6ServiceBrowser = [[NSNetServiceBrowser alloc] init];
				[pro6ServiceBrowser setDelegate:self];
				[pro6ServiceBrowser searchForServicesOfType:RVBonjourServiceName inDomain:@"local."];

				[udc addObserver:self forKeyPath:@"values." RVPrefKeyHTTPServerEnabled options:NSKeyValueObservingOptionInitial context:RVHTTPServerEnabledPrefObservationContext];
			}
		}
	}
	return sharedNetworkController;
}



- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
	if (context == RVHTTPServerEnabledPrefObservationContext) {
		[self _handleHTTPServerEnableChanged];
	} else {
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
}


- (void)_handleHTTPServerEnableChanged {
	BOOL httpEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:RVPrefKeyHTTPServerEnabled];
	if (httpEnabled) {
		[self _turnHTTPServerOn];
	} else {
		[self _turnHTTPServerOff];
	}
}


- (NSView *)generalNetworkPreferencesView {
	if (!generalNetworkPreferencesView) {
		if (![[NSBundle mainBundle] loadNibNamed:@"GeneralNetworkPreferencesView" owner:self topLevelObjects:nil]) {
			NSLog(@"failed to load GeneralNetworkPreferencesView nib");
			return nil;
		}
	}

	if (_httpServer.isRunning) {
		httpServerNameField.stringValue = _httpServer.publishedName ?: @"";
		if (_httpServer.listeningPort > 0) {
			httpServerPortField.integerValue = _httpServer.listeningPort;
		} else {
			httpServerPortField.stringValue = @"";
		}
	} else {
		httpServerNameField.stringValue = @"";
		httpServerPortField.stringValue = @"";
	}
	
	[self updateWebRemoteURL];

	return generalNetworkPreferencesView;
}


- (void)_configureHTTPServer {
	_httpServer.connectionClass = [ProHTTPConnection class];
	_httpServer.type = RVBonjourServiceName;
}


- (void)_turnHTTPServerOn {
	if ([_httpServer isRunning])
		return;
	NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
	NSString *nameToPublish = [ud valueForKey:@"HTTPName"];
	if (!nameToPublish) {
		nameToPublish = @"";
	}
	NSInteger servingPort = [ud integerForKey:@"HTTPPort"];
	if (servingPort < 1024 || servingPort > 65535) {
		servingPort = 0;
	}

	self.servingHTTPUser = nil;		//@"user";
	self.servingHTTPPassword = nil; //@"secret";
	if (self.servingHTTPUser && self.servingHTTPPassword) {
		if (![DDKeychain setPasswordForHTTPServer:self.servingHTTPPassword withUsername:self.servingHTTPUser]) {
			//TODO: alert the user
			NSLog(@"failed to set password, what should we do?");
		}
	}

	if ([_httpServer isRunning])
		[self _turnHTTPServerOff];
	if (!_httpServer)
		_httpServer = [[RVHTTPServer alloc] init];

	[_httpServer setName:nameToPublish];
	[_httpServer setPort:servingPort];

	NSError *e = nil;
	BOOL success = [_httpServer start:&e];

	if (success) {
		if (nameToPublish) {
			[[NSUserDefaults standardUserDefaults] setValue:_httpServer.name forKey:@"HTTPName"];
		}
		if (servingPort > 0) {
			[[NSUserDefaults standardUserDefaults] setInteger:_httpServer.port forKey:@"HTTPPort"];
		}
	} else {
		NSLog(@"failed to start HTTP server: %@", e);
	}
	[self updateWebRemoteURL];
}

- (void)_turnHTTPServerOff {
	if ([_httpServer isRunning]) {
		[_httpServer stop];
	}
	[self updateWebRemoteURL];

}

- (BOOL)servingHTTPUsesSSL {
	return [[NSUserDefaults standardUserDefaults] boolForKey:@"HTTPUsesSSL"];
}


#pragma mark -

- (NSURL *)servingURL { // base URL
	NSString *host = [[[NSHost currentHost] name] urlSafeHostNameForBonjourName];
	UInt16 port = _httpServer.listeningPort;
	if (port < 1) {
		return nil;
	}
	return [NSURL URLWithString:[NSString stringWithFormat:@"http://%@.local:%d", host, port]];
}

- (IBAction)serverNameFieldAction:(id)sender {
	NSTextField *field = sender;

	[[NSUserDefaults standardUserDefaults] setObject:field.stringValue forKey:@"HTTPName"];

	if (![field.stringValue isEqualToString:_httpServer.publishedName]) {
		[_httpServer setName:field.stringValue];
		[_httpServer republishBonjour];
	}
}

- (IBAction)serverPortFieldAction:(id)sender {
	NSTextField *field = sender;
	NSUInteger cleanedPort = field.stringValue.integerValue;
	if (cleanedPort < 1024 || cleanedPort > 65535) {
		cleanedPort = 0;
	}

	[[NSUserDefaults standardUserDefaults] setInteger:cleanedPort forKey:@"HTTPPort"];
	field.integerValue = cleanedPort;
	
	if (cleanedPort != _httpServer.listeningPort) {
		// changing the Bonjour name only requires the Bonjour service to be republished, but changing the port requires the server to be restarted
		[_httpServer stop:YES];
		[_httpServer setPort:cleanedPort];
		NSError *e = nil;
		[_httpServer start:&e];
	}
	[self updateWebRemoteURL];
}

/// Opens the API documentation
- (IBAction) openWebRemote:(id)sender {
	//sportName
	NSURL *remoteURL = [NSURL URLWithString: self.webRemotePath];
	if (remoteURL != nil) {
		[NSWorkspace.sharedWorkspace openURL:remoteURL];
	} else {
		NSAlert *alert = [NSAlert new];
		alert.messageText = @"Missing network settings";
		alert.informativeText = @"Open preferences and update the settings under the network tab.";
		alert.alertStyle = NSAlertStyleWarning;
		[alert runModal];
	}
}

- (void) setSportsName:(NSString*) sportsName {
	_sportsName = sportsName;
	[self updateWebRemoteURL];
}

- (void) updateWebRemoteURL {
	NSURL *url = self.servingURL;
	if (url != nil && [_httpServer isRunning]) {
		NSString *sport = [[_sportsName lowercaseString] stringByReplacingOccurrencesOfString:@" " withString:@""];
		NSURL *remoteURL = [url URLByAppendingPathComponent:[NSString stringWithFormat:@"html/%@", sport]];
		if (remoteURL != nil) {
			self.webRemotePath = remoteURL.absoluteString;
		}
	} else {
		self.webRemotePath = @"";
	}
}

@end

#pragma mark - RVHTTPServerPrivateDelegate
@implementation ProNetworkController (RVHTTPServerPrivateDelegate)

- (void)updateUIForBonjourDidPublish {
	//NSLog(@"HTTPServer available at http://%@:%d",[[NSHost currentHost] name],_httpServer.listeningPort);
	self.httpServerIsPublished = YES;
	httpServerNameField.stringValue = _httpServer.publishedName;
	httpServerPortField.integerValue = _httpServer.listeningPort;
	// make sure the defaults are set - in the event a zero port number was passed
	// and the port was dynamically assigned - RDS 6/30/15
	if (_httpServer.publishedName) {
		[[NSUserDefaults standardUserDefaults] setValue:_httpServer.publishedName forKey:@"HTTPName"];
	}
	if (_httpServer.listeningPort > 0) {
		[[NSUserDefaults standardUserDefaults] setInteger:_httpServer.listeningPort forKey:@"HTTPPort"];
	}
}

- (void)httpServerBonjourDidNotPublish {
	//NSLog(@"HTTPServer failed to publish");
	self.httpServerIsPublished = NO;
}

@end


