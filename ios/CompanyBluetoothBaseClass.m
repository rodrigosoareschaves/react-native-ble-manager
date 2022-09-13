//
//  ItronBaseClass.m
//  ItronLibrary
//
//  Created by 攀杨 on 2018/8/6.
//  Copyright © 2018年 攀杨. All rights reserved.
//

#import "CompanyBluetoothBaseClass.h"
#import "CompanyBluetooth.h"
//#import "TribleDes.h"
#import "CompanyToolClass.h"
#import "TLVanalyze.h"

#import "MySocket.h"

#define WS(weakSelf,self) __weak __typeof(self) weakSelf = self


#define CUSTOMER1 @"01020304050607080910111213141516"
#define CUSTOMER2 @"101112131415161718191a1b1c1d1e1f"//艾创标准版
#define CUSTOMER_HAIWAI @"00112233445566778899AACCBBDDEEFF"
#define CUSTOMER_SHENGFUTONG @"e1893d03c448a359cc58b07eadb65a56"

#define PAGENUMBER 120

//2020.04.28 1.0.1版本，增加09ff测试命令
//2020.06.04 1.0.4版本 串口增加开启、关闭蓝牙命令
//2020.06.16 1.0.5版本 串口增加初始化获取设备命令
//2020.06.22 1.0.6版本 获取设备类型TSN和SN互换，刷卡SN改成TSN
//2020.07.10 1.0.7版本 增加app下载和kernel下载
//2020.07.16 1.0.8版本 修改透传NFC bug
//2020.08.06 1.0.9版本 增加socket接收服务器
//2020.08.06 1.0.10版本 串口不分包
//2020.09.08 1.0.11版本 增加上送磁道明文
//2020.09.08 1.0.12版本 卡类型返回4个字节
//2020.09.29 1.0.13版本 设备SN如果开头不是000030,就ASC码转Hex
//2020.10.30 1.0.14版本 升级时，回调升级进度
//2021.03.10 1.0.15版本 台湾升级固件，添加m6plus
#define SDKVERSION @"1.0.15"

#pragma mark 定义客户类型
static NSString *customerType = @"";

static CompanyBluetoothBaseClass *instance = nil;


@interface CompanyBluetoothBaseClass ()
{
    //设备类型
    int deviceKind;
    //有无log
    BOOL itronLog;
    //判断是更新AID还是RID，1为更新AID，2为清除AID，3为更新RID，24为清除RID
    int aidOrRid;
    //刷卡时的控制标志
    NSString *controlSign;
    
    //蓝牙接收数据是否完毕
    BOOL accepting;
    NSMutableData* acceptData;
    int acceptDatalen;
    int acceptDataSumLen;
    
    //发送数据定时器
    NSTimer *sendTimer;
    
    dispatch_queue_t queue;
}
//蓝牙操作的单例
@property (nonatomic,strong)CompanyBluetooth *bleManager;

//itron代理
@property (nonatomic,weak)id<CompanyDelegate>delegate1;

//命令类型
@property (nonatomic,assign)int commandType;

//socket
@property(nonatomic,strong)MySocket *socket;

//命令类型
@property (nonatomic,assign)int is0601;

@property (nonatomic,assign)BOOL isSend;

//远程下载数据
@property (nonatomic,strong)DownloadTag * downloadTag;
//远程下载数据数组
@property (nonatomic,strong)NSArray *downloadDataArr;

@end

@implementation CompanyBluetoothBaseClass

- (NSString *)getSDKVersion{
    return SDKVERSION;
}
- (BOOL)isConnected{
    if (self.bleManager) {
        return self.bleManager.bleState;
    }
    else{
        return NO;
    }
}
- (void)setDeviceType:(int)deviceType{
   deviceKind = deviceType;
}
+ (CompanyBluetoothBaseClass *)getInstance{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}
- (instancetype)init{
    if (self = [super init]) {
        [self setDebug:YES];
        
        self.bleManager = [CompanyBluetooth getInstance];
    }
    return self;
}



+(instancetype)allocWithZone:(struct _NSZone *)zone{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [super allocWithZone:zone];
    });
    return instance;
}

- (void)setDelegate:(id<CompanyDelegate>)delegate{
    self.delegate1 = delegate;
    self.bleManager.delegate = delegate;
}
- (void)setDebug:(BOOL)isLog{
    itronLog = isLog;
    self.bleManager.itronLog = isLog;
}

#pragma mark 搜索蓝牙
- (void)searchDevices:(id<CompanyDelegate>)delegate timeout:(int)timeout{
    [self.bleManager searchDevices:delegate timeout:timeout];
}
//停止搜索
#pragma mark 停止搜索
- (void)stopSearching{
    [self.bleManager stopSearching];
}
//连接蓝牙
#pragma mark 连接蓝牙(通过UUID)
- (void)openDevice:(NSString *)UUIDString cbDelegate:(id<CompanyDelegate>)cb timeout:(int)timeout{
    [self.bleManager openDevice:UUIDString cbDelegate:cb timeout:timeout];
}
#pragma mark 连接蓝牙(通过外设)
- (void)openDevice:(CBPeripheral *)peripheral delegate:(id<CompanyDelegate>)cb timeout:(int)timeout{
    [self.bleManager openDevice:peripheral delegate:cb timeout:timeout];
}

