//
//  SwedbankJson.m
//
//  Created by Viktor Gardart on 29/12/14.
//  Copyright (c) 2014 Gardart. All rights reserved.
//

#import "SwedbankJson.h"

@implementation SwedbankJson

NSData *data;
NSString *dsidString;
NSString *queryString;

-(id)init {
    self = [super init];
    
    _baseUri = @"https://auth.api.swedbank.se/TDE_DAP_Portal_REST_WEB/api/v1/";
    
    return self;
}

-(id)initWithData:(NSString *)username password:(NSString *)password appdata:(NSDictionary *)appdata {
    
    self = [self init];
    
    if (!self) {
        return nil;
    }
    
    _username = username;
    _password = password;
    [self setAppData:appdata];
    [self setAuthorizationKey];
    [self login];
    
    return self;
}

-(void)setAppData:(NSDictionary *)appdata {
    _appID = [appdata objectForKey:@"appID"];
    _userAgent = [appdata objectForKey:@"useragent"];
    _profileType = [_userAgent rangeOfString:@"Corporate"].location != NSNotFound ? @"corporateProfiles" : @"privateProfile";
}

-(void)setAuthorizationKey {
    _authorization = [self genAuthorizationKey];
}

-(void)setAuthorizationKey:(NSString *)key {
    _authorization = key;
}

-(id)genAuthorizationKey {
    CFUUIDRef uuid = CFUUIDCreate(kCFAllocatorDefault);
    NSString *uuidString = (NSString *)CFBridgingRelease(CFUUIDCreateString(kCFAllocatorDefault, uuid));
    NSString *text = [[_appID stringByAppendingString:@":"] stringByAppendingString:uuidString];
    NSData *plain = [text dataUsingEncoding:NSUTF8StringEncoding];
    CFRelease(uuid);
    return [plain base64EncodedStringWithOptions:0];
}

-(BOOL)login {
    NSError *error;
    NSDictionary *dataToJson = @{@"useEasyLogin": @NO, @"password": _password, @"generateEasyLoginId": @NO, @"userId": _username};
    data = [NSJSONSerialization dataWithJSONObject:dataToJson options:NSJSONWritingPrettyPrinted error:&error];
    
    NSDictionary *response = [self postRequest:@"identification/personalcode" data:data query:dataToJson];
    
    if(response[@"personalCodeChangeRequired"] == 0) {
        @throw [NSException exceptionWithName:@"Login failed"
                                       reason:@"Byte av personlig kod krävs av banken. Var god rätta till detta genom att logga in på internetbanken."
                                     userInfo:nil];
    }
    else if(!response[@"links"][@"next"][@"uri"]) {
        @throw [NSException exceptionWithName:@"Login failed"
                                       reason:@"Inlogging misslyckades. Kontrollera användarnman, lösenord och authorization-nyckel."
                                     userInfo:nil];
    }
    
    return true;
}

-(NSDictionary *)profileList {
    NSDictionary *data = [self getRequest:@"profile/"];
    
    if(!data[@"hasSwedbankProfile"]) {
        @throw [NSException exceptionWithName:@"Profile error"
                                       reason:@"Något med profilsidan är fel."
                                     userInfo:nil];
    }
    
    if (!data[@"banks"][0][@"bankId"]) {
        if (!data[@"hasSwedbankProfile"] && data[@"hasSavingsbankProfile"]) {
            @throw [NSException exceptionWithName:@"User error"
                                           reason:@"Kontot är inte kopplad till Swedbank. Välj ett annat BankID."
                                         userInfo:nil];
        }
        else if(data[@"hasSwedbankProfile"] && !data[@"hasSavingsbankProfile"]){
            @throw [NSException exceptionWithName:@"User error"
                                           reason:@"Kontot är inte kund i Sparbanken. Välj ett annat BankID."
                                         userInfo:nil];
        }
        else {
            @throw [NSException exceptionWithName:@"Profile error"
                                           reason:@"Profilsidan innerhåller inga bankkonton."
                                         userInfo:nil];
        }
    }
    
    return data[@"banks"][0];
}

