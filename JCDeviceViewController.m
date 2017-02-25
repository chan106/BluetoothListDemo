//
//  JCDeviceViewController.m
//  Victor
//
//  Created by coollang on 17/2/24.
//  Copyright © 2017年 coollang. All rights reserved.
//

#define ScanTimeInterval        3.0
#define SearchOutTime           10

#import "JCDeviceViewController.h"
#import "JCBlutoothInfoModel.h"
#import "JCBluetoothCell.h"
#import "JCBluetoothManager.h"



@interface JCDeviceViewController ()<JCBluetoothManagerDelegate>
@property (weak, nonatomic) IBOutlet UITableView *tableView;

@property (nonatomic, weak) JCBluetoothManager *bluetoothManager;
@property (nonatomic, strong) NSMutableArray *allBlutoothModel;
@property (nonatomic, strong) NSMutableArray *sortArray;
@property (nonatomic, strong) NSTimer *scanTimer;
@property (nonatomic, strong) NSTimer *scanTimeOut;

@property (nonatomic, strong) UIActivityIndicatorView *animation;

@end

@implementation JCDeviceViewController


- (void)viewWillDisappear:(BOOL)animated{
    [super viewWillDisappear:animated];
    
    [_scanTimer invalidate];
    _scanTimer = nil;
    
    [_scanTimeOut invalidate];
    _scanTimeOut = nil;
    
    [_bluetoothManager stopScan];
    _bluetoothManager.delegate = nil;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    _sortArray = [NSMutableArray array];
    
    [self initTabBlewView];//UI控件初始化
    [self setUpBluetooth];//蓝牙初始化
    
    if (_bluetoothManager.bluetoothState == BluetoothOpenStateIsOpen && _bluetoothManager.currentPeripheral == nil) {
        [self startScanPeripherals];//开始扫描外设
    }
    else if (_bluetoothManager.bluetoothState == BluetoothOpenStateIsClosed){
        
    }
    [self setUpUI];
    
}
- (IBAction)searchAction:(UIButton *)sender {
    
    
    
}