//断开蓝牙
#pragma mark 断开蓝牙
-(void)closeDevice{
    [self.bleManager closeDevice];
}
#pragma mark 蓝牙收到数据
//蓝牙收到数据
- (void)receiveData:(NSData *)data{
    //测试数据
    // data = [ItronToolClass hexToData:@"6D00CF0002A00000C91F4204106336301F4101011F4E04323431301F47136217710704078161D24102200000046400000F1F5110363231373731303730343037383136311F4D0800007710704078161F5201001F5303803B001F486B9F260814FD83D270ACCD729F2701809F101307010103A0A812010A0100000000980F8563EF9F3704D27B391F9F3602CE6F9505208000E0009A031807269C01009F02060000000010005F2A02084082027C009F1A0208409F3303E0F8C89F3501228408A0000003330101011F44089876543210987654B7"];
    //data = [CompanyToolClass hexToData:@"6d00430002e200003d013b393030303030303031323734aa4cb773b0f1000000000000000000000000000054383838303935343941303336303530314d3039313034323690006b"];
    if (itronLog) {
        NSLog(@"length:%d <<<<< receiveData:%@",(int)data.length,[CompanyToolClass DataToHex:data]);
        /*
        NSString *str = [[CompanyToolClass DataToHex:data] uppercaseString];
        NSString *str1 = @"";
        for (int i=0; i<(int)str.length/2; i++) {
            str1 = [NSString stringWithFormat:@"%@ %@",str1,[str substringWithRange:NSMakeRange(i*2, 2)]];
        }
        NSLog(@"length:%d <<<<< receiveData:%@",(int)data.length,str1);*/
    }
    Byte *resultBuf = (Byte *)[data bytes];
    int resCode1 = resultBuf[4];
    int resCode2 = resultBuf[5];
    int res = resultBuf[6];
    //m6plus下载
    if (resCode1 == 0x07 && resCode2 == 0x01) {
        if (res == 1) {
            if (self.delegate1 && [self.delegate1 respondsToSelector:@selector(sendCommandTimeout)]) {
                [self.delegate1 sendCommandTimeout];
            }
            return;
        }
        if (res == 0) {
            NSInteger len = resultBuf[7]*256 + resultBuf[8];
            NSString *dataStr = [CompanyToolClass DataToHex:[data subdataWithRange:NSMakeRange(9, len)]];
            NSArray *arr = [TLVanalyze getTLVArr1:dataStr];
            int isPage = 0;
            int length = 0;
            for (TLVModel *tlv in arr) {
                if ([tlv.tag isEqualToString:@"4346"]) {
                    //0为使用包序号，1为使用偏移地址
                    if ([self hexToInt:[tlv.value substringWithRange:NSMakeRange(4, 2)]] & 0x10) {
                        isPage = 1;
                    }
                }
            }
            for (TLVModel *tlv in arr) {
                if ([tlv.tag isEqualToString:@"444F"]) {
                    length = [self hexToInt:[tlv.value substringWithRange:NSMakeRange(4, 2)]]*256+[self hexToInt:[tlv.value substringWithRange:NSMakeRange(6, 2)]];
                    if (isPage == 0) {
                        int length1 = [self hexToInt:[self.downloadTag.PL substringToIndex:2]]*256+[self hexToInt:[self.downloadTag.PL substringFromIndex:2]];
                        length = length1 * length;
                    }
                }
            }
            
            //数据分包长度
            int pageLength = 512;
            if (self.downloadTag.PL) {
                pageLength = [self hexToInt:[self.downloadTag.PL substringToIndex:2]]*256 + [self hexToInt:[self.downloadTag.PL substringFromIndex:2]];
            }
            self.downloadTag.DownloadData = [self.downloadTag.DownloadData subdataWithRange:NSMakeRange(length, self.downloadTag.DownloadData.length-length)];
            NSMutableArray *mArr = [[NSMutableArray alloc] init];
            for (int i=0; i<self.downloadTag.DownloadData.length/pageLength; i++) {
                [mArr addObject:[self.downloadTag.DownloadData subdataWithRange:NSMakeRange(i*pageLength, pageLength)]];
            }
            if (self.downloadTag.DownloadData.length%pageLength != 0) {
                [mArr addObject:[self.downloadTag.DownloadData subdataWithRange:NSMakeRange(((int)self.downloadTag.DownloadData.length/pageLength)*pageLength, self.downloadTag.DownloadData.length%pageLength)]];
            }
            self.downloadDataArr = mArr;
            [self requestDataPage:0];
        }
        else{
            if (self.delegate1 && [self.delegate1 respondsToSelector:@selector(onFirmwareUpdateRequest:)]) {
                [self.delegate1 onFirmwareUpdateRequest:res];
            }
        }
    }
    if (resCode1 == 0x07 && resCode2 == 0x02) {
        if (res == 1) {
            if (self.delegate1 && [self.delegate1 respondsToSelector:@selector(sendCommandTimeout)]) {
                [self.delegate1 sendCommandTimeout];
            }
            return;
        }
        if (res == 0) {
            NSInteger len = resultBuf[7]*256 + resultBuf[8];
            NSString *dataStr = [CompanyToolClass DataToHex:[data subdataWithRange:NSMakeRange(9, len)]];
            NSArray *arr = [TLVanalyze getTLVArr1:dataStr];
            int isPage = 0;
            int length = 0;
           
            for (TLVModel *tlv in arr) {
               
                if ([tlv.tag isEqualToString:@"4346"]) {
                    //0为使用包序号，1为使用偏移地址
                    if ([self hexToInt:[tlv.value substringWithRange:NSMakeRange(4, 2)]] & 0x10) {
                        isPage = 1;
                    }
                }
            }
            for (TLVModel *tlv in arr) {
                if ([[tlv.tag uppercaseString] isEqualToString:@"444F"]) {
                    length = [self hexToInt:[tlv.value substringWithRange:NSMakeRange(4, 2)]]*256+[self hexToInt:[tlv.value substringWithRange:NSMakeRange(6, 2)]];
                    
                    if (isPage == 1) {
                        int length1 = [self hexToInt:[self.downloadTag.PL substringToIndex:2]]*256+[self hexToInt:[self.downloadTag.PL substringFromIndex:2]];
                        
                        length = length/length1;
                    }
                }
            }
            if (length<self.downloadDataArr.count) {
                if (self.delegate1 && [self.delegate1 respondsToSelector:@selector(onFirmwareUpdateRequestProgress:)]) {
                    [self.delegate1 onFirmwareUpdateRequestProgress:(length*100/self.downloadDataArr.count)];
                }
                [self requestDataPage:length];

            }
            else{
                if (self.delegate1 && [self.delegate1 respondsToSelector:@selector(onFirmwareUpdateRequest:)]) {
                    [self.delegate1 onFirmwareUpdateRequest:res];
                }
            }
            //[self requestDataPage:length];
        }
        else{
            if (self.delegate1 && [self.delegate1 respondsToSelector:@selector(onFirmwareUpdateRequest:)]) {
                [self.delegate1 onFirmwareUpdateRequest:res];
            }
        }
    }
    //请求下载
    if ((resCode1 == 0x05 && resCode2 == 0x01)||(resCode1 == 0x06 && resCode2 == 0x00)||(resCode1 == 0x06 && resCode2 == 0x01)||(resCode1 == 0x06 && resCode2 == 0x02)) {
        if (resCode1 == 0x06 && resCode2 == 0x01) {
            self.is0601 = 1;
        }
        else{
            self.is0601 = 0;
        }
        if (res == 1) {
            [self closeSocket];
            if (self.delegate1 && [self.delegate1 respondsToSelector:@selector(sendCommandTimeout)]) {
                [self.delegate1 sendCommandTimeout];
            }
            return;
        }
        //app下载
        if ((self.commandType == 1)||(self.commandType == 2)||(self.commandType == 3)||(self.commandType == 4)) {
            if (res != 0) {
                
                //app
                if (self.commandType == 1) {
                    if (self.delegate1 && [self.delegate1 respondsToSelector:@selector(onStartOnlineFirmwareUpdate:)]) {
                        [self.delegate1 onStartOnlineFirmwareUpdate:res];
                    }
                }
                //kernel
                if (self.commandType == 4) {
                    if (self.delegate1 && [self.delegate1 respondsToSelector:@selector(onStartOnlineKernelUpdate:)]) {
                        [self.delegate1 onStartOnlineKernelUpdate:res];
                    }
                }
                //key
                if (self.commandType == 2) {
                    if (self.delegate1 && [self.delegate1 respondsToSelector:@selector(onStartOnlineKeyUpdate:)]) {
                        [self.delegate1 onStartOnlineKeyUpdate:res];
                    }
                }
                [self closeSocket];
            }
            else{
                //下载完成
                if (resCode1 == 0x06 && resCode2 == 0x02){
                    
                    if (self.commandType == 1) {
                        if (self.delegate1 && [self.delegate1 respondsToSelector:@selector(onStartOnlineFirmwareUpdate:)]) {
                            [self.delegate1 onStartOnlineFirmwareUpdate:res];
                        }
                    }
                    if (self.commandType == 4) {
                        if (self.delegate1 && [self.delegate1 respondsToSelector:@selector(onStartOnlineKernelUpdate:)]) {
                            [self.delegate1 onStartOnlineKernelUpdate:res];
                        }
                    }
                    //key
                    if (self.commandType == 2) {
                        if (self.delegate1 && [self.delegate1 respondsToSelector:@selector(onStartOnlineKeyUpdate:)]) {
                            [self.delegate1 onStartOnlineKeyUpdate:res];
                        }
                    }
                    [self closeSocket];
                    return;
                }
                NSString *random = @"";
                //随机数
                int randomLen = resultBuf[7]*256 + resultBuf[8];
                if (randomLen != 0) {
                    random = [CompanyToolClass DataToHex:[data subdataWithRange:NSMakeRange(9, randomLen-1)]];
                    //2020.10.30 1.0.14版本 升级时，回调升级进度
                    if (random.length>10) {
                        NSString *progressStr = [random substringWithRange:NSMakeRange(random.length-10, 10)];
                        NSString *progressTag = [progressStr substringToIndex:4];
                        NSString *progressLength = [progressStr substringWithRange:NSMakeRange(4, 2)];
                        
                        int checkValue = 0;
                        for (int i=0; i<4; i++) {
                            checkValue = checkValue ^ [self hexToInt:[progressStr substringWithRange:NSMakeRange(2*i, 2)]];
                        }
                        int checkValue1 = [self hexToInt:[progressStr substringWithRange:NSMakeRange(8, 2)]];
                        if ((checkValue == checkValue1)&&([progressTag isEqualToString:@"5052"])&&([progressLength isEqualToString:@"02"])) {
                            int progressValue = [self hexToInt:[progressStr substringWithRange:NSMakeRange(6, 2)]];
                            if (self.delegate1 && [self.delegate1 respondsToSelector:@selector(onOnlineProgress:)]) {
                                [self.delegate1 onOnlineProgress:progressValue];
                            }
                            random = [random substringWithRange:NSMakeRange(0, random.length-10)];
                        }
                    }
                    if (itronLog) {
                        NSLog(@"send service data:%@",random);
                    }
                    
                    [self.socket sendMessage:random];
                }
            }
            return;
        }
    }
    //自动关机时间
    if (resCode1 == 0x09 && resCode2 == 0x08){
        if (res == 1) {
            if (self.delegate1 && [self.delegate1 respondsToSelector:@selector(sendCommandTimeout)]) {
                [self.delegate1 sendCommandTimeout];
            }
            return;
        }
        if (self.delegate1 && [self.delegate1 respondsToSelector:@selector(onSetAutomaticShutdownStatus:)]) {
            [self.delegate1 onSetAutomaticShutdownStatus:res];
        }
    }
    //同步时间
    if (resCode1 == 0x09 && resCode2 == 0x31){
        if (res == 1) {
            if (self.delegate1 && [self.delegate1 respondsToSelector:@selector(sendCommandTimeout)]) {
                [self.delegate1 sendCommandTimeout];
            }
            if ((self.commandType == 1)||(self.commandType == 2)||(self.commandType == 3)||(self.commandType == 4)) {
                [self closeSocket];
            }
            return;
        }
        //远程下载更新时间
        if ((self.commandType == 1)||(self.commandType == 2)||(self.commandType == 3)||(self.commandType == 4)) {
            if (res != 0) {
                if (self.commandType == 1) {
                    if (self.delegate1 && [self.delegate1 respondsToSelector:@selector(onStartOnlineFirmwareUpdate:)]) {
                        [self.delegate1 onStartOnlineFirmwareUpdate:res];
                    }
                }
                if (self.commandType == 4) {
                    if (self.delegate1 && [self.delegate1 respondsToSelector:@selector(onStartOnlineKernelUpdate:)]) {
                        [self.delegate1 onStartOnlineKernelUpdate:res];
                    }
                }
                //key
                if (self.commandType == 2) {
                    if (self.delegate1 && [self.delegate1 respondsToSelector:@selector(onStartOnlineKeyUpdate:)]) {
                        [self.delegate1 onStartOnlineKeyUpdate:res];
                    }
                }
                [self closeSocket];
            }
            else{
                [self requestDown:self.commandType];
            }
            return;
        }
        if (self.delegate1 && [self.delegate1 respondsToSelector:@selector(onSetTerminalDateTime:)]) {
            [self.delegate1 onSetTerminalDateTime:res];
        }
    }
    //获取终端时间
    if (resCode1 == 0x09 && resCode2 == 0x32){
        if (res == 1) {
            if (self.delegate1 && [self.delegate1 respondsToSelector:@selector(sendCommandTimeout)]) {
                [self.delegate1 sendCommandTimeout];
            }
            return;
        }
        NSString *timeStr = @"";
        if (res == 0) {
            int getTimeLen = resultBuf[7]*256 + resultBuf[8];
            if (getTimeLen != 0) {
                timeStr = [CompanyToolClass DataToHex:[data subdataWithRange:NSMakeRange(9, getTimeLen)]];
            }
        }
        if (self.delegate1 && [self.delegate1 respondsToSelector:@selector(onGetTerminalDateTime:status:)]) {
            [self.delegate1 onGetTerminalDateTime:timeStr status:res];
        }
    }
    //回写IC卡
    if (resCode1 == 0x02 && resCode2 == 0xA1){
        if (res == 1) {
            if (self.delegate1 && [self.delegate1 respondsToSelector:@selector(sendCommandTimeout)]) {
                [self.delegate1 sendCommandTimeout];
            }
            return;
        }
        if (res == 0) {
            if (self.delegate1 && [self.delegate1 respondsToSelector:@selector(onSendOnlineProcessResult:scriptResult:data:status:)]) {
                int result1 = resultBuf[9];
                int onlineLen = resultBuf[7]*256 + resultBuf[8];
                if (onlineLen != 0) {
                    int scriptResultLen = resultBuf[10];
                    NSString *scriptResultStr = nil;
                    if (scriptResultLen != 0) {
                        scriptResultStr = [CompanyToolClass DataToHex:[data subdataWithRange:NSMakeRange(11, scriptResultLen)]];
                    }
                    NSString *onlineDataStr = [CompanyToolClass DataToHex:[data subdataWithRange:NSMakeRange(scriptResultLen + 11, onlineLen-scriptResultLen-2)]];
                    [self.delegate1 onSendOnlineProcessResult:result1 scriptResult:scriptResultStr data:onlineDataStr status:0];
                }
                else{
                    [self.delegate1 onSendOnlineProcessResult:0 scriptResult:nil data:nil status:0];
                }
                
            }
        }
        else{
            if (self.delegate1 && [self.delegate1 respondsToSelector:@selector(onSendOnlineProcessResult:scriptResult:data:status:)]) {
                [self.delegate1 onSendOnlineProcessResult:0 scriptResult:nil data:nil status:res];
            }
        }
    }
    //更新AId或RID
    if (resCode1 == 0x09 && resCode2 == 0x22) {
        if (res == 1) {
            if (self.delegate1 && [self.delegate1 respondsToSelector:@selector(sendCommandTimeout)]) {
                [self.delegate1 sendCommandTimeout];
            }
            return;
        }
        if (aidOrRid == 1) {
            if (self.delegate1 && [self.delegate1 respondsToSelector:@selector(onDownloadAIDParameters:)]) {
                [self.delegate1 onDownloadAIDParameters:res];
            }
        }
        if (aidOrRid == 2) {
            if (self.delegate1 && [self.delegate1 respondsToSelector:@selector(onClearAIDParameters:)]) {
                [self.delegate1 onClearAIDParameters:res];
            }
        }
        if (aidOrRid == 3) {
            if (self.delegate1 && [self.delegate1 respondsToSelector:@selector(onDownloadPublicKey:)]) {
                [self.delegate1 onDownloadPublicKey:res];
            }
        }
        if (aidOrRid == 4) {
            if (self.delegate1 && [self.delegate1 respondsToSelector:@selector(onClearPublicKey:)]) {
                [self.delegate1 onClearPublicKey:res];
            }
        }
    }
    
    //获取设备类型
    if (resCode1 == 0x09 && resCode2 == 0x1b) {
        TerminalInfo *terminalInfo = [[TerminalInfo alloc] init];
        if (res == 1) {
            if (self.delegate1 && [self.delegate1 respondsToSelector:@selector(sendCommandTimeout)]) {
                [self.delegate1 sendCommandTimeout];
            }
            return;
        }
        if (res == 0) {
            terminalInfo.terminalType = resultBuf[9];
            int tLen = 13;
            //终端号,SN
            if (resultBuf[11] & 0x01) {
                int TSNLen = resultBuf[tLen];
                tLen = tLen+1;
                NSData *data1 = [data subdataWithRange:NSMakeRange(tLen, TSNLen)];
                NSString *str = [CompanyToolClass DataToHex:data1];
                terminalInfo.TSN = str;
                tLen = tLen + TSNLen;
                if (itronLog) {
                    NSLog(@"TSN:%@",terminalInfo.TSN);
                }
            }
            //版本号
            if (resultBuf[11] & 0x02) {
                int sofeversionLen = resultBuf[tLen];
                tLen = tLen+1;
                NSData *data1 = [data subdataWithRange:NSMakeRange(tLen, sofeversionLen)];
                NSString *str = [CompanyToolClass DataToHex:data1];
                terminalInfo.softVersion = [CompanyToolClass ascToHex:str];
                tLen = tLen+sofeversionLen;
                if (itronLog) {
                    NSLog(@"softVersion:%@",terminalInfo.softVersion);
                }
            }
            //蓝牙名称
            if (resultBuf[11] & 0x04) {
                int bluetoothNameLen = resultBuf[tLen];
                tLen = tLen+1;
                NSData *data1 = [data subdataWithRange:NSMakeRange(tLen, bluetoothNameLen)];
                NSString *str = [CompanyToolClass DataToHex:data1];
                terminalInfo.bluetoothName = [CompanyToolClass ascToHex:str];
                tLen = tLen+bluetoothNameLen;
                if (itronLog) {
                    NSLog(@"bluetoothName:%@",terminalInfo.bluetoothName);
                }
            }
            //蓝牙版本
            if (resultBuf[11] & 0x08) {
                int bluetoothVersionLen = resultBuf[tLen];
                tLen = tLen+1;
                NSData *data1 = [data subdataWithRange:NSMakeRange(tLen, bluetoothVersionLen)];
                NSString *str = [CompanyToolClass DataToHex:data1];
                terminalInfo.bluetoothVersion = [CompanyToolClass ascToHex:str];
                tLen = tLen+bluetoothVersionLen;
                if (itronLog) {
                    NSLog(@"bluetoothVersion:%@",terminalInfo.bluetoothVersion);
                }
            }
            //蓝牙mac地址
            if (resultBuf[11] & 0x10) {
                int bluetoothMACLen = resultBuf[tLen];
                tLen = tLen+1;
                NSData *data1 = [data subdataWithRange:NSMakeRange(tLen, bluetoothMACLen)];
                NSString *str = [CompanyToolClass DataToHex:data1];
                terminalInfo.bluetoothMAC = [CompanyToolClass ascToHex:str];
                tLen = tLen+bluetoothMACLen;
                if (itronLog) {
                    NSLog(@"bluetoothMAC:%@",terminalInfo.bluetoothMAC);
                }
            }
            //版本日期
            if (resultBuf[11] & 0x20) {
                int softVersionDateLen = resultBuf[tLen];
                tLen = tLen+1;
                NSData *data1 = [data subdataWithRange:NSMakeRange(tLen, softVersionDateLen)];
                NSString *str = [CompanyToolClass DataToHex:data1];
                terminalInfo.softVersionDate = [CompanyToolClass ascToHex:str];
                tLen = tLen+softVersionDateLen;
                if (itronLog) {
                    NSLog(@"softVersionDate:%@",terminalInfo.softVersionDate);
                }
            }
            //psam卡号
            if (resultBuf[11] & 0x40) {
                int psamNoLen = resultBuf[tLen];
                tLen = tLen+1;
                NSData *data1 = [data subdataWithRange:NSMakeRange(tLen, psamNoLen)];
                NSString *str = [CompanyToolClass DataToHex:data1];
                terminalInfo.psamNo = str;
                tLen = tLen+psamNoLen;
                if (itronLog) {
                    NSLog(@"psamNo:%@",terminalInfo.psamNo);
                }
            }
            //下面还有21号文的，海外的不解析
            //密钥标志
            if (resultBuf[11] & 0x80) {
                int protocolTypeLen = resultBuf[tLen];
                tLen = tLen+1;
                NSData *data1 = [data subdataWithRange:NSMakeRange(tLen, protocolTypeLen)];
                NSString *str = [CompanyToolClass DataToHex:data1];
                terminalInfo.protocolType = str;
                tLen = tLen + protocolTypeLen;
                if (itronLog) {
                    NSLog(@"protocolType:%@",terminalInfo.protocolType);
                }
            }
            //TSN
            if (resultBuf[12] & 0x01) {
                int snLen = resultBuf[tLen];
                tLen = tLen+1;
                NSData *data1 = [data subdataWithRange:NSMakeRange(tLen, snLen)];
                terminalInfo.SN = [CompanyToolClass DataToHex:data1];
                NSString *str = terminalInfo.SN;
                if (str.length >= 6) {
                    if (![[str substringToIndex:6] isEqualToString:@"000030"]) {
                        terminalInfo.SN = [CompanyToolClass ascToHex:str];
                    }
                }
                tLen = tLen+snLen;
                if (itronLog) {
                    NSLog(@"SN:%@",terminalInfo.SN);
                }
            }
            //kernel版本
            if (resultBuf[12] & 0x02) {
                int kernelVersionLen = resultBuf[tLen];
                tLen = tLen+1;
                NSData *data1 = [data subdataWithRange:NSMakeRange(tLen, kernelVersionLen)];
                NSString *str = [CompanyToolClass DataToHex:data1];
                terminalInfo.kernelVersion = [CompanyToolClass ascToHex:str];
                tLen = tLen + kernelVersionLen;
                if (itronLog) {
                    NSLog(@"kernelVersion:%@",terminalInfo.kernelVersion);
                }
            }
            //硬件版本
            if (resultBuf[12] & 0x04) {
                int hardwareVersionLen = resultBuf[tLen];
                tLen = tLen+1;
                NSData *data1 = [data subdataWithRange:NSMakeRange(tLen, hardwareVersionLen)];
                NSString *str = [CompanyToolClass DataToHex:data1];
                terminalInfo.hardwareVersion = [CompanyToolClass ascToHex:str];
                tLen = tLen + hardwareVersionLen;
                if (itronLog) {
                    NSLog(@"hardwareVersion:%@",terminalInfo.hardwareVersion);
                }
            }
            //固件版本
            if (resultBuf[12] & 0x08) {
                int firmwareVersionLen = resultBuf[tLen];
                tLen = tLen+1;
                NSData *data1 = [data subdataWithRange:NSMakeRange(tLen, firmwareVersionLen)];
                NSString *str = [CompanyToolClass DataToHex:data1];
                terminalInfo.firmwareVersion = [CompanyToolClass ascToHex:str];
                tLen = tLen + firmwareVersionLen;
                if (itronLog) {
                    NSLog(@"firmwareVersion:%@",terminalInfo.firmwareVersion);
                }
            }
            //CPUSN
            if (resultBuf[12] & 0x10) {
                int cpuSNLen = resultBuf[tLen];
                tLen = tLen+1;
                NSData *data1 = [data subdataWithRange:NSMakeRange(tLen, cpuSNLen)];
                NSString *str = [CompanyToolClass DataToHex:data1];
                terminalInfo.cpuSN = str;
                tLen = tLen + cpuSNLen;
                if (itronLog) {
                    NSLog(@"cpuSN:%@",terminalInfo.cpuSN);
                }
            }
            //customerSN
            if (resultBuf[12] & 0x20) {
                int customerSNLen = resultBuf[tLen];
                tLen = tLen+1;
                NSData *data1 = [data subdataWithRange:NSMakeRange(tLen, customerSNLen)];
                NSString *str = [CompanyToolClass ascToHex:[CompanyToolClass DataToHex:data1]];;
                terminalInfo.customerSN = str;
                tLen = tLen + customerSNLen;
                if (itronLog) {
                    NSLog(@"customerSN:%@",terminalInfo.customerSN);
                }
            }
            
        }
        if (self.delegate1 && [self.delegate1 respondsToSelector:@selector(onGetTerminalInfo:status:)]) {
            [self.delegate1 onGetTerminalInfo:terminalInfo status:res];
        }
    }
    //刷卡
    if (resCode1 == 0x02 && resCode2 == 0xa0) {
        if (res == 1) {
            if (self.delegate1 && [self.delegate1 respondsToSelector:@selector(sendCommandTimeout)]) {
                [self.delegate1 sendCommandTimeout];
            }
            return;
        }
        if (res == 0x80) {
            if (self.delegate1 && [self.delegate1 respondsToSelector:@selector(onWaitingcard)]) {
                [self.delegate1 onWaitingcard];
            }
            return;
        }
        if (res == 0x89) {
            return;
        }
        if ((res == 0x84) || (res == 0x8a)) {
            //IC
            if (res == 0x84) {
                if (self.delegate1 && [self.delegate1 respondsToSelector:@selector(onICCardInsertion)]) {
                    [self.delegate1 onICCardInsertion];
                }
            }
            //NFC
            if (res == 0x8a) {
                if (self.delegate1 && [self.delegate1 respondsToSelector:@selector(onNFCCardDetection)]) {
                    [self.delegate1 onNFCCardDetection];
                }
            }
            
            return;
        }
        if (res == 0x00) {
            [self analyzI9:data];
            /*
             if (deviceKind == 1) {
             [self analyzI21b:data];
             return;
             }
             if (deviceKind == 2) {
             [self analyzM7:data];
             return;
             }
             if (deviceKind == 0) {
             [self analyzI9:data];
             return;
             }*/
            
        }
        else{
            CardInfo *cardinfo = [[CardInfo alloc] init];
            if ([data length]>9) {
                int failLength = resultBuf[7]*256 + resultBuf[8];
                cardinfo.swipeFailMessage = [CompanyToolClass DataToHex:[data subdataWithRange:NSMakeRange(9, failLength)]];
            }
            if (self.delegate1 && [self.delegate1 respondsToSelector:@selector(onReadCard:status:)]) {
                [self.delegate1 onReadCard:cardinfo status:res];
            }
        }
    }
    //开始NFC
    if (resCode1 == 0x02 && resCode2 == 0xe0) {
        if (res == 1) {
            if (self.delegate1 && [self.delegate1 respondsToSelector:@selector(sendCommandTimeout)]) {
                [self.delegate1 sendCommandTimeout];
            }
            return;
        }
        if (res != 0x80) {
            if (self.delegate1 && [self.delegate1 respondsToSelector:@selector(onPowerOnAPDU:cardData:status:)]) {
                if (res == 0) {
                    int type = resultBuf[9];
                    int len = resultBuf[8];
                    NSData *cardData = [data subdataWithRange:NSMakeRange(10, len-1)];
                    NSString *cardDatastr = [CompanyToolClass DataToHex:cardData];
                    [self.delegate1 onPowerOnAPDU:type cardData:cardDatastr status:res];
                }
                else{
                    [self.delegate1 onPowerOnAPDU:0 cardData:nil status:res];
                }
            }
        }
        
    }
    //关闭NFC
    if (resCode1 == 0x02 && resCode2 == 0xe1) {
        if (res == 1) {
            if (self.delegate1 && [self.delegate1 respondsToSelector:@selector(sendCommandTimeout)]) {
                [self.delegate1 sendCommandTimeout];
            }
            return;
        }
        if (self.delegate1 && [self.delegate1 respondsToSelector:@selector(onPowerOffAPDU:)]) {
            [self.delegate1 onPowerOffAPDU:res];
        }
    }
    //NFC透传
    if (resCode1 == 0x02 && resCode2 == 0xe2) {
        if (res == 1) {
            if (self.delegate1 && [self.delegate1 respondsToSelector:@selector(sendCommandTimeout)]) {
                [self.delegate1 sendCommandTimeout];
            }
            return;
        }
        if (self.delegate1 && [self.delegate1 respondsToSelector:@selector(onSendApdu:status:)]) {
            if (res == 0) {
                //int len = resultBuf[7]*256 + resultBuf[8];
                int apduNumber = resultBuf[9];
                int len1 = 10;
                NSMutableArray *apduMarr = [[NSMutableArray alloc] init];
                for (int i = 0; i < apduNumber; i++) {
                    NSData *apduNFC_ICData = [data subdataWithRange:NSMakeRange(len1+1, resultBuf[len1])];
                    NSString *apduNFC_ICDataStr = [CompanyToolClass DataToHex:apduNFC_ICData];
                    [apduMarr addObject:apduNFC_ICDataStr];
                    len1 = len1 + resultBuf[len1] + 1;
                }
                [self.delegate1 onSendApdu:apduMarr status:res];
            }
            else if(res == 0x86){
                int len = resultBuf[7]*256 + resultBuf[8];
                NSMutableArray *apduMarr = [[NSMutableArray alloc] init];
                NSData *apduNFC_ICData = [data subdataWithRange:NSMakeRange(9, len)];
                NSString *apduNFC_ICDataStr = [CompanyToolClass DataToHex:apduNFC_ICData];
                [apduMarr addObject:apduNFC_ICDataStr];
                [self.delegate1 onSendApdu:apduMarr status:res];
            }
            else{
                [self.delegate1 onSendApdu:nil status:res];
            }
        }
        
    }
    //获取电池电量
    if (resCode1 == 0x09 && resCode2 == 0x13) {
        if (res == 1) {
            if (self.delegate1 && [self.delegate1 respondsToSelector:@selector(sendCommandTimeout)]) {
                [self.delegate1 sendCommandTimeout];
            }
            return;
        }
        if (self.delegate1 && [self.delegate1 respondsToSelector:@selector(onGetBatteryPower:status:)]) {
            if (res == 0) {
                int batteryPoewr = resultBuf[9]*256 + resultBuf[10];
                int power = 0;
                if(batteryPoewr>=3900){
                    //100%
                    power = 100;
                }else if((batteryPoewr<3900)&&(batteryPoewr >= 3700)){
                    //75%
                    power = 75;
                }else if((batteryPoewr<3700)&&(batteryPoewr >= 3500)){
                    // 50
                    power = 50;
                }else if((batteryPoewr<3500)&&(batteryPoewr >= 3200)){
                    // 25%
                    power = 25;
                }else if(batteryPoewr<3200){
                    //5%
                    power = 5;
                }
                [self.delegate1 onGetBatteryPower:power status:res];
            }
            else{
                [self.delegate1 onGetBatteryPower:0 status:res];
            }
        }
        
    }
    //停止
    if (resCode1 == 0x09 && resCode2 == 0x07) {
        if (res == 1) {
            if (self.delegate1 && [self.delegate1 respondsToSelector:@selector(sendCommandTimeout)]) {
                [self.delegate1 sendCommandTimeout];
            }
            return;
        }
        if (self.delegate1 && [self.delegate1 respondsToSelector:@selector(onStopTrade:)]) {
            [self.delegate1 onStopTrade:res];
        }
    }
    //计算mac
    if (resCode1 == 0x02 && resCode2 == 0x06) {
        if (res == 1) {
            if (self.delegate1 && [self.delegate1 respondsToSelector:@selector(sendCommandTimeout)]) {
                [self.delegate1 sendCommandTimeout];
            }
            return;
        }
        if (self.delegate1 && [self.delegate1 respondsToSelector:@selector(onCalculateMac:status:)]) {
            if (res == 0) {
                int calculateMacLen = resultBuf[7] * 256 + resultBuf[8];
                NSData *calculateMac = [data subdataWithRange:NSMakeRange(9, calculateMacLen)];
                NSString *calculateMacStr = [CompanyToolClass DataToHex:calculateMac];
                [self.delegate1 onCalculateMac:calculateMacStr status:res];
            }
            else{
                [self.delegate1 onCalculateMac:nil status:res];
            }
        }
    }
    //pin加密
    if (resCode1 == 0x02 && resCode2 == 0x20) {
        if (res == 1) {
            if (self.delegate1 && [self.delegate1 respondsToSelector:@selector(sendCommandTimeout)]) {
                [self.delegate1 sendCommandTimeout];
            }
            return;
        }
        if (self.delegate1 && [self.delegate1 respondsToSelector:@selector(onPINEntryResult:status:)]) {
            if (res == 0) {
                int pinEncryLen = resultBuf[7] * 256 + resultBuf[8];
                NSData *pinEncry = [data subdataWithRange:NSMakeRange(9, pinEncryLen)];
                NSString *pinEncryStr = [CompanyToolClass DataToHex:pinEncry];
                [self.delegate1 onPINEntryResult:pinEncryStr status:res];
            }
            else{
                [self.delegate1 onPINEntryResult:nil status:res];
            }
        }
    }
}

