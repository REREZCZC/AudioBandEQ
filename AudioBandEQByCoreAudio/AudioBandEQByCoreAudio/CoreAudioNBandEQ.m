//
//  CoreAudioNBandEQ.m
//  AudioBandEQByCoreAudio
//
//  Created by ren zhicheng on 2017/6/13.
//  Copyright © 2017年 renzhicheng. All rights reserved.
//

#import "CoreAudioNBandEQ.h"

static OSStatus inputRenderCallback(
                                    void *inRefCon,
                                    AudioUnitRenderActionFlags *ioActionFlags,
                                    const AudioTimeStamp *inTimeStamp,
                                    UInt32 inBusNumber,
                                    UInt32 inNumberFrames,
                                    AudioBufferList *ioData
                                    ) {
    return noErr;
}

OSStatus micInputRenderCallback(
                                void *inRefCon,
                                AudioUnitRenderActionFlags *ioActionFlags,
                                const AudioTimeStamp *inTimeStamp,
                                UInt32 inBusNumber,
                                UInt32 inNumberFrames,
                                AudioBufferList *ioData
                                ){
    return noErr;
    
}


@interface CoreAudioNBandEQ() {
    AUGraph graph;
    AudioUnit eqUnit;
    AudioUnit playUnit;
    AudioUnit ioUnit;
    AudioUnit mixerUnit;
    AudioFileID AudioFileID;
    
    BOOL inputDeviceIsAvailable;
}
@end

@implementation CoreAudioNBandEQ


#define CheckError(result,operation) (_CheckError((result),(operation),strrchr(__FILE__, '/')+1,__LINE__))
static inline BOOL _CheckError(OSStatus error, const char *operation, const char* file, int line) {
    if (error != noErr) {
        int fourCC = CFSwapInt32HostToBig(error);
        if (isascii(((char*)&fourCC)[0]) && isascii(((char*)&fourCC)[1]) && isascii(((char*)&fourCC)[2])) {
            NSLog(@"%s:%d: %s: '%4.4s' (%d)",file, line, operation, (char*)&fourCC,(int)error);
        }else {
            NSLog(@"%s:%d: %s: %d", file, line, operation, (int)error);
        }
    }
    return YES;
}


- (instancetype)init {
    if (self = [super init]) {
        [self setupSession];
        [self prepareMonoStreamFormat];
        [self preparaStereoStreamFormat];
        [self getAudioFile];
        [self readAudioFileIntoMemery];
        [self setupAndInitializeAudioGraph];
    }
    return self;
}

- (void)setupSession {
    AVAudioSession *mySession = [AVAudioSession sharedInstance];
    mySession.delegate = self;
    
    NSError *sessionError = nil;
    [mySession setCategory:AVAudioSessionCategoryPlayAndRecord error:&sessionError];
    
    inputDeviceIsAvailable = [mySession inputIsAvailable];
    
    if (inputDeviceIsAvailable) {
        NSLog(@"Input device is available");
    }else {
        NSLog(@"Input device not available");
        [mySession setCategory:AVAudioSessionCategoryPlayback error:&sessionError];
    }
    
    if (sessionError != nil) {
        NSLog(@"Error set audio session category");
    }
    
    self.graphSampleRate = 44100.0;
    
    [mySession setPreferredSampleRate:self.graphSampleRate error:&sessionError];
    if (sessionError != nil) {
        NSLog(@"Error set preferrd hardware sample rate");
    }
    
    Float32 currentBufferDuraiotn = (Float32)(1024/self.graphSampleRate);
    UInt32 size = sizeof(currentBufferDuraiotn);
    AudioSessionSetProperty(kAudioSessionProperty_CurrentHardwareIOBufferDuration, sizeof(currentBufferDuraiotn), &currentBufferDuraiotn);
    
    [mySession setActive:YES error:&sessionError];
    
    self.graphSampleRate = [mySession currentHardwareSampleRate];
    NSLog(@"Actual sample rate is %f",self.graphSampleRate);
    
    NSInteger numberOfChannels = [mySession currentHardwareInputNumberOfChannels];
    inputChannels = numberOfChannels;
    return;
    
    
}

