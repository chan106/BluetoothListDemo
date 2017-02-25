//
//  JCBluetoothData.h
//  Zebra
//
//  Created by 奥赛龙-Guo.JC on 2016/10/31.
//  Copyright © 2016年 奥赛龙科技. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface JCBluetoothData : NSObject

@property (nonatomic, assign) BOOL isCharge;            //是否充电

@property (nonatomic, assign) NSInteger battery;        //电量
@property (nonatomic, assign) NSInteger speed;          //速度

@property (nonatomic, assign) NSInteger motorTemp;      //电机温度
@property (nonatomic, assign) NSInteger CPUTemp;        //主板温度
@property (nonatomic, assign) NSInteger batteryTemp;    //电池温度
@property (nonatomic, assign) NSInteger cache;          //缓存

@property (nonatomic, assign) float lenght;           //里程

@property (nonatomic, copy) NSString *MACAddress;       //滑板MAC地址

@property (nonatomic, copy) NSDictionary *GPSDic;       //实时GPS数据

@property (nonatomic, assign) NSInteger cacheGPSCount;  //缓存GPS数量
@property (nonatomic, copy) NSDictionary *cacheGPSDic;  //缓存GPS数据

@property (nonatomic, strong) NSData *bluetoothRecieveData;

+ (JCBluetoothData *)shareBluetoothData;

@end