/**
 16进制字符串转为int，如"2a"转为42

 @param hex 16进制字符串
 @return int值
 */
-(int)hexToInt:(NSString *)hex{
    NSScanner* scanner = [NSScanner scannerWithString:hex];
    unsigned int intValue;
    [scanner scanHexInt:&intValue];
    return intValue;
}
//计算客户的MAC值
/**
 计算客户的MAC值

 @param data 发送的数据
 @param key 客户的密钥
 @return 返回加上mac后的数据   数据+ mac + 随机数
 */
/*
- (NSString *)calMacWithData:(NSData *)data key:(NSString *)key{
    NSString *random = [NSString stringWithFormat:@"%02x%02x%02x%02x",arc4random()%255,arc4random()%255,arc4random()%255,arc4random()%255];
    NSString *mac1 = [NSString stringWithFormat:@"ff00%@aa55",random];
    //第一步，用客户的密钥离散
    NSString *work = [TribleDes lisan:mac1 mainKey:key];
    //第二步，对发送的数据进行8位异或
    NSString *tt = [self xor8:data];
    //第三步，用离散后的密钥对异或后的值加密
    NSString *tt1 = [TribleDes encData:tt mainKey:work];
    //第四步，取第三步的值前8位加上随机数
    NSString *tt2 = [NSString stringWithFormat:@"%@%@",[tt1 substringToIndex:8],random];
    return tt2;
}*/
//8位异或的方法
- (NSString *)xor8:(NSData *)data{
    //长度不足补0
    NSMutableData *data1 = [NSMutableData dataWithData:data];
    Byte by[8];
    memset(by, 0, 8);
    [data1 appendBytes:by length:(8-data.length%8)];
    Byte *by2 = (Byte *)[data1 bytes];
    Byte xor_res[8];
    memset(xor_res, 0, 8);
    for (int i=0; i<data1.length/8; i++) {
        for (int j=0; j<8; j++) {
            xor_res[j] = xor_res[j]^by2[i*8+j];
        }
    }
    NSData * data2 = [NSData dataWithBytes:xor_res length:8];
    NSString *str = [CompanyToolClass DataToHex:data2];
    return str;
}
#pragma mark 发送数据
- (void)sendData:(NSString *)str{
    NSData *data = [CompanyToolClass hexToData:str];
    Byte *byte = (Byte *)[data bytes];
    int timeout = byte[3];
    NSString *mac = @"";
    if (customerType == nil || [customerType isEqualToString:@""]) {
        
    }
    else{
        //mac = [self calMacWithData:data key:customerType];
    }
    NSString *dataStr = [NSString stringWithFormat:@"%@%@",str,mac];
    //dataStr = @"0002A032002F1F0101401F040201001F0204106336301F0307202002201153551F07033132331F08033530301F0901331F0A023839";
    
    if (itronLog) {
        NSLog(@"--dataStr--%@",dataStr);
    }
    [[CompanyBluetooth getInstance] sendBluetoothData:[CompanyToolClass hexToData:dataStr] timeout:timeout];
   
}
- (void)calldelegateSendCommTimeOut{
    if (itronLog) {
        NSLog(@"SendCommand timeout");
    }
    if (self.delegate1 && [self.delegate1 respondsToSelector:@selector(sendCommandTimeout)]) {
        [self.delegate1 sendCommandTimeout];
    }
}

