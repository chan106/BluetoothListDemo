//
//  JCBluetoothManager.m
//  Zebra
//
//  Created by 奥赛龙-Guo.JC on 2016/10/29.
//  Copyright © 2016年 奥赛龙科技. All rights reserved.
//

#import "JCBluetoothManager.h"
//#import "JCAddDevicesTVC.h"
#import "JCBluetoothData.h"
#import "JCDataConvert.h"


static JCBluetoothManager *_manager;
static CBCentralManager *_myCentralManager;

#define     kServiceUUID        @"1234"
#define     kReadUUID           @"1236"
#define     kWriteUUID          @"1235"

#define     kLoopCheckTime      0.3
#define     kCheckHardInfoTime  1


typedef NS_ENUM(NSInteger, respondType) {
    BoardRespondUpdateFirmware = 1,
    BoardRespondFirmwareState,
    BoardRespondSendUpdatePakgeState,
    BoardRespondQueryBoard,
    BoardRespondQueryGPS,
    BoardRespondQueryMACAddress,
    BoardRespondRepeatLastData,
    BoardRespondQueryCacheGPS,
    BoardRespondQueryUploadGPS,
    BoardRespondQueryClearCacheGPS,
    BoardRespondCancelUpdateFirmware,
    BoardRespondBoardPowerState,
};


@interface JCBluetoothManager (){

//    UITextView *tv;
}

@property (nonatomic, strong) CBCharacteristic *readCharacteristic;     //读取数据特性
@property (nonatomic, strong) CBCharacteristic *writeCharacteristic;    //写数据特性
@property (nonatomic, weak) JCBluetoothData *bluetoothData;             //数据模型

@property (nonatomic, strong) NSMutableArray *commandBuffer;            //指令缓存
@property (nonatomic, strong) NSTimer *sendCommandLoop;                 //发送指令定时器

@end


@implementation JCBluetoothManager


#pragma mark 【1】创建单例蓝牙管理中心
+ (JCBluetoothManager *)shareCBCentralManager
{
    @synchronized(self) {
        if (!_manager) {
            _manager = [[JCBluetoothManager alloc]init];
            _myCentralManager = [[CBCentralManager alloc] initWithDelegate:_manager queue:nil];//如果设置为nil，默认在主线程中跑
            _manager.bluetoothData = [JCBluetoothData shareBluetoothData];
            _manager.commandBuffer = [NSMutableArray array];
        }
    }
    return _manager;
}

#pragma mark 【2】监测蓝牙状态
- (void)centralManagerDidUpdateState:(CBCentralManager *)central

{
    switch (central.state)
    {
        case CBCentralManagerStateUnknown:
            break;
        case CBCentralManagerStateUnsupported:
            NSLog(@"模拟器不支持蓝牙调试");
            break;
        case CBCentralManagerStateUnauthorized:
            break;
        case CBCentralManagerStatePoweredOff:{
            NSLog(@"蓝牙处于关闭状态");
            self.bluetoothState = BluetoothOpenStateIsClosed;
            _currentPeripheral = nil;
            _readCharacteristic = nil;
            _writeCharacteristic = nil;
            if ([self.delegate respondsToSelector:@selector(bluetoothStateChange:state:)]) {
                [self.delegate bluetoothStateChange:self state:BluetoothOpenStateIsClosed];
            }
        }
            break;
        case CBCentralManagerStateResetting:
            break;
        case CBCentralManagerStatePoweredOn:
        {
            self.bluetoothState = BluetoothOpenStateIsOpen;
            if ([self.delegate respondsToSelector:@selector(bluetoothStateChange:state:)]) {
                [self.delegate bluetoothStateChange:self state:BluetoothOpenStateIsOpen];
            }
            NSLog(@"蓝牙已开启");
        }
            break;
    }
}

#pragma mark 【3】发现外部设备
- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
    
//    JCLog(@"蓝牙广播数据------>>%@",advertisementData);
    if (![peripheral.name isEqual:[NSNull null]]) {
        if ([self.delegate respondsToSelector:@selector(foundPeripheral:peripheral:advertisementData:RSSI:)]) {
            [self.delegate foundPeripheral:self peripheral:peripheral advertisementData:advertisementData RSSI:RSSI];
        }
    }
}

#pragma mark 【4】连接外部蓝牙设备
- (void)connectToPeripheral:(CBPeripheral *)peripheral
{
    if (!peripheral) {
        return;
    }
    [_myCentralManager connectPeripheral:peripheral options:nil];//连接蓝牙
    _currentPeripheral = peripheral;
}

