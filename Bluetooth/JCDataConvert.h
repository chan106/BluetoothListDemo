//
//  JCDataConvert.h
//  Zebra
//
//  Created by 奥赛龙-Guo.JC on 2016/11/8.
//  Copyright © 2016年 奥赛龙科技. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface JCDataConvert : NSObject

/*!
 *  @将字符串中制定字符删除
 *  @str -[in] 需要处理的字符串
 *  @deleChar -[in] 需要删除的字符
 *  @return -[out] 转换后的字符
 */
+(NSString *) stringDeleteString:(NSString *)str by:(unichar)deleChar;

/*!
 *  @将十六进制数据转换成字符串
 *  @needConvertHex -[in] 需要转换的Hex
 *  @return -[out] 转换后的字符串
 */
+ (NSString *)ConvertHexToString:(NSData *)needConvertHex;

/*!
 *  @字符串转data（十六进制）
 *  @str -[in] 需要转换的字符串
 *  @return -[out] 转换后的字符串(十六进制)
 */
+ (NSData*)hexToBytes:(NSString *)str;

/*!
 *  @将十进制转化为十六进制
 *  @tmpid -[in] 需要转换的数字
 *  @return -[out] 转换后的字符串
 */
+ (NSString *)ToHex:(int)tmpid;

/*!
 *  @将十六进制转化为十进制
 *  @tmpid -[in] 需要转换的十六进制
 *  @return -[out] 转换后的整数
 */
+ (NSInteger)ToInteger:(NSData *)hexData;

@end