#pragma mark 获取终端信息
/**
 获取终端信息
 */
- (void)getTerminalInfo{
    [self sendData:@"00091b100000"];
}
#pragma mark 自动关机时间
/**
 设置终端自动关机时间

 @param time second
 */
- (void)setAutomaticShutdown:(int)time{
    NSString *str = [NSString stringWithFormat:@"000908100001%.2x",time];
    [self sendData:str];
}

#pragma mark 设置终端时间
/**
 设置终端时间

 @param datetime 时间，格式yyyyMMddHHmmss  20190807144120
 */
- (void)setTerminalDateTime:(NSString *)datetime{
    NSString *str = [NSString stringWithFormat:@"000931100007%@",datetime];
    [self sendData:str];
}

#pragma mark 获取终端时间
/**
 获取终端时间
 */
- (void)getTerminalDateTime{
    [self sendData:@"000932100000"];
}

#pragma mark 传输RSA公钥
/**
 传输RSA公钥

 @param publickey rsa 密钥
 */
- (void)downloadRSApublicKey:(NSString *)publickey{
    
}

#pragma mark 更新商户号和终端号
/**
 更新商户号和终端号

 @param acceptor 商户号
 @param terminal 终端号
 */
-(void)setAcceptorTerminalIdentification:(NSString*)acceptor Terminal:(NSString *)terminal{
    NSString *acceptor1 = [CompanyToolClass hexToAsc:acceptor];
    NSString *terminal1 = [CompanyToolClass hexToAsc:terminal];
    int len = 2 + (int)acceptor1.length + (int)terminal1.length;
    NSString *str = [NSString stringWithFormat:@"00021110%.2x%.2x%.2x%@%.2x%@",len/256,len%256,(int)acceptor1.length,acceptor1,(int)terminal1,terminal1];
    [self sendData:str];
}