- (void)prepareMonoStreamFormat {
    size_t bytesPerSample = sizeof(SInt32);
    monoStreamFormat.mFormatID = kAudioFormatLinearPCM;
    monoStreamFormat.mFormatFlags = kAudioFormatFlagsAudioUnitCanonical;
    monoStreamFormat.mBytesPerPacket = (UInt32)bytesPerSample;
    monoStreamFormat.mFramesPerPacket = 1;
    monoStreamFormat.mBytesPerFrame = (UInt32)bytesPerSample;
    monoStreamFormat.mChannelsPerFrame = 1;
    monoStreamFormat.mBitsPerChannel = 8 * (UInt32)bytesPerSample;
    monoStreamFormat.mSampleRate = self.graphSampleRate;
}

- (void)preparaStereoStreamFormat {
    size_t bytesPerSample = sizeof(SInt32);
    
    stereoStreamFormat.mFormatID          = kAudioFormatLinearPCM;
    stereoStreamFormat.mFormatFlags       = kAudioFormatFlagsAudioUnitCanonical;
    stereoStreamFormat.mBytesPerPacket    = (UInt32)bytesPerSample;
    stereoStreamFormat.mFramesPerPacket   = 1;
    stereoStreamFormat.mBytesPerFrame     = (UInt32)bytesPerSample;
    stereoStreamFormat.mChannelsPerFrame  = 2;                    // 2 indicates stereo
    stereoStreamFormat.mBitsPerChannel    = 8 * (UInt32)bytesPerSample;
    stereoStreamFormat.mSampleRate        = self.graphSampleRate;
}

//获取音频文件的 URL
- (void)getAudioFile {
    NSURL *audioFileURL = [[NSBundle mainBundle] URLForResource:@"file" withExtension:@"wav"];
    NSURL *audioFileURL2 = [[NSBundle mainBundle] URLForResource:@"file2" withExtension:@"wav"];
    
    audioFileURLArray[0] = (CFURLRef)[audioFileURL retain];
    audioFileURLArray[1] = (CFURLRef)[audioFileURL2 retain];
}


- (void)readAudioFileIntoMemery {
    
    for (int fileIndex = 0; fileIndex < NUM_FILES; ++fileIndex) {
        //instantiate an audio file object.
        ExtAudioFileRef audioFileObject = 0;
        
        //open an audio file with audio file object.
        OSStatus result = ExtAudioFileOpenURL(audioFileURLArray[fileIndex], &audioFileObject);
        CheckError(result, "open audio file url failed");
        
        //get audio file length in frames
        UInt64 totalFramesInFile = 0;
        UInt32 frameLengthPropertySize = sizeof(totalFramesInFile);
        result = ExtAudioFileGetProperty(audioFileObject,
                                         kExtAudioFileProperty_FileLengthFrames,
                                         &frameLengthPropertySize,
                                         &totalFramesInFile);
        CheckError(result, "get audio file length failed");
        soundStructArray[fileIndex].frameCount = (UInt32)totalFramesInFile;
        
        AudioStreamBasicDescription fileAudioFormat ={0};
        UInt32 formatPropertySize = sizeof(fileAudioFormat);
        
        result = ExtAudioFileGetProperty(audioFileObject,
                                         kExtAudioFileProperty_FileDataFormat,
                                         &formatPropertySize,
                                         &fileAudioFormat);
        CheckError(result, "get audio file format failed");
        UInt32 channelCount = fileAudioFormat.mChannelsPerFrame;
        
        //Allocate memory for soundStructArray isntance to hold left and right channel.
        soundStructArray[fileIndex].audioDataLeft = calloc(totalFramesInFile, sizeof(SInt32));
        
        AudioStreamBasicDescription importFormat = {0};
        //right data
        if (2 == channelCount) {
            soundStructArray[fileIndex].isStrereo = YES;
            //audio file si stereo, need allocate memory to hold right channel audio data.
            soundStructArray[fileIndex].audioDataRight = calloc(totalFramesInFile, sizeof(SInt32));
            importFormat = stereoStreamFormat;
        }else if (1 == channelCount) {
            soundStructArray[fileIndex].isStrereo = NO;
            importFormat = monoStreamFormat;
        }else {
            NSLog(@"Audio file format not available!!");
            ExtAudioFileDispose(audioFileObject);
            return;
        }
        
        //
        result = ExtAudioFileSetProperty(audioFileObject,
                                         kExtAudioFileProperty_ClientDataFormat,
                                         sizeof(importFormat),
                                         &importFormat);
        
        CheckError(result, "Set client format failed");
        
        //Set AudioBufferList struct
        AudioBufferList *bufferList;
        bufferList = (AudioBufferList *)malloc(sizeof(AudioBufferList) + sizeof(AudioBuffer) * channelCount - 1);
        if (NULL == bufferList) {
            NSLog(@"malloc bufferlist failed");
        }
        //set the mNumberBuffers member
        bufferList->mNumberBuffers = channelCount;
        //set the mNumberBuffers member to 0
        AudioBuffer emptyBuffer ={0};
        size_t arrayIndex;
        for (arrayIndex = 0; arrayIndex < channelCount; arrayIndex++) {
            bufferList->mBuffers[arrayIndex] = emptyBuffer;
        }
        
        //set left and right buffer list
        bufferList->mBuffers[0].mNumberChannels = 1;
        bufferList->mBuffers[0].mDataByteSize = (UInt32)totalFramesInFile * sizeof(SInt32);
        bufferList->mBuffers[0].mData = soundStructArray[fileIndex].audioDataLeft;
        
        if (2 == channelCount) {
            bufferList->mBuffers[1].mNumberChannels = 1;
            bufferList->mBuffers[1].mDataByteSize = (UInt32)totalFramesInFile * sizeof(SInt32);
            bufferList->mBuffers[1].mData = soundStructArray[fileIndex].audioDataRight;
        }
        
        //read audio file into buffer
        UInt32 numberOfpacketsToRead = (UInt32)totalFramesInFile;
        result = ExtAudioFileRead(audioFileObject, &numberOfpacketsToRead, bufferList);
        free(bufferList);
        if (noErr != result) {
            NSLog(@"Read file to memory failed");
            free(soundStructArray[fileIndex].audioDataLeft);
            soundStructArray[fileIndex].audioDataLeft = 0;
            
            if (2 == channelCount) {
                free(soundStructArray[fileIndex].audioDataRight);
                soundStructArray[fileIndex].audioDataRight = 0;
            }
            ExtAudioFileDispose(audioFileObject);
            return;
        }
        
        NSLog(@"Finished reading file.");
        soundStructArray[fileIndex].sampleNumber = 0;
        ExtAudioFileDispose(audioFileObject);
    }
    
}

