//
//  AppData.m
//
//  Created by Viktor Gardart on 29/12/14.
//  Copyright (c) 2014 Gardart. All rights reserved.
//

#import "AppData.h"

@implementation AppData

NSDictionary *appData;


+(id)bankAppId:(NSString *)bankID {
    appData = @{
                @"swedbank" :  @{ @"appID" : @"i1Pc8spRArqu9KAh", @"useragent" : @"SwedbankMOBPrivateIOS/4.0.0_(iOS;_8.1.1)_Apple/iPhone5,2"},
                @"sparbanken" : @{ @"appID" : @"NOhNNqhzTXXSoOdQ", @"useragent" : @"SavingbankMOBPrivateIOS/4.0.0_(iOS;_8.1.1)_Apple/iPhone5,2"},
                @"swedbank_ung" : @{ @"appID" : @"CXTbGZnvWjL4vVBr", @"useragent" : @"SwedbankMOBYouthIOS/1.7.0_(iOS;_8.1.1)_Apple/iPhone5,2"},
                @"sparbanken_ung" : @{ @"appID" : @"l8TOWVEHNtS1dCvd", @"useragent" : @"SavingbankMOBYouthIOS/1.7.0_(iOS;_8.1.1)_Apple/iPhone5,2"},
                @"swedbank_foretag" : @{ @"appID" : @"4WXxfxvWDY5kd0eg", @"useragent" : @"SwedbankMOBCorporateIOS/1.6.0_(iOS;_8.1.1)_Apple/iPhone5,2"},
                @"sparbanken_foretag" : @{ @"appID" : @"qaSBwIdFFqRo48WD", @"useragent" : @"SavingbankMOBCorporateIOS/1.6.0_(iOS;_8.1.1)_Apple/iPhone5,2"},
                };
    
    if ([bankID isEqualToString:@"swedbank_företag"]) {
        @throw [NSException exceptionWithName:@"Bankid \"swedbank_företag\" är inte längre giltigt. Använd \"swedbank_foretag\""
                                       reason:@""
                                     userInfo:nil];
    }else if([appData objectForKey:bankID] == nil) {
        @throw [NSException exceptionWithName:@"BankID existerar inte"
                                       reason:@""
                                     userInfo:nil];
    }
    return [appData objectForKey:bankID];
}

@end