//
//  CoreAudioNBandEQ.h
//  AudioBandEQByCoreAudio
//
//  Created by ren zhicheng on 2017/6/13.
//  Copyright © 2017年 renzhicheng. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AudioUnit/AudioUnit.h>

#define NUM_FILES 2

typedef struct {
    BOOL isStrereo;
    UInt32 frameCount;
    UInt32 sampleNumber;
    SInt32 *audioDataLeft;
    SInt32 *audioDataRight;
    
} soundStruct, *soundStructPrt;

@interface CoreAudioNBandEQ : NSObject <AVAudioSessionDelegate>{
    CFURLRef audioFileURLArray[NUM_FILES];
    soundStruct soundStructArray[NUM_FILES];
    AudioStreamBasicDescription stereoStreamFormat;
    AudioStreamBasicDescription monoStreamFormat;
    AudioStreamBasicDescription eqEffectForamt;
    AUGraph processGraph;
    
    AUNode iONode;
    AUNode mixerNode;
    AUNode nBandEqNode;
    AUNode filePlayerNode;
    
    int inputChannels;
}


//CheckError method
static inline BOOL CheckError(OSStatus error, const char *operation, const char* file, int line);
@property (readwrite)Float64 graphSampleRate;
@end