-(void)selectProfile:(NSString *)profileId {
    if (profileId.length == 0) {
        if(_selectedProfileID.length != 0) {
            return;
        }
        
        NSDictionary *profiles = [self profileList];
        id profileData = profiles[_profileType];
        
        profileId = profileData[@"id"] ? profileData[@"id"] : profileData[0][@"id"];
    }
    
    [self postRequest:[@"profile/" stringByAppendingString:profileId]];
    _selectedProfileID = profileId;
}

-(NSDictionary *)reminders {
    [self selectProfile:@""];
    return [self getRequest:@"message/reminders"];
}

-(NSDictionary *)baseInfo {
    [self selectProfile:@""];
    return [self getRequest:@"transfer/baseinfo"];
}

-(NSDictionary *)accountList {
    [self selectProfile:@""];
    
    NSDictionary *data = [self getRequest:@"engagement/overview"];
    
    if (!data[@"transactionAccounts"]) {
        @throw [NSException exceptionWithName:@"Profile error"
                                       reason:@"Bankkonton kunde inte listas."
                                     userInfo:nil];
    }
    
    return data;
}

-(NSDictionary *)portfolioList {
    [self selectProfile:@""];
    NSDictionary *data = [self getRequest:@"portfolio/holdings"];
    
    if (!data[@"savingsAccounts"]) {
        @throw [NSException exceptionWithName:@"Profile error"
                                       reason:@"Investeringssparkonton kunde inte listas."
                                     userInfo:nil];
    }
    
    return data;
}

-(NSDictionary *)accountDetails:(NSString *)accoutId transactionsPerPage:(int)transactionsPerPage page:(int)page {
    if (accoutId.length == 0) {
        accoutId = [self accountList][@"transactionAccounts"][0][@"id"];
    }
    
    NSMutableDictionary *query;
    if (transactionsPerPage > 0 && page >= 1) {
        [query setValue:[@(transactionsPerPage) stringValue] forKey:@"transactionsPerPage"];
        [query setValue:[@(page) stringValue] forKey:@"page"];
    }
    
    NSDictionary *data = [self getRequest:[@"engagement/transactions/" stringByAppendingString:accoutId] query:query];
    
    if (!data[@"transactions"]) {
        @throw [NSException exceptionWithName:@"Account error"
                                       reason:@"AccountID stämmer inte."
                                     userInfo:nil];
    }
    
    return data;
}

-(NSDictionary *)quickBalanceAccounts {
    [self selectProfile:@""];
    NSDictionary *data = [self getRequest:@"quickbalance/accounts"];
    
    if (!data[@"accounts"]) {
        @throw [NSException exceptionWithName:@"Account error"
                                       reason:@"Snabbsaldokonton kan inte listas."
                                     userInfo:nil];
    }
    
    return data;
}

-(NSDictionary *)quickBalanceSubscription:(NSString *)accountQuickBalanceSubId {
    NSDictionary *data = [self postRequest:[@"quickbalance/subscription/" stringByAppendingString:accountQuickBalanceSubId]];
    
    if (!data[@"subscriptionId"]) {
        @throw [NSException exceptionWithName:@"Subscription error"
                                       reason:@"Kan ej sätta prenumeration, förmodligen fel ID av \"quickbalanceSubscription\"."
                                     userInfo:nil];
    }
    
    return data;
}

-(NSDictionary *)quickBalance:(NSString *)accountQuickBalanceSubId {
    NSDictionary *data = [self getRequest:[@"quickbalance/" stringByAppendingString:accountQuickBalanceSubId]];
    
    if (!data[@"balance"]) {
        @throw [NSException exceptionWithName:@"Subscription error"
                                       reason:@"Kan ej hämta snabbsaldo. Kontrollera ID."
                                     userInfo:nil];
    }
    
    return data;
}