#pragma mark  获取商户号和终端号
/**
 获取商户号和终端号
 */
- (void)getAcceptorIdentification{
    [self sendData:@"000212100000"];
}

#pragma mark  获取终端信息
/**
 获取终端信息
 */
- (void)getTerminalIdentification{
    
}

#pragma mark  退出
/**
 退出
 */
- (void)stopTrade{
    [self sendData:@"000907100000"];
}

#pragma mark  更新主密钥
/**
 更新主密钥

 @param index 主密钥索引
 @param tmk 主密钥
 */
- (void)downloadMainKey:(int)index tmk:(NSString *)tmk{
    
}

#pragma mark  更新工作密钥
/**
 更新工作密钥

 @param index 主密钥索引
 @param PINkey 密码
 @param MACkey mac
 @param DESkey 磁道
 */
- (void)downloadWorkKey:(int)index PINkey:(NSString *)PINkey MACkey:(NSString *)MACkey DESkey:(NSString *)DESkey{
    
}

#pragma mark  计算mac
/**
 计算mac

 @param data mac数据
 */
- (void)calculateMac:(NSString *)data{
    NSString *dataStr = [NSString stringWithFormat:@"1F74%.2x%@",(int)data.length/2,data];
    int len = (int)dataStr.length/2;
    NSString *str = [NSString stringWithFormat:@"00020610%.2x%.2x%@",len/256,len%256,dataStr];
    [self sendData:str];
}

#pragma mark  更新AID
/**
 更新AID

 @param aIDParameters aid
 */
- (void)downloadAIDParameters:(AIDParameters *)aIDParameters{
    aidOrRid = 1;
    NSMutableString *str = [[NSMutableString alloc] initWithFormat:@"31"];
    if (aIDParameters.AID.length>0) {
        [str appendFormat:@"9F06%.2x%@",(int)aIDParameters.AID.length/2,aIDParameters.AID];
    }
    [str appendFormat:@"DF01%.2x%@",(int)[[self intToString:aIDParameters.Asi] length]/2,[self intToString:aIDParameters.Asi]];
    if (aIDParameters.AppVerNum.length>0) {
        [str appendFormat:@"9F09%.2x%@",(int)aIDParameters.AppVerNum.length/2,aIDParameters.AppVerNum];
    }
    if (aIDParameters.TacDefault.length>0) {
        [str appendFormat:@"DF11%.2x%@",(int)aIDParameters.TacDefault.length/2,aIDParameters.TacDefault];
    }
    if (aIDParameters.TacOnline.length>0) {
        [str appendFormat:@"DF12%.2x%@",(int)aIDParameters.TacOnline.length/2,aIDParameters.TacOnline];
    }
    if (aIDParameters.TacDecline.length>0) {
        [str appendFormat:@"DF13%.2x%@",(int)aIDParameters.TacDecline.length/2,aIDParameters.TacDecline];
    }
    if (aIDParameters.FloorLimit.length>0) {
        [str appendFormat:@"9F1B%.2x%@",(int)aIDParameters.FloorLimit.length/2,aIDParameters.FloorLimit];
    }
    if (aIDParameters.Threshold.length>0) {
        [str appendFormat:@"DF15%.2x%@",(int)aIDParameters.Threshold.length/2,aIDParameters.Threshold];
    }
    [str appendFormat:@"DF16%.2x%@",(int)[[self intToString:aIDParameters.MaxTargetPercent] length]/2,[self intToString:aIDParameters.MaxTargetPercent]];
    [str appendFormat:@"DF17%.2x%@",(int)[[self intToString:aIDParameters.TargetPercent] length]/2,[self intToString:aIDParameters.TargetPercent]];
    if (aIDParameters.TermDDOL.length>0) {
        [str appendFormat:@"DF14%.2x%@",(int)aIDParameters.TermDDOL.length/2,aIDParameters.TermDDOL];
    }
    if (aIDParameters.vlptranslimit.length>0) {
        [str appendFormat:@"DF20%.2x%@",(int)aIDParameters.vlptranslimit.length/2,aIDParameters.vlptranslimit];
    }
    if (aIDParameters.termcvm_limit.length>0) {
        [str appendFormat:@"DF21%.2x%@",(int)aIDParameters.termcvm_limit.length/2,aIDParameters.termcvm_limit];
    }
    if (aIDParameters.clessofflinelimitamt.length>0) {
        [str appendFormat:@"DF19%.2x%@",(int)aIDParameters.clessofflinelimitamt.length/2,aIDParameters.clessofflinelimitamt];
    }
    if (aIDParameters.otherTLV && aIDParameters.otherTLV.length>0) {
        [str appendString:aIDParameters.otherTLV];
    }
    int len = 2 + (int)str.length/2;
    NSString *str1 = [NSString stringWithFormat:@"00092210%.2x%.2x0101%@",len/256,len%256,str];
    [self sendData:str1];
}

#pragma mark  清除AID
/**
 清除AID
 */
- (void)clearAIDParameters{
    aidOrRid = 2;
    [self sendData:@"0009221000720100319F0607A0000000031010DF0101009F08020030DF1105D84000A800DF1205D84004F800DF130500100000009F1B0400002710DF150400000000DF160100DF170100DF14039F3704DF1801019F7B06000000080000DF1906000000050000DF2006000000100000DF2106000000010000"];
}

#pragma mark  更新RID
/**
 更新RID
 
 @param caPublicKey rid
 */
- (void)downloadPublicKey:(CAPublicKey *)caPublicKey{
    aidOrRid = 3;
    NSMutableString *str = [[NSMutableString alloc] initWithFormat:@"31"];
    if (caPublicKey.RID.length>0) {
        [str appendFormat:@"9F06%.2x%@",(int)caPublicKey.RID.length/2,caPublicKey.RID];
    }
    [str appendFormat:@"9F22%.2x%@",(int)[[self intToString:caPublicKey.CAPKI] length]/2,[self intToString:caPublicKey.CAPKI]];
    [str appendFormat:@"DF07%.2x%@",(int)[[self intToString:caPublicKey.HashInd] length]/2,[self intToString:caPublicKey.HashInd]];
    
    if (caPublicKey.ExpireDate.length>0) {
        [str appendFormat:@"DF05%.2x%@",(int)caPublicKey.ExpireDate.length/2,caPublicKey.ExpireDate];
    }
    [str appendFormat:@"DF06%.2x%@",(int)[[self intToString:caPublicKey.ArithInd] length]/2,[self intToString:caPublicKey.ArithInd]];
    if (caPublicKey.Modul.length>0) {
        [str appendFormat:@"DF0281%.2x%@",(int)caPublicKey.Modul.length/2,caPublicKey.Modul];
    }
    if (caPublicKey.Exponent.length>0) {
        [str appendFormat:@"DF04%.2x%@",(int)caPublicKey.Exponent.length/2,caPublicKey.Exponent];
    }
    if (caPublicKey.CheckSum.length>0) {
        [str appendFormat:@"DF03%.2x%@",(int)caPublicKey.CheckSum.length/2,caPublicKey.CheckSum];
    }
    int len = 2 + (int)str.length/2;
    NSString *str1 = [NSString stringWithFormat:@"00092210%.2x%.2x0001%@",len/256,len%256,str];
    [self sendData:str1];
    
}
- (NSString *)intToString:(int)number{
    NSString *str = [NSString stringWithFormat:@"%x",number];
    if (str.length%2 == 1) {
        str = [NSString stringWithFormat:@"0%@",str];
    }
    return str;
}
#pragma mark  清除RID
/**
 清除RID
 */
- (void)clearPublicKey{
    aidOrRid = 4;
    [self sendData:@"0009221000ED0000319F0605A0000003339F220103DF050420241231DF060101DF070101DF0281B0B0627DEE87864F9C18C13B9A1F025448BF13C58380C91F4CEBA9F9BCB214FF8414E9B59D6ABA10F941C7331768F47B2127907D857FA39AAF8CE02045DD01619D689EE731C551159BE7EB2D51A372FF56B556E5CB2FDE36E23073A44CA215D6C26CA68847B388E39520E0026E62294B557D6470440CA0AEFC9438C923AEC9B2098D6D3A1AF5E8B1DE36F4B53040109D89B77CAFAF70C26C601ABDF59EEC0FDC8A99089140CD2E817E335175B03B7AA33DDF040103DF031487F0CD7C0E86F38F89A66F8C47071A8B88586F26"];
}

