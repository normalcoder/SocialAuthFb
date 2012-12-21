#import "SocialAuthFb.h"
#import "AppOpenUrlNotification.h"
#import "FacebookSDK.h"
#import <Accounts/Accounts.h>

@interface SocialAuthFbSuccessObject ()

@property (strong, nonatomic) NSString * token;
@property (strong, nonatomic) NSDictionary<FBGraphUser> * user;

@end

@implementation SocialAuthFbSuccessObject

+ (id)socialAuthSuccessObjectFbWithToken:(NSString *)token user:(NSDictionary<FBGraphUser> *)user {
    return [[self alloc] initWithToken:token user:user];
}

- (id)initWithToken:(NSString *)token user:(NSDictionary<FBGraphUser> *)user {
    if ((self = [super init])) {
        self.token = token;
        self.user = user;
    }
    return self;
}

@end

@interface SocialAuthFb ()

@property (strong, nonatomic) void (^logoutFinish)();

@end

@implementation SocialAuthFb

+ (id)sharedInstance {
    static dispatch_once_t pred;
    static id instance;
    dispatch_once(&pred, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (id)init {
    if ((self = [super init])) {
        [[NSNotificationCenter defaultCenter]
         addObserver:self
         selector:@selector(applicationDidBecomeActive:)
         name:UIApplicationDidBecomeActiveNotification
         object:nil];
        [[NSNotificationCenter defaultCenter]
         addObserver:self
         selector:@selector(applicationWillTerminate:)
         name:UIApplicationWillTerminateNotification
         object:nil];
        [[NSNotificationCenter defaultCenter]
         addObserver:self
         selector:@selector(applicationDidOpenUrl:)
         name:AppOpenUrlNotification
         object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark -

- (NSArray *)fbReadPermissions {
    return
    @[ @"user_photos"
    , @"user_relationships"
    , @"user_events"
    , @"user_checkins"
    , @"user_location"
    , @"friends_photos"
    , @"friends_relationships"
    , @"friends_events"
    , @"friends_checkins"
    , @"friends_location"
    , @"read_stream"
    ];
}

#pragma mark -

- (void)loginSuccess:(void (^)(SocialAuthFbSuccessObject *))success
             failure:(void (^)(NSError *))failure {
    [self loginAllowUi:YES success:success failure:failure];
}

- (void)testLoginAllowUi:(BOOL)allowUi
                 success:(void (^)(SocialAuthFbSuccessObject *))success
                 failure:(void (^)(NSError *))failure
       attemptsRemaining:(NSInteger)attemptsRemaining {
    [FBSession openActiveSessionWithReadPermissions:[self fbReadPermissions]
                                       allowLoginUI:allowUi
                                  completionHandler:
     ^(FBSession * session, FBSessionState state, NSError * e) {
         switch (state) {
             case FBSessionStateOpenTokenExtended:
             case FBSessionStateOpen: {
                 NSLog(@"token: %@", [[FBSession activeSession] accessToken]);
                 [FBRequestConnection startForMeWithCompletionHandler:
                  ^(FBRequestConnection *connection, NSDictionary<FBGraphUser> *user, NSError * e) {
                      NSLog(@"e: %@", e);
                      if (!e) {
                          NSLog(@"user: %@", user);
                          success
                          ([SocialAuthFbSuccessObject
                            socialAuthSuccessObjectFbWithToken:[FBSession activeSession].accessToken
                            user:user]);
                          
                      } else if ([[e userInfo][FBErrorParsedJSONResponseKey][@"body"][@"error"][@"code"] compare:@190] == NSOrderedSame) {
                          //requestForMe failed due to error validating access token (code 190), so retry login
                          
                          if (attemptsRemaining > 0) {
                              ACAccountStore * accountStore = [[ACAccountStore alloc] init];
                              
                              NSArray * fbAccounts =
                              [accountStore
                               accountsWithAccountType:
                               [accountStore
                                accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierFacebook]];
                              
                              if ([fbAccounts count] > 0) {
                                  id account = [fbAccounts objectAtIndex:0];
                                  
                                  dispatch_queue_t q = dispatch_get_main_queue();
                                  
                                  [accountStore renewCredentialsForAccount:account completion:
                                   ^(ACAccountCredentialRenewResult renewResult, NSError *error) {
                                       dispatch_async(q, ^{
                                           [self testLoginAllowUi:allowUi
                                                          success:success
                                                          failure:failure
                                                attemptsRemaining:attemptsRemaining - 1];
                                       });
                                   }];
                              } else {
                                  [self testLoginAllowUi:allowUi
                                                 success:success
                                                 failure:failure
                                       attemptsRemaining:attemptsRemaining - 1];
                              }
                          } else {
                              failure(e);
                          }
                      } else {
                          failure(e);
                      }
                  }];
             } break;
             case FBSessionStateClosedLoginFailed: {
                 failure(e);
             } break;
             case FBSessionStateClosed: {
                 if (self.logoutFinish) {
                     self.logoutFinish();
                     self.logoutFinish = nil;
                 } else {
                 }
             } break;
             default: {
                 assert(NO);
             }
         }
     }];
}

- (void)logoutFbFinish:(void (^)())finish {
    
}

- (void)loginAllowUi:(BOOL)allowUi
             success:(void (^)(SocialAuthFbSuccessObject *))success
             failure:(void (^)(NSError *))failure {
    [[FBSession activeSession] closeAndClearTokenInformation];
    
    ACAccountStore * accountStore = [[ACAccountStore alloc] init];
    
    NSArray * fbAccounts =
    [accountStore
     accountsWithAccountType:
     [accountStore
      accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierFacebook]];
    
    if ([fbAccounts count] > 0) {
        id account = [fbAccounts objectAtIndex:0];
        
        dispatch_queue_t q = dispatch_get_main_queue();
        
        [accountStore renewCredentialsForAccount:account completion:
         ^(ACAccountCredentialRenewResult renewResult, NSError *error) {
             dispatch_async(q, ^{
                 [self testLoginAllowUi:allowUi success:success failure:failure attemptsRemaining:4];
             });
         }];
    } else {
        [self testLoginAllowUi:allowUi success:success failure:failure attemptsRemaining:4];
    }
}

- (void)logoutFinish:(void (^)())finish {
    self.logoutFinish = finish;
    [FBSession.activeSession closeAndClearTokenInformation];
}

#pragma mark -

- (void)applicationDidBecomeActive:(NSNotification *)notification {
    [FBSession.activeSession handleDidBecomeActive];
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    [FBSession.activeSession closeAndClearTokenInformation];
}

- (void)applicationDidOpenUrl:(NSNotification *)notification {
    [FBSession.activeSession handleOpenURL:
     [[notification userInfo] objectForKey:AppOpenUrlNotificationUserInfoKey]];
}

@end
