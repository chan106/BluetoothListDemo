//
//  JCTableViewCell.m
//  Turing
//
//  Created by Guo.JC on 16/9/17.
//  Copyright © 2016年 Guo.JC. All rights reserved.
//

#import "JCBluetoothCell.h"


@interface JCBluetoothCell ()
@property (weak, nonatomic) IBOutlet UIImageView *signal;
@property (weak, nonatomic) IBOutlet UILabel *signalLabel;
@property (weak, nonatomic) IBOutlet UILabel *name;
@property (weak, nonatomic) IBOutlet UILabel *sevices;
@property (weak, nonatomic) IBOutlet UILabel *distance;

@end

@implementation JCBluetoothCell



- (void)setBlutoothInfo:(JCBlutoothInfoModel *)blutoothInfo
{
    _blutoothInfo = blutoothInfo;
    
    NSNumber *RSSI = blutoothInfo.RSSI;
    
    self.signalLabel.text = [RSSI stringValue];
    
    self.name.text = blutoothInfo.peripheral.name;
    self.sevices.text = [NSString stringWithFormat:@"%lu Sevices",(unsigned long)((NSArray *)blutoothInfo.advertisementData[@"kCBAdvDataServiceUUIDs"]).count];
    
    /*计算蓝牙距离*/
    int iRssi = abs([RSSI intValue]);
    float power = (iRssi-59)/(10*2.0);
    float distance = pow(10, power);
    
    self.distance.text = [NSString stringWithFormat:@"%.3f米",distance];
    if (iRssi < 40) {
        self.signal.image = [UIImage imageNamed:[NSString stringWithFormat:@"信号-4"]];
    }
    else if(iRssi > 100){
        self.signal.image = [UIImage imageNamed:[NSString stringWithFormat:@"信号-0"]];
    }
    else if(iRssi <= 100 || iRssi >= 40){
        self.signal.image = [UIImage imageNamed:[NSString stringWithFormat:@"信号-%01d",5-((iRssi - 25)/15)]];
    }
}

@end