- (void)setUpUI{
    _animation = [[UIActivityIndicatorView alloc]initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    [self.view addSubview:_animation];
    _animation.hidesWhenStopped = YES;
    _animation.color = UIColorFromHex(0x333333);
    [_animation startAnimating];
    _animation.center = self.view.center;
}

- (void)reSearch:(UIBarButtonItem *)sender{
    
    [self startScanPeripherals];
    self.navigationItem.rightBarButtonItem.enabled = NO;
    [_animation startAnimating];
    _scanTimeOut = [NSTimer scheduledTimerWithTimeInterval:SearchOutTime repeats:NO block:^(NSTimer * _Nonnull timer) {
        [_scanTimer invalidate];
        _scanTimer = nil;
        [_bluetoothManager stopScan];
        [_animation stopAnimating];
        self.navigationItem.rightBarButtonItem.enabled = YES;
    }];
}

#pragma mark UITabBleView初始化
- (void)initTabBlewView{
    self.tableView.backgroundColor = UIColorFromHex(0xf4f3f3);
    [self.tableView registerNib:[UINib nibWithNibName:@"JCBluetoothCell" bundle:nil] forCellReuseIdentifier:@"myBTCell"];
    //去掉没有数据的cell底部分割线
    UIView *view = [[UIView alloc] init];
    [view setBackgroundColor:[UIColor clearColor]];
    self.tableView.tableFooterView = view;
    self.title = @"搜索设备";
}

#pragma mark - 搜索设备
- (void)searchDevices:(UIButton *)sender{
    JCLog(@"搜索设备");
    [_bluetoothManager reScan];
}

#pragma mark - 蓝牙及相关设置初始化
- (void)setUpBluetooth{
    
    _allBlutoothModel = [NSMutableArray array];
    _bluetoothManager = [JCBluetoothManager shareCBCentralManager];
    _bluetoothManager.delegate = self;
}

#pragma mark - 蓝牙相关代理方法
//蓝牙未开启状态提醒
- (void)bluetoothStateChange:(JCBluetoothManager *)manager state:(BluetoothOpenState)openState{
    JCLog(@"蓝牙状态改变---");
    if (BluetoothOpenStateIsClosed == openState) {
        [self.allBlutoothModel removeAllObjects];
        [self.tableView reloadData];
    }
    else{
    }
}

//发现设备
- (void)foundPeripheral:(JCBluetoothManager *)manager peripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
    // 1 - 创建外设模型
    JCBlutoothInfoModel *model = [[JCBlutoothInfoModel alloc]init];
    model.peripheral = peripheral;
    model.RSSI = RSSI;
    model.advertisementData = advertisementData;
    
    // 2 -解析广播数据
    NSObject *value = [advertisementData objectForKey:@"kCBAdvDataManufacturerData"];
    NSString *macStr = nil;
    
    if (![value isKindOfClass: [NSArray class]]){
        const char *valueString = [[value description] cStringUsingEncoding: NSUTF8StringEncoding];
        if (valueString == NULL) {//如果为空，则跳过，解决出现空指针bug
            return;
        }
        
        macStr = [[NSString alloc]initWithCString:valueString encoding:NSUTF8StringEncoding];
        JCLog(@"发现的设备广播中：%@",macStr);
        model.adverMacAddr = macStr;
    }
    // 3 - 第一次扫描到的设备，添加进数组中
    if (_allBlutoothModel.count == 0) {
        [_allBlutoothModel addObject:model];
    }
    else{
        // 4 - 遍历数组中的蓝牙模型，更新原有的数据（主要是更新信号强度）
        for (NSInteger i = 0; i < _allBlutoothModel.count; i++) {
            JCBlutoothInfoModel *primaryModel = _allBlutoothModel[i];
            CBPeripheral *per = primaryModel.peripheral;
            
            if ([peripheral.identifier.UUIDString isEqualToString:per.identifier.UUIDString]) {
                [_allBlutoothModel replaceObjectAtIndex:i withObject:model];//更新数组中的数据
                
                // 5 - 数组数据源中的模型 按信号值排序
                _sortArray = [NSMutableArray arrayWithArray:[_allBlutoothModel sortedArrayUsingComparator:^NSComparisonResult(JCBlutoothInfoModel *p1, JCBlutoothInfoModel *p2){
                    
                    return [p2.RSSI compare:p1.RSSI];
                }]];
                
                // 6 - 刷新列表
                [self.tableView reloadSections:[[NSIndexSet alloc] initWithIndex:0] withRowAnimation:UITableViewRowAnimationNone];
            }
        }
        // 7 - 若未有包含过此设备，则将其添加进数组中
        if (![_allBlutoothModel containsObject:model]) {
            [_allBlutoothModel addObject:model];
        }
    }
}


#pragma mark - 扫描定时器
- (void)startScanPeripherals
{
    if (!_scanTimer) {
        _scanTimer = [NSTimer timerWithTimeInterval:ScanTimeInterval target:self selector:@selector(scanForPeripherals) userInfo:nil repeats:YES];
        [[NSRunLoop mainRunLoop] addTimer:_scanTimer forMode:NSDefaultRunLoopMode];
    }
    if (_scanTimer && !_scanTimer.valid) {
        [_scanTimer fire];
    }
}

#pragma mark - 扫描外设
- (void)scanForPeripherals
{
    [_bluetoothManager reScan];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    
}

#pragma mark - Table view 数据源
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _sortArray.count;
}

#pragma mark - cell显示
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    JCBluetoothCell *cell = [tableView dequeueReusableCellWithIdentifier:@"myBTCell" forIndexPath:indexPath];
    cell.blutoothInfo = _sortArray[indexPath.row];
    return cell;
}

#pragma mark - 选中连接外设、绑定外设
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}


@end