-(NSDictionary *)quickBalanceUnsubscription:(NSString *)quickBalanceSubscriptionId profileId:(NSString *)profileId {
    [self selectProfile:profileId];
    
    NSDictionary *data = [self deleteRequest:[@"quickbalance/subscription/" stringByAppendingString:quickBalanceSubscriptionId]];
    
    if (!data[@"subscriptionId"]) {
        @throw [NSException exceptionWithName:@"Subscription error"
                                       reason:@"Kan ej sätta prenumeration, förmodligen fel ID av \"quickbalanceSubscription\"."
                                     userInfo:nil];
    }
    
    return data;
}

-(NSDictionary *)terminate {
    return [self putRequest:@"identification/logout"];
}

-(id)putRequest:(NSString *)apiRequest {
    NSMutableURLRequest *request = [self createRequest:@"PUT" apiRequest:apiRequest];
    
    NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
    
    if(data) {
        return [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    }else {
        return FALSE;
    }
}

-(id)deleteRequest:(NSString *)apiRequest {
    NSMutableURLRequest *request = [self createRequest:@"DELETE" apiRequest:apiRequest];
    
    NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
    
    if(data) {
        return [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    }else {
        return FALSE;
    }
}

-(id)getRequest:(NSString *)apiRequest {
    NSMutableURLRequest *request = [self createRequest:@"GET" apiRequest:apiRequest];
    
    NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
    
    if(data) {
        return [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    }else {
        return FALSE;
    }
}

-(id)getRequest:(NSString *)apiRequest query:(NSDictionary *)query {
    
    NSMutableURLRequest *request = [self createRequest:@"GET" apiRequest:apiRequest query:query];
    
    NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
    
    if(data) {
        return [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    }else {
        return FALSE;
    }
}

-(id)postRequest:(NSString *)apiRequest data:(NSData *)data query:(NSDictionary *)query {
    NSMutableURLRequest *request = [self createRequest:@"POST" apiRequest:apiRequest];
    
    [request setValue:@"application/json; charset=UTF-8" forHTTPHeaderField:@"Content-Type"];
    
    [request setHTTPBody: [NSJSONSerialization dataWithJSONObject:query options:0 error:nil]];
    
    NSData *postData = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
    
    if(postData) {
        return [NSJSONSerialization JSONObjectWithData:postData options:0 error:nil];
    }else {
        return FALSE;
    }
}

-(id)postRequest:(NSString *)apiRequest {
    NSMutableURLRequest *request = [self createRequest:@"POST" apiRequest:apiRequest];
    
    [request setValue:@"application/json; charset=UTF-8" forHTTPHeaderField:@"Content-Type"];
    
    NSData *postData = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
    
    if(postData) {
        return [NSJSONSerialization JSONObjectWithData:postData options:0 error:nil];
    }else {
        return FALSE;
    }
}

-(id)createRequest:(NSString *)method apiRequest:(NSString *)apiRequest {
    NSArray                 *cookies;
    NSDictionary            *cookieHeaders;
    
    _dsidStr = [self dsid:8];
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL: [NSURL URLWithString:[NSString stringWithFormat:@"%@%@?dsid=%@", _baseUri, apiRequest, _dsidStr]]];
        
    [request setHTTPMethod:method];
        
    [request setValue:_authorization forHTTPHeaderField:@"Authorization"];
    [request setValue:@"*/*" forHTTPHeaderField:@"Accept"];
    [request setValue:@"sv-se" forHTTPHeaderField:@"Accept-Language"];
    [request setValue:@"gzip, deflate" forHTTPHeaderField:@"Accept-Encoding"];
    [request setValue:@"keep-alive" forHTTPHeaderField:@"Connection"];
    [request setValue:@"keep-alive" forHTTPHeaderField:@"Proxy-Connection"];
    [request setValue:_userAgent forHTTPHeaderField:@"User-Agent"];
    
    cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookiesForURL:[NSURL URLWithString:_baseUri]];
    
    if (!cookies) {
        [request setValue:[@"dsid=" stringByAppendingString:_dsidStr] forHTTPHeaderField:@"Cookie"];
    }else {
        cookieHeaders = [NSHTTPCookie requestHeaderFieldsWithCookies: cookies];
        NSString *realCookie = [cookieHeaders objectForKey:@"Cookie"];
        realCookie = [realCookie stringByAppendingString:[@";dsid=" stringByAppendingString:_dsidStr]];
        [request setValue:realCookie forHTTPHeaderField: @"Cookie"];
    }

    return request;
}

-(id)createRequest:(NSString *)method apiRequest:(NSString *)apiRequest query:(NSDictionary *)query {
    NSArray                 *cookies;
    NSDictionary            *cookieHeaders;
    
    _dsidStr = [self dsid:8];
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL: [NSURL URLWithString:[NSString stringWithFormat:@"%@%@?dsid=%@", _baseUri, apiRequest, _dsidStr]]];
    
    [request setHTTPMethod:method];
    
    [request setValue:_authorization forHTTPHeaderField:@"Authorization"];
    [request setValue:@"*/*" forHTTPHeaderField:@"Accept"];
    [request setValue:@"sv-se" forHTTPHeaderField:@"Accept-Language"];
    [request setValue:@"gzip, deflate" forHTTPHeaderField:@"Accept-Encoding"];
    [request setValue:@"keep-alive" forHTTPHeaderField:@"Connection"];
    [request setValue:@"keep-alive" forHTTPHeaderField:@"Proxy-Connection"];
    [request setValue:_userAgent forHTTPHeaderField:@"User-Agent"];
    [request setValue:[self addQueryStringToUrlString:query] forHTTPHeaderField:@"query"];
    
    cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookiesForURL:[NSURL URLWithString:_baseUri]];
    
    if (!cookies) {
        [request setValue:[@"dsid=" stringByAppendingString:_dsidStr] forHTTPHeaderField:@"Cookie"];
    }else {
        cookieHeaders = [NSHTTPCookie requestHeaderFieldsWithCookies: cookies];
        NSString *realCookie = [cookieHeaders objectForKey:@"Cookie"];
        realCookie = [realCookie stringByAppendingString:[@";dsid=" stringByAppendingString:_dsidStr]];
        [request setValue:realCookie forHTTPHeaderField: @"Cookie"];
    }
    
    return request;
}