#pragma mark 【5】连接外部蓝牙设备成功
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    _currentPeripheral = peripheral;
    peripheral.delegate = self;
    //外围设备开始寻找服务
    [peripheral discoverServices:nil];
    if ([self.delegate respondsToSelector:@selector(bluetoothManager:didSucceedConectPeripheral:)]) {
        [self.delegate bluetoothManager:self didSucceedConectPeripheral:peripheral];
    }

    //连接成功，开启定时轮询发送指令机制
    [self startLoopCheckCommandBuffer];
    
//    //如果是在轨迹模式下重新接上的连接，则获取GPS缓存条数
//    if (_isRecordTrack) {
//        JCLog(@"轨迹模式下重连设备，获取缓存情况,延时1秒");
//        [NSTimer scheduledTimerWithTimeInterval:1 repeats:NO block:^(NSTimer * _Nonnull timer) {
//           
//            [self sendDataUseCommand:APP_COMMAND_QUERY_CACHE_GPS Payload:@"00"];//发送查询GPS缓存指令
//        }];
//        
//    }
//    else{
//        //连接成功，开启发送查询滑板指令
//        [self startCheckHardwareInfo];
//    }
}

#pragma mark 连接外部蓝牙设备失败
- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    //如何实现自动断线重连，就是在断开的委托方法中，执行连接蓝牙的方法  可以在此处重新调用连接蓝牙方法
    if ([self.delegate respondsToSelector:@selector(bluetoothManager:didFailConectPeripheral:)]) {
        [self.delegate bluetoothManager:self didFailConectPeripheral:peripheral];
    }
    _currentPeripheral = nil;
}

#pragma mark 【6】寻找蓝牙服务
//外围设备寻找到服务后
-(void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error{
    
    if(error){
        NSLog(@"外围设备寻找服务过程中发生错误，错误信息：%@",error.localizedDescription);
    }
    //遍历查找到的服务
    CBUUID *serviceUUID=[CBUUID UUIDWithString:kServiceUUID];
    for (CBService *service in peripheral.services) {
        if([service.UUID isEqual:serviceUUID]){
            //外围设备查找指定服务中的特征
            [peripheral discoverCharacteristics:@[[CBUUID UUIDWithString:kReadUUID],[CBUUID UUIDWithString:kWriteUUID]] forService:service];
        }
    }
}


#pragma mark 【7】寻找蓝牙服务中的特性
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    if (error) {//报错直接返回退出
        NSLog(@"didDiscoverCharacteristicsForService error : %@", [error localizedDescription]);
        return;
    }
    
    for (CBCharacteristic *characteristic in service.characteristics)//遍历服务中的所有特性
    {
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:kReadUUID]]){//找到收数据特性
            [peripheral setNotifyValue:YES forCharacteristic:characteristic];//订阅其特性（这个特性只有订阅方式）
            _readCharacteristic = characteristic;
        }
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:kWriteUUID]]) {//找到发数据特性
            _writeCharacteristic = characteristic;
        }
    }
}