OSStatus REAUGraphaddNode(OSType inComponentType, OSType inComponentSubType, AUGraph inGraph, AUNode *outNode) {
    AudioComponentDescription desc;
    desc.componentType = inComponentType;
    desc.componentSubType = inComponentSubType;
    desc.componentFlags = 0;
    desc.componentFlagsMask = 0;
    desc.componentManufacturer = kAudioUnitManufacturer_Apple;
    return AUGraphAddNode(inGraph, &desc, outNode);

}

- (void)setupAndInitializeAudioGraph {
    NSLog(@"Configuration audio graph");
    
    OSStatus result = noErr;
    
    UInt16 busNumber;
    
    //setup audio graph
    [self setupAudioGraph];
    
    //open audio graph
    result = AUGraphOpen(processGraph);
    CheckError(result, "open audio graph failed");
    
    //obtain unit from node;
    result = AUGraphNodeInfo(processGraph,
                             iONode,
                             NULL,
                             &ioUnit);
    CheckError(result, "get iounit from node");
    
    //set I/O unit format by with Mono format or stereo format.
    if (inputDeviceIsAvailable) {
        AudioUnitElement ioUnitInputBus = 1;
        UInt32 enableInput = 1;
        AudioUnitSetProperty(ioUnit,
                             kAudioOutputUnitProperty_EnableIO,
                             kAudioUnitScope_Input,
                             ioUnitInputBus,
                             &enableInput,
                             sizeof(enableInput)
                             );
        
        
        if (inputChannels == 1) {
            NSLog(@"set mono format for I/O unit input bus's output scope");
            result = AudioUnitSetProperty(ioUnit,
                                          kAudioUnitProperty_StreamFormat,
                                          kAudioUnitScope_Output,
                                          ioUnitInputBus,
                                          &monoStreamFormat,
                                          sizeof(monoStreamFormat));
            CheckError(result, "set mono foramt for iounit");
        }else {
            NSLog(@"set stereo format for I/O unit input bus's ouput scope");
            result = AudioUnitSetProperty(ioUnit,
                                          kAudioUnitProperty_StreamFormat,
                                          kAudioUnitScope_Output,
                                          ioUnitInputBus,
                                          &stereoStreamFormat,
                                          sizeof(stereoStreamFormat));
            CheckError(result, "set stereo format for iounit");
        }
    }
    
    
    //obtain the mixer unit instace.
    result = AUGraphNodeInfo(processGraph,
                             mixerNode,
                             NULL,
                             &mixerUnit);
    CheckError(result, "get mixer unit failed");
    //mixer unit setup
    UInt32 busCount = 3; //microPhone, two file player
    UInt32 file_first_bus = 0;
    UInt32 file_second_bus = 1;
    UInt32 mic_bus = 2;
    
    result = AudioUnitSetProperty(mixerUnit,
                                  kAudioUnitProperty_ElementCount,
                                  kAudioUnitScope_Input,
                                  0,
                                  &busCount,
                                  sizeof(busCount));
    CheckError(result, "set mixer unit bus count failed");
    
    //set max frames per slice
    UInt32 maximumFramesPerSlice = 4096;
    result = AudioUnitSetProperty(mixerUnit,
                                  kAudioUnitProperty_MaximumFramesPerSlice,
                                  kAudioUnitScope_Global,
                                  0,
                                  &maximumFramesPerSlice,
                                  sizeof(maximumFramesPerSlice));
    CheckError(result, "set max frames per slice failed.");
    
    //number of file to play
    UInt16 fileCount = 2;
    //set file bus number to 0 and 1 on mixer unit.
    for (UInt16 busNumber = 0; busNumber < fileCount; ++busNumber) {
        //set input render callback
        AURenderCallbackStruct inputCallbackStruct;
        inputCallbackStruct.inputProc = &inputRenderCallback;
        inputCallbackStruct.inputProcRefCon = soundStructArray;
        
        result = AUGraphSetNodeInputCallback(processGraph,
                                             mixerNode,
                                             busNumber,
                                             &inputCallbackStruct
                                             );
    }
    CheckError(result, "set input render callback failed");
    
    //set input callbck depend on how many input channel
    if (inputDeviceIsAvailable) {
        //mic input channel bus index on mixer unint.
        UInt16 busNumber = 2;
        //set callback
        AURenderCallbackStruct micInputCallbackstruct;
        micInputCallbackstruct.inputProc = micInputRenderCallback;
        micInputCallbackstruct.inputProcRefCon = self;
        
        result = AUGraphSetNodeInputCallback(processGraph,
                                             mixerNode,
                                             busNumber,
                                             &micInputCallbackstruct);
        CheckError(result, "set mic input render callback failed");
    }
    
    //set streamFormat for each file.
    result = AudioUnitSetProperty(mixerUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Input,
                                  file_first_bus,
                                  &stereoStreamFormat,
                                  sizeof(stereoStreamFormat));
    CheckError(result, "set first file format failed");
    
    
    result = AudioUnitSetProperty(mixerUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Input,
                                  file_second_bus,
                                  &stereoStreamFormat,
                                  sizeof(stereoStreamFormat));
    CheckError(result, "set second file format failed ");
    
    
    //set mic input channel foramt for mono or stereo.
    //mono input, one channel
    if (inputChannels == 1) {
        NSLog(@"set mono format for mixer unit bus index 2");
        result = AudioUnitSetProperty(mixerUnit,
                                      kAudioUnitProperty_StreamFormat,
                                      kAudioUnitScope_Input,
                                      mic_bus,
                                      &monoStreamFormat,
                                      sizeof(monoStreamFormat));
        CheckError(result, "set mic inptut format mono failed");
    }else if(inputChannels > 1) {
        NSLog(@"set stereo format for mixer unit bus index 2");
        result = AudioUnitSetProperty(mixerUnit,
                                      kAudioUnitProperty_StreamFormat,
                                      kAudioUnitScope_Input,
                                      mic_bus,
                                      &stereoStreamFormat,
                                      sizeof(stereoStreamFormat));
        CheckError(result, "set mic inptut format stereo failed");
    }
    
    //get nBandEQ effect unit.
    result = AUGraphNodeInfo(processGraph,
                             nBandEqNode,
                             NULL,
                             &eqUnit);
    CheckError(result, "get eq unit failed ");
    
    //get stream format from equnit and make sure sampelRate is correct
    UInt32 eqASBDSize = sizeof(eqEffectForamt);
    memset(&eqEffectForamt, 0, sizeof(eqEffectForamt));
    result = AudioUnitGetProperty(eqUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &eqEffectForamt, &eqASBDSize);
    CheckError(result, "get eq unit format failed");
    //set prefer samplerate for equnit.
    eqEffectForamt.mSampleRate = self.graphSampleRate;
    NSLog(@"eq unit sampel:%f",eqEffectForamt.mSampleRate);
    
    //reset eq unit foramt
    result = AudioUnitSetProperty(eqUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &eqEffectForamt, sizeof(eqEffectForamt));
    CheckError(result, "reset equnit input format failed");
    
    //If there is no equnit, set samplerate on the mixer output scope
    result = AudioUnitSetProperty(eqUnit, kAudioUnitProperty_SampleRate, kAudioUnitScope_Output, 0, &_graphSampleRate, sizeof(_graphSampleRate));
    CheckError(result, "set equnit output format sampelrate failed ");
    
    //set mixer unit output format.
    //make sure mixer output format and equnit input format are the same
    result = AudioUnitSetProperty(mixerUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &eqEffectForamt, sizeof(eqEffectForamt));
    
    CheckError(result, "set mixer output formate failed");
    
    [self connectAudioGraphWithNode];
}

