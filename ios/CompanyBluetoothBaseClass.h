//
//  ItronBaseClass.h
//  ItronLibrary
//
//  Created by 攀杨 on 2018/8/6.
//  Copyright © 2018年 攀杨. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CompanyDelegate.h"
#import "CompanyClass.h"


@interface CompanyBluetoothBaseClass : NSObject

+ (CompanyBluetoothBaseClass *)getInstance;
@property (nonatomic,weak)id<CompanyDelegate>delegate;
@property (nonatomic,assign)BOOL debug;



@property (nonatomic,assign)int deviceType;

#pragma Bluetooth

/**
 bluetooth connect state
 */
- (BOOL)isConnected;
/**
 search bluetooth

 @param delegate delegate
 @param timeout timeout
 */
- (void)searchDevices:(id<CompanyDelegate>)delegate timeout:(int)timeout;

/**
 stop search bluetooth
 */
- (void)stopSearching;

/**
 connect bluetooth by UUID

 @param UUIDString UUID of peripheral
 @param cb delegate
 @param timeout timeout
 */
- (void)openDevice:(NSString *)UUIDString cbDelegate:(id<CompanyDelegate>)cb timeout:(int)timeout;

/**
 connect bluetooth by peripheral

 @param peripheral peripheral
 @param cb delegate
 @param timeout timeout
 */
- (void)openDevice:(CBPeripheral *)peripheral delegate:(id<CompanyDelegate>)cb timeout:(int)timeout;

/**
 disconnect bluetooth
 */
-(void)closeDevice;
#pragma mark sendCommand
/**
 get device information
 */
- (void)getTerminalInfo;

/**
 Set terminal automatic shutdown time function

 @param time second
 */
- (void)setAutomaticShutdown:(int)time;


/**
 Update terminal time function

 @param datetime yyyyMMddHHmmss
 */
- (void)setTerminalDateTime:(NSString *)datetime;

/**
 get terminal time
 */
- (void)getTerminalDateTime;


/**
Download terminal communication key

 @param publickey RSA public key
 */
- (void)downloadRSApublicKey:(NSString *)publickey;


/**
 Set Card Acceptor Identification Code and Terminal Identification

 @param acceptor Acceptor Identification Cod
 @param terminal Terminal Identification
 */
-(void)setAcceptorTerminalIdentification:(NSString*)acceptor Terminal:(NSString *)terminal;


/**
 return Acceptor Identification Code
 */
- (void)getAcceptorIdentification;


/**
 return Terminal Identification
 */
- (void)getTerminalIdentification;

/**
 Stop current operation
 */
- (void)stopTrade;


/**
 calculate MAC

 @param data mab
 */
- (void)calculateMac:(NSString *)data;


/**
 download Main Key

 @param index Main Key index
 @param tmk Main key
 */
- (void)downloadMainKey:(int)index tmk:(NSString *)tmk;


/**
 doenload Work key

 @param index main key index
 @param PINkey PINkey
 @param MACkey MACkey
 @param DESkey DESkey
 */
- (void)downloadWorkKey:(int)index PINkey:(NSString *)PINkey MACkey:(NSString *)MACkey DESkey:(NSString *)DESkey;


/**
 download AID Parameters

 @param aIDParameters aIDParameters
 */
- (void)downloadAIDParameters:(AIDParameters *)aIDParameters;


/**
 clear Terminal AID Parameters
 */
- (void)clearAIDParameters;


/**
 download CA Public Key

 @param caPublicKey caPublicKey
 */
- (void)downloadPublicKey:(CAPublicKey  *)caPublicKey;


/**
 clear Terminal Public Key
 */
- (void)clearPublicKey;


/**
 startEmvProcess

 @param timeout Operation timeout
 @param tradeData tradeData
 */
- (void)startEmvProcess:(int)timeout tradeData:(TradeData*)tradeData;


/**
 pin entry
 @param pin pin
 */
- (void)PINEntry:(NSString *)pin;


/**
 Send transaction results from the processor back to EMVSwipe
 
 @param data icData
 */
- (void)sendOnlineProcessResult:(NSString*)data;

/**
 begin NFC/IC

 @param type 0 is IC,1 is NFC
 */
- (void)powerOnAPDU:(int)type timeout:(int)timeout;


/**
 stop NFC/IC
 */
- (void)powerOffAPDU;


/**
 NFC/IC apdu

 @param type 0 is IC,1 is NFC
 @param apduData apdu data
 */
- (void)sendApdu:(int)type apdu:(NSArray*)apduData timeout:(int)timeout;


/**
 get battery power
 */
- (void)getBatteryPower;


/**
 shut down
 */
- (void)shutDown;

/**
 get sdk version
 */
- (NSString *)getSDKVersion;

- (void)startOnlineFirmwareUpdate:(NSString *)url port:(int)port;


- (void)startOnlineKernelUpdate:(NSString *)url port:(int)port;


- (void)startOnlineKeyUpdate:(NSString *)url port:(int)port;


- (void)firmwareUpdateRequest:(DownloadTag*)download;


- (void)receiveData:(NSData *)data;



@end