#pragma mark 【8】直接读取特征值被更新后
-(void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error{
    if (error) {
        NSLog(@"更新特征值时发生错误，错误信息：%@",error.localizedDescription);
        return;
    }
    
    if (characteristic.value) {
        NSData *data = characteristic.value;
    
        //校验数据，丢弃错误数据
        
        //开线程处理传输回来的数据
        @autoreleasepool {
            
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                //            JCLog(@"收到的原始数据：%@",characteristic.value);
                //过滤数据
                //            if ([[JCDataConvert ConvertHexToString:[data subdataWithRange:NSMakeRange(0, 1)]]isEqualToString:SOP_BOARD])
                if ([[data subdataWithRange:NSMakeRange(0, 1)]isEqualToData:[JCDataConvert hexToBytes:SOP_BOARD]])
                {
                    NSInteger respondType = [JCDataConvert ToInteger:[data subdataWithRange:NSMakeRange(1, 1)]];
                    NSInteger length = [JCDataConvert ToInteger:[data subdataWithRange:NSMakeRange(2, 1)]];
                    
                    switch (respondType) {
                            //响应固件升级请求
                        case BoardRespondUpdateFirmware:
                        {
//                            JCLog(@"滑板响应固件升级请求 -- %@\n",data);
                            NSData *payload = [data subdataWithRange:NSMakeRange(3, length)];
                            if ([JCDataConvert ToInteger:payload]) {
                                //允许固件升级
                                if ([self.delegate respondsToSelector:@selector(updateHardFeedback:feedBackInfo:)]) {
                                    [self.delegate updateHardFeedback:self feedBackInfo:UpdateHardFeedBackAllowableUpdate];
                                }
                            }
                            else{
                                //禁止固件升级
                                if ([self.delegate respondsToSelector:@selector(updateHardFeedback:feedBackInfo:)]) {
                                    [self.delegate updateHardFeedback:self feedBackInfo:UpdateHardFeedBackNotAllowUpdate];
                                }
                            }
                            NSLog(@"%@",[JCDataConvert ToInteger:payload] == 0? @"禁止固件升级！":@"允许固件升级！");
                        }
                            break;
                            
                            //响应固件升级包状态
                        case BoardRespondFirmwareState:
                        {
                            NSLog(@"滑板响应固件升级包状态 -- %@\n",data);
                            if ([self.delegate respondsToSelector:@selector(updateHardFeedback:feedBackInfo:)]) {
                                [self.delegate updateHardFeedback:self feedBackInfo:UpdateHardFeedBackReceivePackageSituation];
                            }
                            
                        }
                            break;
                            
                            //响应发送固件升级包
                        case BoardRespondSendUpdatePakgeState:
                        {
//                            JCLog(@"响应发送固件升级包 -- %@",data);
                            NSData *payload = [data subdataWithRange:NSMakeRange(3, length)];
                            NSInteger payloadNum = [JCDataConvert ToInteger:payload];
                            if (payloadNum == 1) {
                                                                NSLog(@"滑板要求APP发送下一帧号的固件包。\n");
                                if ([self.delegate respondsToSelector:@selector(updateHardFeedback:feedBackInfo:)])
                                    [self.delegate updateHardFeedback:self feedBackInfo:UpdateHardFeedBackAskNextFrame];
                            }
                            else if (payloadNum == 2) {
                                                                NSLog(@"滑板固件升级完成。只有当收到最后一帧固件包时ACK才为2。");
                                if ([self.delegate respondsToSelector:@selector(updateHardFeedback:feedBackInfo:)])
                                    [self.delegate updateHardFeedback:self feedBackInfo:UpdateHardFeedBackUpdateSuccess];
                            }
                            else if (payloadNum == 3) {
                                                                NSLog(@"滑板固件升级失败。滑板自动回复到升级之前的版本。");
                                if ([self.delegate respondsToSelector:@selector(updateHardFeedback:feedBackInfo:)])
                                    [self.delegate updateHardFeedback:self feedBackInfo:UpdateHardFeedBackUpdateFail];
                            }
                        }
                            break;
                            
                            //响应查询滑板信息
                        case BoardRespondQueryBoard:
                        {
//                            JCLog(@"响应查询滑板实时信息 -- %@",data);
                            NSData *payload = [data subdataWithRange:NSMakeRange(3, length)];
                            _bluetoothData.isCharge = [JCDataConvert ToInteger:[payload subdataWithRange:NSMakeRange(0, 1)]];
                            _bluetoothData.battery = [JCDataConvert ToInteger:[payload subdataWithRange:NSMakeRange(1, 1)]];
                            _bluetoothData.speed = [JCDataConvert ToInteger:[payload subdataWithRange:NSMakeRange(2, 1)]];
                            _bluetoothData.motorTemp = [JCDataConvert ToInteger:[payload subdataWithRange:NSMakeRange(3, 1)]];
                            _bluetoothData.CPUTemp = [JCDataConvert ToInteger:[payload subdataWithRange:NSMakeRange(4, 1)]];
                            _bluetoothData.batteryTemp = [JCDataConvert ToInteger:[payload subdataWithRange:NSMakeRange(5, 1)]];
                            _bluetoothData.cache = [JCDataConvert ToInteger:[payload subdataWithRange:NSMakeRange(6, 1)]];
                        }
                            break;
                            
                            //响应查询滑板GPS信息
                        case BoardRespondQueryGPS:
                        {
//                            if (!tv) {
//                                tv = [[UITextView alloc]initWithFrame:CGRectMake(0, kHeight - 170, kWidth, 120*ScreenHTMP)];
//                                tv.backgroundColor = [UIColor blackColor];
//                                tv.textColor = [UIColor greenColor];
//                                dispatch_async(dispatch_get_main_queue(), ^{
//                                    [[UIApplication sharedApplication].keyWindow.rootViewController.view addSubview:tv];
//                                });
//                            }
                            
                            
                            
                            NSData *payload = [data subdataWithRange:NSMakeRange(3, length)];
//                            JCLog(@"响应查询滑板GPS信息 -- %@",data);
                            if ([JCDataConvert ToInteger:[payload subdataWithRange:NSMakeRange(0, 1)]] == 1) {
#pragma mark 转换GPS数据
//                                JCLog(@"GPS数据有效");
                                
//                                dispatch_async(dispatch_get_main_queue(), ^{
//                                    tv.text = [NSString stringWithFormat:@"%@\n-->GPS有效:%@",tv.text,[JCDataConvert ConvertHexToString:data]];
//                                });
                                
                                NSData *latDire = [payload subdataWithRange:NSMakeRange(1, 1)];
                                NSData *latData = [payload subdataWithRange:NSMakeRange(2, 5)];
                                NSData *lonDire = [payload subdataWithRange:NSMakeRange(7, 1)];
                                NSData *lonData = [payload subdataWithRange:NSMakeRange(8, 6)];
                                
                                //纬度转换
                                NSMutableString *latStr = [[JCDataConvert ConvertHexToString:latData] mutableCopy] ;
                                [latStr replaceCharactersInRange:NSMakeRange(4, 1) withString:@"."];
                                
                                //经度转换
                                NSMutableString *lonStr = [[JCDataConvert ConvertHexToString:lonData] mutableCopy];
                                [lonStr replaceCharactersInRange:NSMakeRange(5, 1) withString:@"."];
                                
                                NSDictionary *GPSDic = @{@"latDirection":[[JCDataConvert ConvertHexToString:latDire]isEqualToString:@"dd"]?@"1":@"0",
                                                         @"latValue":[NSString stringWithString:latStr],
                                                         @"lonDirection":[[JCDataConvert ConvertHexToString:lonDire]isEqualToString:@"aa"]?@"1":@"0",
                                                         @"lonValue":[NSString stringWithString:lonStr]};
                                
                                _bluetoothData.GPSDic = GPSDic;
                            }
                            else{
//                                JCLog(@"GPS数据无效");
//                                dispatch_async(dispatch_get_main_queue(), ^{
//                                    tv.text = [NSString stringWithFormat:@"%@\n❎无效❌GPS:%@",tv.text,[JCDataConvert ConvertHexToString:data]];
//                                });
                            }
                            
                        }
                            break;
                            
                            //响应查询滑板MAC地址信息
                        case BoardRespondQueryMACAddress:
                        {
//                            JCLog(@"响应查询滑板MAC地址信息 -- %@",data);
                            NSData *payload = [data subdataWithRange:NSMakeRange(3, length)];
                            NSString *macAdd = nil;
                            for (int i = 0; i < length; i++)
                            {
                                NSRange range = NSMakeRange(i, 1);
                                NSData* subData = [payload subdataWithRange:range];
                                if (i == 0) {
                                    macAdd = [[NSString alloc]initWithData:subData encoding:NSUTF8StringEncoding];
                                }
                                else if (i == 1){
                                    macAdd = [macAdd stringByAppendingString:[[NSString alloc]initWithData:subData encoding:NSUTF8StringEncoding]];
                                }
                                else if (i == 2){
                                    NSMutableString *rev = [[JCDataConvert ConvertHexToString:subData] mutableCopy];
                                    [rev insertString:@"." atIndex:1];
                                    macAdd = [macAdd stringByAppendingString:[NSString stringWithFormat:@"v%@",rev]];
//                                    JCLog(@"%@-->%@",subData,macAdd);
                                }
                                else {
                                    NSString *appending = [JCDataConvert ConvertHexToString:subData];
                                    macAdd = [macAdd stringByAppendingString:[NSString stringWithFormat:@"-%@",appending]];
                                }
                            }
                            _bluetoothData.MACAddress = macAdd;
//                            JCLog(@"---%@",macAdd);//得到MAC地址
                        }
                            break;
                            
                            //响应重发上一次数据
                        case BoardRespondRepeatLastData:
                        {
//                            JCLog(@"滑板要求重发上一次数据 -- %@",data);
                            if ([self.delegate respondsToSelector:@selector(updateHardFeedback:feedBackInfo:)])
                                [self.delegate updateHardFeedback:self feedBackInfo:UpdateHardFeedBackRepeat];
                        }
                            break;
                            
                            
/*======================响应查询滑板GPS缓存======================*/
                        case BoardRespondQueryCacheGPS:
                        {
                            NSLog(@"响应查询滑板GPS缓存 -- %@",data);
                            NSData *payload = [data subdataWithRange:NSMakeRange(3, length)];
                            NSInteger cacheCount = [JCDataConvert ToInteger:payload];
                            _bluetoothData.cacheGPSCount = cacheCount;
                            NSLog(@"滑板缓存数量为：%ld",cacheCount);
                        }
                            break;
                            
                            
                            
/*======================响应上传缓存GPS数据======================*/
                        case BoardRespondQueryUploadGPS:
                        {
                            NSData *payload = [data subdataWithRange:NSMakeRange(3, length)];
                            NSLog(@"响应查询滑板缓存GPS信息 -- %@",data);
                            if ([JCDataConvert ToInteger:[payload subdataWithRange:NSMakeRange(0, 1)]] == 1) {
#pragma mark 转换缓存GPS数据
                                NSLog(@"缓存GPS数据有效");
                                
//                                dispatch_async(dispatch_get_main_queue(), ^{
//                                    tv.text = [NSString stringWithFormat:@"%@\n-->缓存GPS有效:%@",tv.text,[JCDataConvert ConvertHexToString:data]];
//                                });
                                
                                NSData *latDire = [payload subdataWithRange:NSMakeRange(1, 1)];
                                NSData *latData = [payload subdataWithRange:NSMakeRange(2, 5)];
                                NSData *lonDire = [payload subdataWithRange:NSMakeRange(7, 1)];
                                NSData *lonData = [payload subdataWithRange:NSMakeRange(8, 6)];
                                
                                //纬度转换
                                NSMutableString *latStr = [[JCDataConvert ConvertHexToString:latData] mutableCopy] ;
                                [latStr replaceCharactersInRange:NSMakeRange(4, 1) withString:@"."];
                                
                                //经度转换
                                NSMutableString *lonStr = [[JCDataConvert ConvertHexToString:lonData] mutableCopy];
                                [lonStr replaceCharactersInRange:NSMakeRange(5, 1) withString:@"."];
                                
                                NSDictionary *cacheGPSDic = @{@"latDirection":[[JCDataConvert ConvertHexToString:latDire]isEqualToString:@"dd"]?@"1":@"0",
                                                         @"latValue":[NSString stringWithString:latStr],
                                                         @"lonDirection":[[JCDataConvert ConvertHexToString:lonDire]isEqualToString:@"aa"]?@"1":@"0",
                                                         @"lonValue":[NSString stringWithString:lonStr]};
                                
                                _bluetoothData.cacheGPSDic = cacheGPSDic;
                            }
                            else{
                                NSLog(@"缓存GPS数据无效");
//                                dispatch_async(dispatch_get_main_queue(), ^{
//                                    tv.text = [NSString stringWithFormat:@"%@\n❎无效❌缓存GPS:%@",tv.text,[JCDataConvert ConvertHexToString:data]];
//                                });
                            }

                        }
                            break;
                            
                            //响应清除GPS缓存
                        case BoardRespondQueryClearCacheGPS:
                        {
                            NSLog(@"响应清除GPS缓存 -- %@",data);
                        }
                            break;
                            
                            //响应停止固件升级
                        case BoardRespondCancelUpdateFirmware:
                        {
                            NSLog(@"响应停止固件升级 -- %@",data);
                        }
                            break;
                            
                            //响应滑板电源状态
                        case BoardRespondBoardPowerState:
                        {
                            NSLog(@"响应滑板电源状态: -- %@",data);
                            NSData *payload = [data subdataWithRange:NSMakeRange(3, length)];
                            NSInteger skateBoardPowerState = [JCDataConvert ToInteger:payload];
                            if (skateBoardPowerState == SkateBoardPowerOn) {
                                NSLog(@"滑板开机  \n");
                                _skateBoardPower = SkateBoardPowerOn;
                                
                                //如果是在轨迹模式下重新接上的连接，则获取GPS缓存条数
                                if (_isRecordTrack) {
                                    NSLog(@"轨迹模式下重连设备，获取缓存情况,延时1秒");
                                    [NSTimer scheduledTimerWithTimeInterval:1 repeats:NO block:^(NSTimer * _Nonnull timer) {
                                        
                                        [self sendDataUseCommand:APP_COMMAND_QUERY_CACHE_GPS Payload:@"00"];//发送查询GPS缓存指令
                                    }];
                                    
                                }
                                else{
                                    //此处是子线程，需要回到主线程开启定时器
                                    dispatch_async(dispatch_get_main_queue(), ^{
                                        //连接成功，开启发送查询滑板指令
                                        [self startCheckHardwareInfo];
                                    });
                                   
                                }

                            }
                            else if (skateBoardPowerState == SkateBoardPowerOff){
                                NSLog(@"滑板滑板待机  \n");
                                _skateBoardPower = SkateBoardPowerOff;
                                [self stopCheckHardwareInfo];//停止查询硬件信息
                            }
                        }
                            break;
                            
                        default:
                            break;
                    }
                    
                    //                for (int i = 1; i < data.length; i++)
                    //                {
                    //                    NSRange range = NSMakeRange(i, 1);
                    //                    NSData* subData = [data subdataWithRange:range];
                    //                    NSInteger checkSum = strtoul([[JCDataConvert ConvertHexToString:subData] UTF8String], 0, 16);
                    //                    JCLog(@"---%@---%s---%ld\n\n",subData,[[JCDataConvert ConvertHexToString:subData] UTF8String],checkSum);
                    //                    if ([subData isEqualToData:[JCDataConvert hexToBytes:@"fe"]])
                    //                    {
                    //
                    //                        JCLog(@"以上是帧头 -- %ld",(long)checkSum);
                    //                    }
                    //
                    //                    if ([subData isEqualToData:[JCDataConvert hexToBytes:@"ef"]])
                    //                    {
                    //
                    //                        JCLog(@"以上是帧尾 -- %ld",(long)checkSum);
                    //                    }
                    //                }
                    
                }
            });
        }
    }else{
        NSLog(@"未发现特征值.");
    }
}

