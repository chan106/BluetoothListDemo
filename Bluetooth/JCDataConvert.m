//
//  JCDataConvert.m
//  Zebra
//
//  Created by 奥赛龙-Guo.JC on 2016/11/8.
//  Copyright © 2016年 奥赛龙科技. All rights reserved.
//

#import "JCDataConvert.h"

@implementation JCDataConvert

//删除字符串中的制定字符
+(NSString *) stringDeleteString:(NSString *)str by:(unichar)deleChar{
    NSMutableString *str1 = [NSMutableString stringWithString:str];
    for (int i = 0; i < str1.length; i++) {
        unichar c = [str1 characterAtIndex:i];
        NSRange range = NSMakeRange(i, 1);
        if ( c == deleChar ) { //此处可以是任何字符
            [str1 deleteCharactersInRange:range];
            --i;
        }
    }
    NSString *newstr = [NSString stringWithString:str1];
    return newstr;
}
//data转字符串
+ (NSString *)ConvertHexToString:(NSData *)needConvertHex{
    NSString *str = nil;
    const char *valueString = [[needConvertHex description] cStringUsingEncoding: NSUTF8StringEncoding];
    str = [[NSString alloc]initWithCString:valueString encoding:NSUTF8StringEncoding];
    str = [str substringWithRange:NSMakeRange(1, str.length - 2)];
    str = [JCDataConvert stringDeleteString:str by:' '];
    return str;
}

//字符串转data
+ (NSData*)hexToBytes:(NSString *)str
{
    NSMutableData* data = [NSMutableData data];
    int idx;
    for (idx = 0; idx+2 <= str.length; idx+=2) {
        NSRange range = NSMakeRange(idx, 2);
        NSString* hexStr = [str substringWithRange:range];
        NSScanner* scanner = [NSScanner scannerWithString:hexStr];
        unsigned int intValue;
        [scanner scanHexInt:&intValue];
        [data appendBytes:&intValue length:1];
    }
    return data;
}

//将十进制转化为十六进制
+ (NSString *)ToHex:(int)tmpid
{
    NSString *nLetterValue;
    NSString *str =@"";
    int ttmpig;
    for (int i = 0; i<9; i++) {
        ttmpig=tmpid%16;
        tmpid=tmpid/16;
        switch (ttmpig)
        {
            case 10:
                nLetterValue =@"A";break;
            case 11:
                nLetterValue =@"B";break;
            case 12:
                nLetterValue =@"C";break;
            case 13:
                nLetterValue =@"D";break;
            case 14:
                nLetterValue =@"E";break;
            case 15:
                nLetterValue =@"F";break;
            default:
                nLetterValue = [NSString stringWithFormat:@"%u",ttmpig];
                
        }
        str = [nLetterValue stringByAppendingString:str];
        if (tmpid == 0) {
            break;
        }
    }
    if(str.length == 1 || str.length%2){
        return [NSString stringWithFormat:@"0%@",str];
    }else{
        return str;
    }
}


//将十六进制转换成十进制
+ (NSInteger)ToInteger:(NSData *)hexData{
    return (strtoul([[JCDataConvert ConvertHexToString:hexData] UTF8String], 0, 16));
}
@end
