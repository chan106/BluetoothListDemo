//
//  JCBluetoothManager.h
//  Zebra
//
//  Created by 奥赛龙-Guo.JC on 2016/10/29.
//  Copyright © 2016年 奥赛龙科技. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>


typedef NS_ENUM(NSInteger, UpdateHardFeedBack) {

    /*!
     *  允许升级
     */
    UpdateHardFeedBackAllowableUpdate = 0,
    /*!
     *  不允许升级
     */
    UpdateHardFeedBackNotAllowUpdate,
    /*!
     *  收到固件包概况
     */
    UpdateHardFeedBackReceivePackageSituation,
    /*!
     *  要求发送下一帧
     */
    UpdateHardFeedBackAskNextFrame,
    /*!
     *  升级成功
     */
    UpdateHardFeedBackUpdateSuccess,
    /*!
     *  升级失败
     */
    UpdateHardFeedBackUpdateFail,
    /*!
     *  要求重发上一帧数据
     */
    UpdateHardFeedBackRepeat,

};


typedef NS_ENUM(NSInteger, BluetoothOpenState) {
/*!
*  蓝牙打开
*/
    BluetoothOpenStateIsOpen = 0,
/*!
*  蓝牙关闭
*/
    BluetoothOpenStateIsClosed = 1
};


typedef NS_ENUM(BOOL, SkateBoardPowerState) {
    /*!
     *  滑板关机、待机
     */
    SkateBoardPowerOff = NO,
    /*!
     *  滑板开机
     */
    SkateBoardPowerOn = YES
};


@class JCBluetoothManager;

/**
 *  蓝牙管理器中心协议
 */
@protocol JCBluetoothManagerDelegate <NSObject>

@optional

/*!
 *  蓝牙开启状态改变
 *
 *  @param manager -[in] 蓝牙管理中心
 *  @param openState -[in] 蓝牙开启状态
 */
- (void)bluetoothStateChange:(nullable JCBluetoothManager *)manager
                       state:(BluetoothOpenState)openState;

/*!
 *  发现新设备
 *
 *  @param manager -[in] 蓝牙管理中心
 *  @param peripheral -[in] 发现的外设
 *  @param advertisementData -[in] 外设中的广播包
 *  @param RSSI -[in] 外设信号强度
 */
- (void)foundPeripheral:(nullable JCBluetoothManager *)manager
             peripheral:(nullable CBPeripheral *)peripheral
      advertisementData:(nullable NSDictionary *)advertisementData
                   RSSI:(nullable NSNumber *)RSSI;

/*!
 *  蓝牙连接外设成功
 *
 *  @param manager -[in] 蓝牙管理中心
 *  @param peripheral -[in] 连接成功的外设
 */
- (void)bluetoothManager:(nullable JCBluetoothManager*)manager
didSucceedConectPeripheral:(nullable CBPeripheral *)peripheral;

/*!
 *  蓝牙连接外设失败
 *
 *  @param manager -[in] 蓝牙管理中心
 *  @param peripheral -[in] 连接失败的外设
 */
- (void)bluetoothManager:(nullable JCBluetoothManager*)manager
 didFailConectPeripheral:(nullable CBPeripheral *)peripheral;

/*!
 *  收到已连接的外设传过来的数据
 *
 *  @param manager -[in] 蓝牙管理中心
 *  @param data -[in] 外设发过来的data数据
 */
- (void)receiveData:(nullable JCBluetoothManager *)manager
               data:(nullable NSData *)data;

/*!
 *  收到已连接的外设传过来的数据
 *
 *  @param manager -[in] 蓝牙管理中心
 *  @param feedBack -[in]   固件升级发过来的反馈信息
 */
- (void)updateHardFeedback:(nullable JCBluetoothManager *) manager
                      feedBackInfo:(UpdateHardFeedBack)feedBack;

/*!
 *  与外设的连接断开
 *
 *  @param manager -[in] 蓝牙管理中心
 *  @param peripheral -[in]   连接的外设
 *  @param error -[in]   错误信息
 */
- (void)bluetoothManager:(nullable JCBluetoothManager *)manager
 didDisconnectPeripheral:(nullable CBPeripheral *)peripheral
                   error:(nullable NSError *)error;

@required

@end





@interface JCBluetoothManager : NSObject<
                                            CBCentralManagerDelegate,       //作为中央设备
                                            CBPeripheralDelegate            //外设代理
                                        >

@property (nonatomic, strong, nullable) CBPeripheral   *currentPeripheral;
@property (nonatomic, assign) BluetoothOpenState bluetoothState;
@property (nonatomic, weak, nullable) id <JCBluetoothManagerDelegate> delegate;

@property (nonatomic, strong, nullable) NSTimer *checkHardInfoTimer;        /**< 查询硬件信息定时器 */

@property (nonatomic, assign) BOOL isRecordTrack;                           /**< 是否在记录轨迹 */
@property (nonatomic, assign) SkateBoardPowerState skateBoardPower;         /**< 滑板开、关机状态 */

/*!
 *  创建全局蓝牙管理中心
 *
 *  @return 返回蓝牙管理中心对象单例
 */
+ (nullable JCBluetoothManager *)shareCBCentralManager;

/*!
 *  重新扫描外设
 *
 */
- (void)reScan;

/*!
 *  停止扫描外设
 *
 */
- (void)stopScan;

/*!
 *  连接到外设蓝牙
 *
 *  @param peripheral -[in] 要连接的外设
 */
- (void)connectToPeripheral:(nullable CBPeripheral *)peripheral;

/*!
 *  断开与外设蓝牙连接
 *
 *  @param peripheral -[in] 要断开的外设
 */
- (void)disConnectToPeripheral:(nullable CBPeripheral *)peripheral;

/*!
 *  通过蓝牙发送字符串到外设
 *
 *  @param string -[in] 要发送的字符串
 */
- (void)sendString:(nullable NSString *)string;

/*!
 *  通过蓝牙发送data数据到外设
 *
 *  @param data -[in] 要发送的字符串
 */
- (void)sendData:(nullable NSData *)data;

/*!
 *  通过协议发送数据到外设
 *
 *  @param command  -[in] 指令
 *  @param payload  -[in] 数据有效段
 */
- (void)sendDataUseCommand:(nullable NSString *)command
                   Payload:(nullable NSString *)payload;

/*!
 *  启动查询滑板硬件信息
 *
 */
- (void)startCheckHardwareInfo;

/*!
 *  停止查询滑板硬件信息
 *
 */
- (void)stopCheckHardwareInfo;

@end