- (void)connectAudioGraphWithNode {
    OSStatus result = noErr;
    
    //connect mixerNode  to eqNode/
    result = AUGraphConnectNodeInput(processGraph, mixerNode, 0, nBandEqNode, 0);
    CheckError(result, "connect mixer and eq failed");
    
    //connect eqNode to ioNode
    result = AUGraphConnectNodeInput(processGraph, nBandEqNode, 0, iONode, 0);
    CheckError(result, "connect eq and io failed");
    
    
    
}

- (void)setupAudioGraph {
    OSStatus result = noErr;
    
    //Create new audio graph
    result = NewAUGraph(&processGraph);
    CheckError(result, "Create new audio graph");
    
    //Specify the AduioComponentDescription for AudioUnit.
    
    //I/O unit
    AudioComponentDescription iOUnitDescription;
    iOUnitDescription.componentType = kAudioUnitType_Output;
    iOUnitDescription.componentSubType = kAudioUnitSubType_RemoteIO;
    iOUnitDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
    iOUnitDescription.componentFlags = 0;
    iOUnitDescription.componentFlagsMask = 0;
    
    //File Player unit
//    AudioComponentDescription filePlayerUnitDescription;
//    filePlayerUnitDescription.componentType = kAudioUnitType_Generator;
//    filePlayerUnitDescription.componentSubType = kAudioUnitSubType_AudioFilePlayer;
//    filePlayerUnitDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
    
    //MultiChannel mixer unit
    AudioComponentDescription mixerUnitDescription;
    mixerUnitDescription.componentType = kAudioUnitType_Mixer;
    mixerUnitDescription.componentSubType = kAudioUnitSubType_MultiChannelMixer;
    mixerUnitDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
    mixerUnitDescription.componentFlags = 0;
    mixerUnitDescription.componentFlagsMask = 0;
    
    //EQ effect unit
    AudioComponentDescription nBandEQEffectUnitDescription;
    nBandEQEffectUnitDescription.componentType = kAudioUnitType_Effect;
    nBandEQEffectUnitDescription.componentSubType = kAudioUnitSubType_NBandEQ;
    nBandEQEffectUnitDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
    
    //Add node
    result = AUGraphAddNode(processGraph,
                            &iOUnitDescription,
                            &iONode);
    CheckError(result, "add iONode to graph");
    
    //mixer node
    result = AUGraphAddNode(processGraph,
                            &mixerUnitDescription,
                            &mixerNode);
    
    CheckError(result, "add mixerNode to graph");
    
    //eq node
    result = AUGraphAddNode(processGraph,
                            &nBandEQEffectUnitDescription,
                            &nBandEqNode);
    
    CheckError(result, "add nBandEQ to graph");
    
    //file player node
//    result = AUGraphAddNode(processGraph,
//                            &filePlayerUnitDescription,
//                            &filePlayerNode);
    
    CheckError(result, "add filePlayer to graph");
}
































@end