#pragma mark  刷卡
/**
 刷卡

 @param timeout 超时时间
 @param tradeData 刷卡参数
 */
- (void)startEmvProcess:(int)timeout tradeData:(TradeData*)tradeData{
    [self sendData:[self getI9Str:tradeData timeout:timeout]];
    /*
    //I9
    if (deviceKind == 0) {
        [self sendData:[self getI9Str:tradeData timeout:timeout]];
        return;
    }
    //i21b or i31
    if (deviceKind == 1) {
        [self sendData:[self getI21bStr:tradeData timeout:timeout]];
        return;
    }*/
}
#pragma mark  转加密
- (void)PINEntry:(NSString *)pin{
    pin = [CompanyToolClass hexToAsc:pin];
    int pinlen = (int)pin.length/2;
    NSString *data = [NSString stringWithFormat:@"1F74%.2x%@",pinlen,pin];
    int len = (int)data.length/2;
    NSString *str = [NSString stringWithFormat:@"00022010%.2x%.2x%@",len/256,len%256,data];
    [self sendData:str];
}
#pragma mark  回写数据
- (void)sendOnlineProcessResult:(NSString*)data{
    int len = (int)data.length/2;
    NSString *str = [NSString stringWithFormat:@"0002A110%.2x%.2x%@",len/256,len%256,data];
    [self sendData:str];
}
#pragma mark  开始NFC/IC
- (void)powerOnAPDU:(int)type timeout:(int)timeout{
    NSString *str = [NSString stringWithFormat:@"0002e0%.2x0001%.2x",timeout,type];
    [self sendData:str];
}

#pragma mark  结束NFC/IC
- (void)powerOffAPDU{
    [self sendData:@"0002e1100000"];
}
#pragma mark  透传
- (void)sendApdu:(int)type apdu:(NSArray*)apduData timeout:(int)timeout{
    NSMutableString *mstr = [[NSMutableString alloc] init];
    for (NSString *str in apduData) {
        [mstr appendFormat:@"%.2x30%@",(int)str.length/2+1,str];
    }
    int len = 2 + (int)mstr.length/2;
    NSString *str = [NSString stringWithFormat:@"0002e2%.2x%.2x%.2x%.2x%.2x%@",timeout,len/256,len%256,type,(int)apduData.count,mstr];
    [self sendData:str];
}

#pragma mark  获取电量
- (void)getBatteryPower{
    [self sendData:@"000913100000"];
    //[self sendData:@"00010217040506070809101112131415160001020304050607080910111213141516000102030405060708091011121314151600010203040506070809101112131415160001020304050607080910111213141516000102030405060708091011121314151600010203040506070809101112131415160001020304050607080910111213141516000102030405060708091011121314151600010203040506070809101112131415160001020304050607080910111213141516000102030405060708091011121314151600010203040506070809101112131415160001020304050607080910111213141516000102030405060708091011121314151600010203040506070809101112131415160001020304050607080910111213141516000102030405060708091011121314151600010203040506070809101112131415160001020304050607080910111213141516000102030405060708091011121314151600010203040506070809101112131415160001020304050607080910111213141516000102030405060708091011121314151600010203040506070809101112131415160001020304050607080910111213141516000102030405060708091011121314151600010203040506070809101112131415160001020304050607080910111213141516000102030405060708091011121314151600010001021704050607080910111213141516000102030405060708091011121314151600010203040506070809101112131415160001020304050607080910111213141516000102030405060708091011121314151600010203040506070809101112131415160001020304050607080910111213141516000102030405060708091011121314151600010203040506070809101112131415160001020304050607080910111213141516000102030405060708091011121314151600010203040506070809101112131415160001020304050607080910111213141516000102030405060708091011121314151600010203040506070809101112131415160001020304050607080910111213141516000102030405060708091011121314151600010203040506070809101112131415160001020304050607080910111213141516000102030405060708091011121314151600010203040506070809101112131415160001020304050607080910111213141516000102030405060708091011121314151600010203040506070809101112131415160001020304050607080910111213141516000102030405060708091011121314151600010203040506070809101112131415160001020304050607080910111213141516000102030405060708091011121314151600010203040506070809101112131415160001"];
}
#pragma mark  关机
- (void)shutDown{
    [self sendData:@"000980100000"];
}
//组建TLV
- (NSString *)getTLV:(NSString *)tag value:(NSString *)value{
    NSString *len = nil;
    if (value.length/2<=127) {
        len = [NSString stringWithFormat:@"%.2lx",(long)value.length/2];
    }
    if (value.length/2>127 && value.length/2<=255) {
        len = [NSString stringWithFormat:@"81%.2lx",(long)value.length/2];
    }
    if (value.length/2>255 && value.length/2<=0xffff) {
        len = [NSString stringWithFormat:@"82%.2lx%.2lx",(long)(value.length/2)/256,(long)(value.length/2)%256];
    }
    NSString *str = [[NSString stringWithFormat:@"%@%@%@",tag,len,value] uppercaseString];
    return str;
}
#pragma mark i21b or i31组建
- (NSString *)getI21bStr:(TradeData*)swipe timeout:(int)timeout{
    //系统时间
    NSDate *currentDate = [NSDate date];
    NSDateFormatter *dataFormatter = [[NSDateFormatter alloc] init];
    [dataFormatter setDateFormat:@"yyMMddHHmmss"];
    NSString *dateStr = [dataFormatter stringFromDate:currentDate];
    [dataFormatter setDateFormat:@"yyyyMMddHHmmss"];
    NSString *dateStr1 = [dataFormatter stringFromDate:currentDate];
    NSMutableString *mstr = [[NSMutableString alloc] init];
    [mstr appendFormat:@"%@%@%@010101",swipe.swipeMode,swipe.sign,dateStr1];
    if (swipe.random) {
        [mstr appendFormat:@"%.2lx%@",swipe.random.length/2,swipe.random];
    }
    if (!swipe.random) {
        [mstr appendString:@"00"];
    }
    if (swipe.cash) {
        [mstr appendFormat:@"%.2lx%@",swipe.cash.length,[CompanyToolClass hexToAsc:swipe.cash]];
    }
    if (swipe.transactionInfo) {
        NSString *str1 = [NSString stringWithFormat:@"9a03%@9f2103%@9c01%@5f2a%.2lx%@9f1a%.2lx%@",[dateStr substringToIndex:6],[dateStr substringFromIndex:6],swipe.transactionInfo.type,swipe.transactionInfo.currencyCode.length/2,swipe.transactionInfo.currencyCode,swipe.transactionInfo.countryCode.length/2,swipe.transactionInfo.countryCode];
        [mstr appendFormat:@"%.2lx%@",str1.length/2,str1];
    }
    if (swipe.extraData) {
        [mstr appendFormat:@"%.2lx%@",swipe.extraData.length/2,swipe.extraData];
    }
    if (!swipe.extraData) {
        [mstr appendString:@"00"];
    }
    NSString *str2 = [NSString stringWithFormat:@"0002a0%.2x%.2lx%.2lx%@",timeout,(mstr.length/2)/256,(mstr.length/2)%256,mstr];
    return str2;
}
#pragma mark i9组建
- (NSString *)getI9Str:(TradeData*)swipe timeout:(int)timeout{
    NSMutableString *str = [[NSMutableString alloc] init];
    int len =0;
    //刷卡模式
    if (swipe.swipeMode) {
        NSString *str1 = [self getTLV:@"1F01" value:swipe.swipeMode];
        [str appendString:str1];
        len = len + (int)str1.length/2;
    }
    //控制标志
    if (swipe.sign) {
        NSString *str1 = [self getTLV:@"1F02" value:swipe.sign];
        [str appendString:str1];
        len = len + (int)str1.length/2;
    }
    //系统时间
    NSDate *currentDate = [NSDate date];
    NSDateFormatter *dataFormatter = [[NSDateFormatter alloc] init];
    [dataFormatter setDateFormat:@"yyyyMMddHHmmss"];
    NSString *dateStr = [dataFormatter stringFromDate:currentDate];
    NSString *str2 = [self getTLV:@"1F03" value:dateStr];
    [str appendString:str2];
    len = len + (int)str2.length/2;
    //加密算法
    if (swipe.encryptionAlgorithm) {
        NSString *str1 = [self getTLV:@"1F04" value:swipe.encryptionAlgorithm];
        [str appendString:str1];
        len = len + (int)str1.length/2;
    }
    //刷卡标题
    if (swipe.swipeTitle) {
        NSStringEncoding ytenc = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000);
        NSString *strCode = [CompanyToolClass DataToHex:[swipe.swipeTitle dataUsingEncoding:ytenc]];
        NSString *str1 = [self getTLV:@"1F05" value:strCode];
        [str appendString:str1];
        len = len + (int)str1.length/2;
    }
    //密码输入标题
    if (swipe.pinTitle) {
        NSStringEncoding ytenc = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000);
        NSString *strCode = [CompanyToolClass DataToHex:[swipe.pinTitle dataUsingEncoding:ytenc]];
        NSString *str1 = [self getTLV:@"1F06" value:strCode];
        [str appendString:str1];
        len = len + (int)str1.length/2;
    }
    //随机数
    if (swipe.random) {
        NSString *str1 = [self getTLV:@"1F07" value:swipe.random];
        [str appendString:str1];
        len = len + (int)str1.length/2;
    }
    //交易金额
    if (swipe.cash) {
        NSString *str1 = [self getTLV:@"1F08" value:[CompanyToolClass hexToAsc:swipe.cash]];
        [str appendString:str1];
        len = len + (int)str1.length/2;
    }
    //附加交易信息
    if (swipe.transactionInfo) {
        NSString *dateTime = [self getTLV:@"9A" value:[dateStr substringToIndex:6]];
        NSString *time = [self getTLV:@"9F21" value:[dateStr substringFromIndex:6]];
        NSString *currencyCode = [self getTLV:@"5F2A" value:swipe.transactionInfo.currencyCode];
        NSString *type = [self getTLV:@"9C" value:swipe.transactionInfo.type];
        NSString *str1 = [self getTLV:@"1F09" value:[NSString stringWithFormat:@"%@%@%@%@",dateTime,time,currencyCode,type]];
        [str appendString:str1];
        len = len + (int)str1.length/2;
    }
    //附加数据
    if (swipe.extraData) {
        NSString *str1 = [self getTLV:@"1F0A" value:swipe.extraData];
        [str appendString:str1];
        len = len + (int)str1.length/2;
    }
    //回显数据
    if (swipe.displayData) {
        NSString *str1 = [self getTLV:@"1F0B" value:swipe.displayData];
        [str appendString:str1];
        len = len + (int)str1.length/2;
    }
    
    NSString *sendStr = [NSString stringWithFormat:@"0002a0%.2x%.2x%.2x%@",timeout,len/256,len%256,str];
    //刷卡测试数据
    //sendStr = @"0002A030003F1F0101711F02041A6736301F0307201807261427081F040501010909091F05035357501F06035057441F07031234561F0804313030301F0901331F0A023938";
    //sendStr = @"0002A01E003E1F0101711F0204026736301F0307201807261427081F0404010000001F05035357501F06035057441F07031234561F0804313030301F0901331F0A023938";
    return sendStr;
}

