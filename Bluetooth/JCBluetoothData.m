//
//  JCBluetoothData.m
//  Zebra
//
//  Created by 奥赛龙-Guo.JC on 2016/10/31.
//  Copyright © 2016年 奥赛龙科技. All rights reserved.
//

#import "JCBluetoothData.h"

static JCBluetoothData *_bluetoothData;




@interface JCBluetoothData ()

@end





@implementation JCBluetoothData

#pragma mark - 创建单例蓝牙数据模型
+ (JCBluetoothData *)shareBluetoothData{
    @synchronized(self) {
        if (!_bluetoothData) {
            _bluetoothData = [JCBluetoothData new];

        }
    }
    return _bluetoothData;
}


@end
