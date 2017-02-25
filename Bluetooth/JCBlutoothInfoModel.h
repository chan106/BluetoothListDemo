//
//  JCBlutoothInfoModel.h
//  Turing
//
//  Created by Guo.JC on 16/9/18.
//  Copyright © 2016年 Guo.JC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>

@interface JCBlutoothInfoModel : NSObject

//@property (nonatomic, strong) NSNumber *signal;
//@property (nonatomic, strong) NSNumber *sevicesCount;
//@property (nonatomic, copy) NSString *name;

@property (nonatomic, strong) CBPeripheral *peripheral;
@property (nonatomic, strong) NSDictionary *advertisementData;
@property (nonatomic, strong) NSNumber *RSSI;
@property (nonatomic, copy) NSString *adverMacAddr;

@end