-(id)dsid:(int)len {
    NSString *letters = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";
    NSMutableString *randomString = [NSMutableString stringWithCapacity: len];
    
    for (int i=0; i<len; i++) {
        [randomString appendFormat: @"%C", [letters characterAtIndex: arc4random_uniform((int)[letters length])]];
    }
    return randomString;
}

-(NSString*)urlEscapeString:(NSString *)unencodedString
{
    CFStringRef originalStringRef = (__bridge_retained CFStringRef)unencodedString;
    NSString *s = (__bridge_transfer NSString *)CFURLCreateStringByAddingPercentEscapes(NULL,originalStringRef, NULL, NULL,kCFStringEncodingUTF8);
    CFRelease(originalStringRef);
    return s;
}

-(NSString*)addQueryStringToUrlString:(NSDictionary *)dictionary
{
    NSMutableString *urlWithQuerystring = [[NSMutableString alloc] init];
    
    for (id key in dictionary) {
        NSString *keyString = [key description];
        NSString *valueString = [[dictionary objectForKey:key] description];
        
        if ([urlWithQuerystring rangeOfString:@"?"].location == NSNotFound) {
            [urlWithQuerystring appendFormat:@"?%@=%@", [self urlEscapeString:keyString], [self urlEscapeString:valueString]];
        } else {
            [urlWithQuerystring appendFormat:@"&%@=%@", [self urlEscapeString:keyString], [self urlEscapeString:valueString]];
        }
    }
    return urlWithQuerystring;
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    NSHTTPURLResponse        *httpResponse = (NSHTTPURLResponse *)response;
    NSArray                  *cookies;
    
    cookies = [NSHTTPCookie cookiesWithResponseHeaderFields:[httpResponse allHeaderFields] forURL:[NSURL URLWithString:_baseUri]];
    [[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookies: cookies forURL:[NSURL URLWithString:_baseUri] mainDocumentURL: nil];
}

@end
