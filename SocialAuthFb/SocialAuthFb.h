#import <Foundation/Foundation.h>

@protocol FBGraphUser;


@interface SocialAuthFbSuccessObject : NSObject

- (NSString *)token;
- (NSDictionary<FBGraphUser> *)user;

@end


@interface SocialAuthFb : NSObject

+ (id)sharedInstance;

- (void)loginSuccess:(void (^)(SocialAuthFbSuccessObject *))success
             failure:(void (^)(NSError *))failure;

- (void)loginWithURLSchemeSuffix:(NSString *)suffix
                         success:(void (^)(SocialAuthFbSuccessObject *))success
                         failure:(void (^)(NSError *))failure;

- (void)logoutFinish:(void (^)())finish;

@end