#pragma mark i21b or i31解析
//i21b解析
- (void)analyzI21b:(NSData *)data{
    if (itronLog) {
        NSLog(@"Analyz I21B or I31.....");
    }
    Byte *resultBuf = (Byte *)[data bytes];
    CardInfo *cardInfo = [[CardInfo alloc] init];
    cardInfo.cardType = resultBuf[13] & 0x03;
    int len = 14;
    if ((cardInfo.cardType == 3)) {
        len = len +1;
    }
    int trackLen = resultBuf[len];
    len = len + 1;
    cardInfo.tracks = [CompanyToolClass DataToHex:[data subdataWithRange:NSMakeRange(len, trackLen)]];
    if (itronLog) {
        NSLog(@"track:%@",cardInfo.tracks);
    }
    len = len + trackLen;
    /*
    //磁道密文
    if (resultBuf[9] & 0x80) {
        cardInfo.encryTrack1Len = resultBuf[len];
        cardInfo.encryTrack2Len = resultBuf[len+1];
        cardInfo.encryTrack3Len = resultBuf[len+2];
        len = len + 3;
    }
    //磁道明文
    if (resultBuf[9] & 0x08) {
        cardInfo.track1Len = resultBuf[len];
        cardInfo.encryTrack2Len = resultBuf[len+1];
        cardInfo.encryTrack3Len = resultBuf[len+2];
        len = len + 3;
    }*/
    //卡有效期
    cardInfo.cardexpiryDate = [[NSString alloc] initWithData:[data subdataWithRange:NSMakeRange(len, 4)] encoding:NSUTF8StringEncoding];
    if (itronLog) {
        NSLog(@"CardExpiryDate:%@",cardInfo.cardexpiryDate);
    }
    len = len + 4;
    //卡号
    int cardNumLen = resultBuf[len];
    len = len + 1;
    cardInfo.cardNo = [[NSString alloc] initWithData:[data subdataWithRange:NSMakeRange(len, cardNumLen)] encoding:NSUTF8StringEncoding];
    if (itronLog) {
        NSLog(@"CardNumber:%@",cardInfo.cardNo);
    }
    len = len + cardNumLen;
    //PAN码
    if (!(resultBuf[9] & 0x20)) {
        cardInfo.PAN = [CompanyToolClass DataToHex:[data subdataWithRange:NSMakeRange(len, 8)]];
        len = len + 8;
        if (itronLog) {
            NSLog(@"PAN:%@",cardInfo.PAN);
        }
    }
    
    if ((cardInfo.cardType!=02) && (cardInfo.cardType!=0)) {
        //卡片序列号
        int xulieLen = resultBuf[len];
        len = len + 1;
        cardInfo.cardSerial = [CompanyToolClass DataToHex:[data subdataWithRange:NSMakeRange(len, xulieLen)]];
        len = len + xulieLen;
        if (itronLog) {
            NSLog(@"CardSerial:%@",cardInfo.cardSerial);
        }
        //CVM
        cardInfo.CVM = [CompanyToolClass DataToHex:[data subdataWithRange:NSMakeRange(len, 3)]];
        len = len + 3;
        if (itronLog) {
            NSLog(@"CVM:%@",cardInfo.CVM);
        }
        //55域
        int icDataLen = resultBuf[len]*256 + resultBuf[len+1];
        len = len + 2;
        cardInfo.icdata = [CompanyToolClass DataToHex:[data subdataWithRange:NSMakeRange(len, icDataLen)]];
        len = len + icDataLen;
        if (itronLog) {
            NSLog(@"ICData:%@",cardInfo.icdata);
        }
    }
    //SN号
    int SNLen = resultBuf[len];
    len = len + 1;
    cardInfo.TSN = [CompanyToolClass DataToHex:[data subdataWithRange:NSMakeRange(len, SNLen)]];
    len = len + SNLen;
    if (itronLog) {
        NSLog(@"SN:%@",cardInfo.TSN);
    }
    //mac
    if (resultBuf[9] & 0x02) {
        cardInfo.MAC = [CompanyToolClass DataToHex:[data subdataWithRange:NSMakeRange(len, 8)]];
        if (itronLog) {
            NSLog(@"MAC:%@",cardInfo.MAC);
        }
    }
    if (self.delegate1 && [self.delegate1 respondsToSelector:@selector(onReadCard:status:)]) {
        [self.delegate1 onReadCard:cardInfo status:0];
    }
}

#pragma mark m7解析
//m7解析
- (void)analyzM7:(NSData *)data{
    
}

//去掉字符串后面的空格
- (NSString *)removeSpace:(NSString *)str{
    if (str.length == 0) {
        return @"";
    }
    int length = (int)str.length;
    for (int i = 0; i < length; i++) {
        NSString * str1 = [str substringWithRange:NSMakeRange(str.length-1, 1)];
        if ([str1 isEqualToString:@" "]) {
            str = [str substringToIndex:str.length-1];
        }else{
            return str;
        }
    }
    return str;
}
#pragma mark i9解析
//m7解析
- (void)analyzI9:(NSData *)data{
    if (itronLog) {
        NSLog(@"Analyz I9.....");
    }
    Byte *resultBuf = (Byte *)[data bytes];
    NSInteger len = resultBuf[7]*256 + resultBuf[8];
    NSString *dataStr = [CompanyToolClass DataToHex:[data subdataWithRange:NSMakeRange(9, len)]];
    CardInfo *cardInfo = [[CardInfo alloc] init];
    NSArray *arr = [TLVanalyze getTLVArr:dataStr];
    for (TLVModel *tlv in arr) {
        //NSLog(@"--%@--%lu--%@",tlv.tag,tlv.length,tlv.value);
        //磁道明文
        if ([tlv.tag isEqualToString:@"1F40"]) {
            cardInfo.tracks = tlv.value;
            if (itronLog) {
                NSLog(@"tracks:%@",cardInfo.tracks);
            }
        }
        //卡类型
        if ([tlv.tag isEqualToString:@"1F41"]) {
            cardInfo.cardType = [self hexToInt:[tlv.value substringToIndex:2]];
            if (itronLog) {
                NSLog(@"cardType:%d",cardInfo.cardType);
            }
        }
        //回送的控制模式
        if ([tlv.tag isEqualToString:@"1F42"]) {
            cardInfo.ControlModel = tlv.value;
            if (itronLog) {
                NSLog(@"ControlModel:%@",cardInfo.ControlModel);
            }
        }
        //psam卡号
        if ([tlv.tag isEqualToString:@"1F43"]) {
            cardInfo.psamNo = tlv.value;
            if (itronLog) {
                NSLog(@"psamNo:%@",cardInfo.psamNo);
            }
        }
        //终端ID
        if ([tlv.tag isEqualToString:@"1F44"]) {
            cardInfo.TSN = tlv.value;
            if (itronLog) {
                NSLog(@"SN:%@",cardInfo.TSN);
            }
        }
        //TUSN
        if ([tlv.tag isEqualToString:@"1F45"]) {
            cardInfo.TUSN = tlv.value;
            if (itronLog) {
                NSLog(@"TUSN:%@",cardInfo.TUSN);
            }
        }
        //交易结果
        if ([tlv.tag isEqualToString:@"1F46"]) {
            cardInfo.result = tlv.value;
            if (itronLog) {
                NSLog(@"result:%@",cardInfo.result);
            }
        }
        //磁道密文
        if ([tlv.tag isEqualToString:@"1F47"]) {
            cardInfo.encryTrack = tlv.value;
            if (itronLog) {
                NSLog(@"encryTrack:%@",cardInfo.encryTrack);
            }
        }
        //55域
        if ([tlv.tag isEqualToString:@"1F48"]) {
            cardInfo.icdata = tlv.value;
            if (itronLog) {
                NSLog(@"icdata:%@",cardInfo.icdata);
            }
        }//密码
        if ([tlv.tag isEqualToString:@"1F49"]) {
            cardInfo.PIN = tlv.value;
            if (itronLog) {
                NSLog(@"PIN:%@",cardInfo.PIN);
            }
        }
        //随机数
        if ([tlv.tag isEqualToString:@"1F4A"]) {
            cardInfo.random = tlv.value;
            if (itronLog) {
                NSLog(@"random:%@",cardInfo.random);
            }
        }
        //MAC
        if ([tlv.tag isEqualToString:@"1F4C"]) {
            cardInfo.MAC = tlv.value;
            if (itronLog) {
                NSLog(@"MAC:%@",cardInfo.MAC);
            }
        }
        //PAN
        if ([tlv.tag isEqualToString:@"1F4D"]) {
            cardInfo.PAN = tlv.value;
            if (itronLog) {
                NSLog(@"PAN:%@",cardInfo.PAN);
            }
        }
        //有效期
        if ([tlv.tag isEqualToString:@"1F4E"]) {
            cardInfo.cardexpiryDate = [CompanyToolClass ascToHex:tlv.value];
            if (itronLog) {
                NSLog(@"cardexpiryDate:%@",cardInfo.cardexpiryDate);
            }
        }
        //磁道密文长度
        if ([tlv.tag isEqualToString:@"1F4F"]) {
            cardInfo.encryTrackLen = tlv.value;
            if (itronLog) {
                NSLog(@"encryTrackLen:%@",cardInfo.encryTrackLen);
            }
        }
        //磁道明文长度
        if ([tlv.tag isEqualToString:@"1F50"]) {
            cardInfo.trackLen = tlv.value;
            if (itronLog) {
                NSLog(@"trackLen:%@",cardInfo.trackLen);
            }
        }
        //卡号
        if ([tlv.tag isEqualToString:@"1F51"]) {
            cardInfo.cardNo = [CompanyToolClass ascToHex:tlv.value];
            //cardInfo.cardNo = tlv.value;
            if (itronLog) {
                NSLog(@"cardNo:%@",cardInfo.cardNo);
            }
        }
        //IC卡序列号
        if ([tlv.tag isEqualToString:@"1F52"]) {
            cardInfo.cardSerial = tlv.value;
            if (itronLog) {
                NSLog(@"cardSerial:%@",cardInfo.cardSerial);
            }
        }
        //CVM
        if ([tlv.tag isEqualToString:@"1F53"]) {
            cardInfo.CVM = tlv.value;
            if (itronLog) {
                NSLog(@"CVM:%@",cardInfo.CVM);
            }
        }
        //拒绝原因
        if ([tlv.tag isEqualToString:@"1F54"]) {
            cardInfo.deninalReason = tlv.value;
            if (itronLog) {
                NSLog(@"deninalReason:%@",cardInfo.deninalReason);
            }
        }
        //持卡人姓名
        if ([tlv.tag isEqualToString:@"1F55"]) {
            //cardInfo.cardName = tlv.value;
            cardInfo.cardName = [CompanyToolClass ascToHex:tlv.value];
            cardInfo.cardName = [self removeSpace:cardInfo.cardName];
            if (itronLog) {
                NSLog(@"cardName:%@",cardInfo.cardName);
            }
        }
        //KSN
        if ([tlv.tag isEqualToString:@"1F56"]) {
            cardInfo.KSN = tlv.value;
            if (itronLog) {
                NSLog(@"KSN:%@",cardInfo.KSN);
            }
        }
        //Kernel Type
        if ([tlv.tag isEqualToString:@"1F61"]) {
            cardInfo.kernelType = tlv.value;
            if (itronLog) {
                NSLog(@"Kernel Type:%@",cardInfo.kernelType);
            }
        }
        //Outcome Parameter Set
        if ([tlv.tag isEqualToString:@"1F62"]) {
            cardInfo.outcomeParameterSet = tlv.value;
            if (itronLog) {
                NSLog(@"Outcome Parameter Set:%@",cardInfo.outcomeParameterSet);
            }
        }
        //User Interface Request Data
        if ([tlv.tag isEqualToString:@"1F63"]) {
            cardInfo.userInterfaceRequestData = tlv.value;
            if (itronLog) {
                NSLog(@"User Interface Request Data:%@",cardInfo.userInterfaceRequestData);
            }
        }
        //Error Indication
        if ([tlv.tag isEqualToString:@"1F64"]) {
            cardInfo.errorIndication = tlv.value;
            if (itronLog) {
                NSLog(@"Error Indication:%@",cardInfo.errorIndication);
            }
        }
    }
    if (self.delegate1 && [self.delegate1 respondsToSelector:@selector(onReadCard:status:)]) {
        [self.delegate1 onReadCard:cardInfo status:0];
    }
}