#pragma mark 蓝牙外设连接断开，自动重连
- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error{
    
    [self stopCheckHardwareInfo];//停止发送查询硬件信息指令
    [self stopLoopCheckCommandBuffer];//停止轮询发送指令
    
    if ([self.delegate respondsToSelector:@selector(bluetoothManager:didDisconnectPeripheral:error:)]) {
        [self.delegate bluetoothManager:self didDisconnectPeripheral:peripheral error:error];
    }

    if (peripheral) {
        NSLog(@"\n\n断开与%@的连接，正在重连...\n\n",_currentPeripheral);
        [_manager connectToPeripheral:_currentPeripheral];
    }
}


/*!
 *  通过蓝牙发送data数据到外设
 *
 *  @param data -[in] 要发送的字符串
 */
- (void)sendData:(nullable NSData *)data{
    [self.currentPeripheral writeValue:data
                     forCharacteristic:_writeCharacteristic
                                  type:CBCharacteristicWriteWithoutResponse];
}
#pragma mark 发送数据
-(void)sendString:(NSString *)string
{
    if (_currentPeripheral.state == CBPeripheralStateConnected){
        NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding];
        
        [_currentPeripheral writeValue:data
                     forCharacteristic:_writeCharacteristic
                                  type:CBCharacteristicWriteWithoutResponse];
    }
}

