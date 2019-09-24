//
//  MhbSdk.m
//  RNLibMhb
//
//  Created by 健康益友 on 2019/9/9.
//  Copyright © 2019 Facebook. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "React/RCTBridgeModule.h"

@interface RCT_EXTERN_MODULE(MhbSdk, NSObject)

RCT_EXTERN_METHOD(startProc:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(fetchData:(NSString *)startTimestamp ets:(NSString *)endTimestamp resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)

@end