#pragma mark 请求下载0501

/**
 请求下载
 
 @param type 1=远程程序下载，
 2=远程密钥下载，
 3=本地密钥下载
 4=远程kernel下载
 */
- (void)requestDown:(int)type{
    [self sendData:[NSString stringWithFormat:@"000501100001%.2x",type]];
}
-(NSString *)getTime{
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    
    [dateFormatter setDateStyle:NSDateFormatterMediumStyle];
    
    [dateFormatter setTimeStyle:NSDateFormatterShortStyle];
    
    [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss.SSS"];
    return [dateFormatter stringFromDate:[NSDate date]];
}

/**
 交互认证数据 0600
 
 @param data data
 */
- (void)confirmData:(NSString *)data{
    int len = (int)data.length/2;
    
    NSString *str = [NSString stringWithFormat:@"00060014%.2x%.2x%@",len/256,len%256,data];
    if (self.is0601 == 1) {
        str = [NSString stringWithFormat:@"00060114%.2x%.2x%@",len/256,len%256,data];
        self.is0601 = 0;
        [self sendData:str];
    }
    else{
        dispatch_sync(queue, ^{
            [NSThread sleepForTimeInterval:0.1f];
            [self sendData:str];
        });
        /*
         NSLog(@"time------%@",[self getTime]);
         [self sendData:str];
         */
    }
}

- (void)startOnlineFirmwareUpdate:(NSString *)url port:(int)port{
    queue = dispatch_queue_create("SERIALQUEUE", DISPATCH_QUEUE_SERIAL);
    [self createAppDownloadSocket:1 url:url port:port];
}
- (void)startOnlineKernelUpdate:(NSString *)url port:(int)port{
    queue = dispatch_queue_create("SERIALQUEUE", DISPATCH_QUEUE_SERIAL);
    [self createAppDownloadSocket:4 url:url port:port];
}
- (void)startOnlineKeyUpdate:(NSString *)url port:(int)port{
    queue = dispatch_queue_create("SERIALQUEUE", DISPATCH_QUEUE_SERIAL);
    [self createAppDownloadSocket:2 url:url port:port];
}
- (void)closeSocket{
    self.commandType = 0;
    [self.socket cutOffSocket];
}

//1为远程程序下载，2为远程密钥下载，3为本地密钥下载,4为远程kernel下载
- (void)createAppDownloadSocket:(int)type url:(NSString *)url port:(int)port{
    self.socket = [[MySocket alloc] init];
    self.socket.isDebug = itronLog;
    self.socket.socketHost = url;
    self.socket.socketPort = port;
    __block int connectTimes = 1;
    WS(weakSelf, self);
    //socket连接成功
    self.socket.connectSuccess = ^(){
        //第一次连接去做下面的事
        if (connectTimes == 1) {
            connectTimes = connectTimes + 1;
            //更新终端时间
            weakSelf.commandType = type;
            NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
            [formatter setDateFormat:@"YYYYMMddHHmmss"];
            NSDate *datenow = [NSDate date];
            NSString *currentTimeString = [formatter stringFromDate:datenow];
            [weakSelf setTerminalDateTime:currentTimeString];
        }
    };
    //socket断开连接
    self.socket.disConnect = ^(SocketOffline socketOffline){
        
    };
    //接收服务器发的数据
    self.socket.callBack = ^(NSString *data){
        //NSLog(@"读到数据:%@",data);
        [weakSelf confirmData:data];
    };
    [self.socket socketConnectHost];
}
-(NSString *)crc32:(NSData*)data
{
    uint32_t *table = malloc(sizeof(uint32_t) * 256);
    uint32_t crc = 0xffffffff;
    uint8_t *bytes = (uint8_t *)[data bytes];
    
    for (uint32_t i=0; i<256; i++) {
        table[i] = i;
        for (int j=0; j<8; j++) {
            if (table[i] & 1) {
                table[i] = (table[i] >>= 1) ^ 0xedb88320;
            } else {
                table[i] >>= 1;
            }
        }
    }
    
    for (int i=0; i<data.length; i++) {
        crc = (crc >> 8) ^ table[crc & 0xff ^ bytes[i]];
    }
    crc ^= 0xffffffff;
    
    free(table);
    NSString *str = [[NSString stringWithFormat:@"%.8x",crc] uppercaseString];
    return str;
}

//远程下载
- (void)firmwareUpdateRequest:(DownloadTag*)download{
    if (!download.DownloadData) {
        download.DownloadData = [CompanyToolClass hexToData:@""];
    }
    self.downloadTag = download;
    //数据分包长度
    int pageLength = 512;
    if (download.PL) {
        pageLength = [self hexToInt:[download.PL substringToIndex:2]]*256 + [self hexToInt:[download.PL substringFromIndex:2]];
    }
    NSMutableArray *mArr = [[NSMutableArray alloc] init];
    for (int i=0; i<download.DownloadData.length/pageLength; i++) {
        [mArr addObject:[download.DownloadData subdataWithRange:NSMakeRange(i*pageLength, pageLength)]];
    }
    if (download.DownloadData.length%pageLength != 0) {
        [mArr addObject:[download.DownloadData subdataWithRange:NSMakeRange(((int)download.DownloadData.length/pageLength)*pageLength, download.DownloadData.length%pageLength)]];
    }
    self.downloadDataArr = mArr;
    //DL，下载数据的长度
    NSString *str = [NSString stringWithFormat:@"444C04%.8x",(int)download.DownloadData.length];
    //CR,crc32校验
    NSString *crc32 = [self crc32:download.DownloadData];
    str = [NSString stringWithFormat:@"%@435204%@",str,crc32];
    if (download.CF) {
        str = [NSString stringWithFormat:@"%@4346%.2x%@",str,(int)download.CF.length/2,download.CF];
    }
    if (download.PL) {
        str = [NSString stringWithFormat:@"%@504C02%@",str,download.PL];
    }
    if (download.DT) {
        str = [NSString stringWithFormat:@"%@445402%@",str,download.DT];
    }
    if (download.TI) {
        str = [NSString stringWithFormat:@"%@544902%@",str,download.TI];
    }

    if (download.VR) {
        str = [NSString stringWithFormat:@"%@5652%.2x%@",str,(int)download.VR.length/2,download.VR];
    }
    if (download.NA) {
        str = [NSString stringWithFormat:@"%@4E41%.2x%@",str,(int)download.NA.length/2,download.NA];
    }
    if (download.PD) {
        str = [NSString stringWithFormat:@"%@5044%.2x%@",str,(int)download.PD.length/2,download.PD];
    }
    if (download.DO) {
        str = [NSString stringWithFormat:@"%@444F04%@",str,download.DO];
    }
    if (download.EX) {
        str = [NSString stringWithFormat:@"%@4558%.2x%@",str,(int)download.EX.length/2,download.EX];
    }
    if (download.PR) {
        str = [NSString stringWithFormat:@"%@505202%@",str,download.PR];
    }
    
    str = [[NSString stringWithFormat:@"00070120%.4x%@",(int)str.length/2,str] uppercaseString];
    [self sendData:str];
}

- (void)requestDataPage:(int)page{
    NSData *data = self.downloadDataArr[page];
    NSString *str = [NSString stringWithFormat:@"504482%.4x%@",(int)data.length,[CompanyToolClass DataToHex:data]];
    if ([self hexToInt:[self.downloadTag.CF substringWithRange:NSMakeRange(4, 2)]] & 0x10) {
        str = [NSString stringWithFormat:@"%@444F04%.8x",str,page*(int)[self.downloadDataArr[0] length]];
    }
    else{
        str = [NSString stringWithFormat:@"%@444F04%.8x",str,page];
    }
    str = [NSString stringWithFormat:@"%@435204%@",str,[self crc32:data]];
    str = [[NSString stringWithFormat:@"00070220%.4x%@",(int)str.length/2,str] uppercaseString];
    
    [self sendData:str];
}

@end