#pragma mark - 轮询发送指令机制
/*
 *@开始轮询发送指令
 */
- (void)startLoopCheckCommandBuffer{
    NSLog(@"开启轮询发送指令");
    _sendCommandLoop = [NSTimer scheduledTimerWithTimeInterval:kLoopCheckTime target:self selector:@selector(loopCheckCommandBufferToSend) userInfo:nil repeats:YES];
}

/*
 *@关闭轮询发送指令
 */
- (void)stopLoopCheckCommandBuffer{
    NSLog(@"关闭轮询发送指令");
    [_sendCommandLoop invalidate];
    _sendCommandLoop = nil;
    [_commandBuffer removeAllObjects];//清空指令缓存区
}

/*
 *@轮询发送指令
 */
- (void)loopCheckCommandBufferToSend{
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if (_commandBuffer.count > 0) {
            if (!_writeCharacteristic) {
                return ;
            }
            //将缓冲区第一个指令发出去
            [_currentPeripheral writeValue:[_commandBuffer firstObject]
                         forCharacteristic:_writeCharacteristic
                                      type:CBCharacteristicWriteWithoutResponse];
            
            NSLog(@"发送的指令为：===> %@",[_commandBuffer firstObject]);
            
            //删除已发送指令
            [_commandBuffer removeObjectAtIndex:0];
        }
        
    });
}

