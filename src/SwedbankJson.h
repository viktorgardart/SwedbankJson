//
//  SwedbankJson.h
//
//  Created by Viktor Gardart on 29/12/14.
//  Copyright (c) 2014 Gardart. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SwedbankJson : NSObject<NSURLConnectionDelegate>

@property NSString *baseUri;
@property NSString *username;
@property NSString *password;
@property NSString *appID;
@property NSString *userAgent;
@property NSString *authorization;
@property NSString *client;
@property NSString *profileType;
@property NSString *dsidStr;
@property NSString *selectedProfileID;
@property NSArray *authCookies;

-(id)initWithData:(NSString *)username password:(NSString *)password appdata:(NSDictionary *)appdata;

-(NSDictionary *)profileList;
-(NSDictionary *)reminders;
-(NSDictionary *)baseInfo;
-(NSDictionary *)accountList:(NSString *)profileId;
-(NSDictionary *)portfolioList:(NSString *)profileId;
-(NSDictionary *)accountDetails:(NSString *)accoutId transactionsPerPage:(int)transactionsPerPage page:(int)page;
-(NSDictionary *)quickBalanceAccounts:(NSString *)profileId;

-(NSDictionary *)terminate;

@end
