//
//  ViewController.m
//  BluetoothListDemo
//
//  Created by coollang on 17/2/24.
//  Copyright © 2017年 coollang. All rights reserved.
//

#import "ViewController.h"
#import "JCDeviceViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}
- (IBAction)search:(UIButton *)sender {
    
    
    [self.navigationController pushViewController:[JCDeviceViewController new] animated:YES];
    
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