#pragma mark - 查询硬件信息
/*
 *@开始查询硬件信息
 */
- (void)startCheckHardwareInfo{

    NSLog(@"开启查询硬件信息");
    if (_checkHardInfoTimer) {
        
        NSLog(@"+++++++++++++++\n\n\n\n查询硬件信息故障\n\n\n\n++++++++++++++++");
        
        return;
    }
    _checkHardInfoTimer = [NSTimer scheduledTimerWithTimeInterval:kCheckHardInfoTime repeats:YES block:^(NSTimer * _Nonnull timer) {
        [self sendDataUseCommand:APP_COMMAND_QUERY_BOARD Payload:@"00"];//发送查询硬件信息指令
    }];
}

/*
 *@停止轮询发送指令
 */
- (void)stopCheckHardwareInfo{
    NSLog(@"关闭查询硬件信息");
    [_checkHardInfoTimer invalidate];
    _checkHardInfoTimer = nil;
    
}

#pragma mark 重新扫描外设
- (void)reScan
{
//    if (![JCUserManager sharedUser].loginState) {
//        JCLog(@"未登录账号，不打开蓝牙");
//        return;
//    }
    if (_currentPeripheral) {
        [_myCentralManager cancelPeripheralConnection:_currentPeripheral];//断开连接
        _currentPeripheral = nil;
        _readCharacteristic = nil;
        _writeCharacteristic = nil;
    }
    
    [_myCentralManager scanForPeripheralsWithServices:nil//@[[CBUUID UUIDWithString:kServiceUUID]]
                                              options:@{CBCentralManagerScanOptionAllowDuplicatesKey:[NSNumber numberWithBool:NO]}];
}

