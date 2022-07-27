#import <Cocoa/Cocoa.h>
#import <Security/Security.h>

@interface DDKeychain : NSObject
{
	
}

+ (NSString *)passwordForHTTPServerWithUsername:(NSString *)username;
+ (BOOL)setPasswordForHTTPServer:(NSString *)password withUsername:(NSString *)username;

+ (void)createNewIdentity;
+ (NSArray *)SSLIdentityAndCertificates;

+ (NSString *)applicationTemporaryDirectory;
+ (NSString *)stringForSecExternalFormat:(SecExternalFormat)extFormat;
+ (NSString *)stringForSecExternalItemType:(SecExternalItemType)itemType;
+ (NSString *)stringForSecKeychainAttrType:(SecKeychainAttrType)attrType;

@end