#pragma mark 停止扫描外设
- (void)stopScan{
    [_myCentralManager stopScan];
}

#pragma mark 断开外设连接
- (void)disConnectToPeripheral:(CBPeripheral *)peripheral{
    [_myCentralManager cancelPeripheralConnection:peripheral];
    _currentPeripheral = nil;
//    _readCharacteristic = nil;
//    _writeCharacteristic = nil;
}

#pragma APP发送指令数据
- (void)sendDataUseCommand:(NSString *)command
                   Payload:(NSString *)payload{
    //开线程处理发送数据
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    
        NSInteger length = payload.length/2;
        //拼接帧头+指令+长度+数据
        NSString *sendStr = [SOP_APP stringByAppendingFormat:@"%@%@%@",command,[JCDataConvert ToHex:(int)length],payload];
        //计算出checkSum
        NSInteger checkSum = 0;
        for (NSInteger i = 0; i < 3; i++) {
            switch (i) {
                case 0:
                    checkSum += strtoul([command UTF8String], 0, 16);
                    break;
                case 1:
                    checkSum += length;
                    break;
                case 2:
                {
                    NSInteger subCheckNum = 0;
                    for (NSInteger calcuChekNum = 0; calcuChekNum < payload.length/2.0; calcuChekNum++) {
                        NSString *cutStr = [payload substringWithRange:NSMakeRange(calcuChekNum*2, 2)];
                        //                    JCLog(@"拆分的： --- %@",cutStr);
                        subCheckNum += strtoul([cutStr UTF8String], 0, 16);
                    }
                    
                    checkSum += subCheckNum;
                    checkSum %= 256;//溢出的直接忽略掉
                }
                    break;
                default:
                    break;
            }
        }
        //转换成十六进制
        NSString *checkSumStr = [JCDataConvert ToHex:(int)checkSum];
        //将checkSum拼接进去
        sendStr = [sendStr stringByAppendingFormat:@"%@%@",checkSumStr,EOP_APP];
        //打印出来看
        //    JCLog(@"转换前的结果：%@ \n 转换后的结果：%@",sendStr,[JCDataConvert hexToBytes:sendStr]);
        //    JCLog(@"发送的数据为：== > %@ checkNum = %d\n\n",[JCDataConvert hexToBytes:sendStr],(int)checkSum);
        
        //指令已转换成data数据，将其填装进缓冲区待发送
        if (_currentPeripheral) {
            [_commandBuffer addObject:[JCDataConvert hexToBytes:sendStr]];
        }
        
    });
}

@end
