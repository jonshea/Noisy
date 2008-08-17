/*
 * Modifications to original file:
 *     Copyright (c) 2008, Noisy Developers
 *     All rights reserved.
 *
 * Original file:
 *     NoiseGenerator.m
 *     Noise
 *     http://www.blackholemedia.com/noise/
 *
 *     Copyright (c) 2002 Aaron Sittig
 *     Copyright (c) 2001, Blackhole Media 
 *     All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *     * Neither the name of the <organization> nor the
 *       names of its contributors may be used to endorse or promote products
 *       derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY Noisy Developers ``AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL Noisy Developers BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


#import "NoiseGenerator.h"
#import <CoreAudio/AudioHardware.h>

#define kSamplesPerBuffer    (8*1024)


@interface NoiseGenerator (Internal)
- (void)initRandomEnv:(long)numRows;
- (void)createAudio;
- (void)destroyAudio;
- (void)startAudio;
- (void)stopAudio;
- (OSStatus)processAudioBufferList:(AudioBufferList *)bufferList;
- (OSStatus)defaultOutputDeviceChanged;
- (unsigned long) randomNumber;
@end


static OSStatus sWaveIOProc( AudioDeviceID inDevice, const AudioTimeStamp *ts, const AudioBufferList *inInputData,
    const AudioTimeStamp *inInputTime, AudioBufferList *outOutputData, const AudioTimeStamp *inOutputTime, void *inContext )
{
    NoiseGenerator *generator = (NoiseGenerator *)inContext;
    return [generator processAudioBufferList:outOutputData];
}


static OSStatus sDefaultOutputDeviceChanged(AudioHardwarePropertyID inPropertyID, void *inClientData)
{
    NoiseGenerator *generator = (NoiseGenerator *)inClientData;
    return [generator defaultOutputDeviceChanged];    
}


@implementation NoiseGenerator

- (id) init
{
    [super init];

    [self initRandomEnv:5];
    [self createAudio];
    
    _devRandom = fopen("/dev/random", "r");

    AudioHardwareAddPropertyListener(kAudioHardwarePropertyDefaultOutputDevice, sDefaultOutputDeviceChanged, self);

    return self;
}


- (void)dealloc
{
    fclose(_devRandom);

    [self stopAudio];
    [self destroyAudio];

    AudioHardwareRemovePropertyListener(kAudioHardwarePropertyDefaultOutputDevice, sDefaultOutputDeviceChanged);

    [super dealloc];    
}


- (void)initRandomEnv:(long)numRows
{
    int    index;
    long    pmax;
    
    _pinkIndex = 0;
    _pinkIndexMask = (1 << numRows) - 1;
    _type = NoNoiseType;
    _volume = 0.33;
    
    // Calculate max possible signed random value. extra 1 for white noise always added
    pmax = (numRows + 1) * (1 << (kPinkRandomBits-1));
    _pinkScalar = 1.0f / pmax;
    
    // Initialize rows
    for( index = 0; index < numRows; index++ )
        _pinkRows[index] = 0;
    _pinkRunningSum = 0;
}


- (void) createAudio
{
    OSStatus    status;
    UInt32      theSize;
    UInt32      bufferByteCount;

    theSize = sizeof(_outputDevID);
    status = AudioHardwareGetProperty( kAudioHardwarePropertyDefaultOutputDevice, &theSize, &_outputDevID );
    if( status ){ NSLog(@"NoiseGenerator::AudioHardwareGetProperty status %d", status ); return; }
    
    theSize = sizeof(bufferByteCount);
    bufferByteCount = kSamplesPerBuffer * sizeof(float);
    status = AudioDeviceSetProperty( _outputDevID, NULL, 0, NO, kAudioDevicePropertyBufferSize, theSize, &bufferByteCount );
    if( status ){ NSLog(@"NoiseGenerator::AudioDeviceSetProperty setting buffer size status %d", status); return; }

    status = AudioDeviceCreateIOProcID( _outputDevID, sWaveIOProc, self, &_outputProcID );
    if( status ){ NSLog(@"NoiseGenerator::AudioDeviceCreateIOProcID status %d", status ); return; }
}


- (void) destroyAudio
{
    AudioDeviceDestroyIOProcID(_outputDevID, _outputProcID);
    _outputProcID = 0;
}


- (void) startAudio
{
    OSStatus    status;
    
    status = AudioDeviceStart( _outputDevID, sWaveIOProc );
    if( status ) NSLog(@"NoiseGenerator::AudioDeviceStart status %d", status );
}


- (void) stopAudio
{
    OSStatus    status;
    
    status = AudioDeviceStop( _outputDevID, sWaveIOProc );
    if( status ) NSLog(@"NoiseGenerator::AudioDeviceStop status %d", status );
}


- (OSStatus) processAudioBufferList:(AudioBufferList *)bufferList
{
    float     *buffer = bufferList->mBuffers[0].mData;
    UInt32     bufferSize = bufferList->mBuffers[0].mDataByteSize;
    UInt32     numChannels = bufferList->mBuffers[0].mNumberChannels;
    UInt32     bufferSamples = bufferSize / 4;
    UInt32     bufferFrames = bufferSamples / numChannels;
    UInt32     channel;
    float      sample;
    UInt32     sampleIndex;
    
    // White Noise
    if( _type == WhiteNoiseType )
    {
        for( sampleIndex = 0; sampleIndex < bufferFrames; sampleIndex++ )
        {
            sample = ((long)[self randomNumber]) * (float)(1.0f / 0x7FFFFFFF) * _volume;
            for( channel = 0; channel < numChannels; channel++ )
                *buffer++ = sample;
        }
        return kAudioHardwareNoError;
    }
    
    // Pink Noise
    for( sampleIndex = 0; sampleIndex < bufferFrames; sampleIndex++ )
    {
        long    newRandom;
        long    sum;
        
        // Increment and mask index
        _pinkIndex = (_pinkIndex + 1) & _pinkIndexMask;
        
        // If index is zero, don't update any random values
        if( _pinkIndex )
        {
            int        numZeros = 0;
            int        n = _pinkIndex;
            
            // Determine how many trailing zeros in pinkIndex
            // this will hang if n == 0 so test first
            while( (n & 1) == 0 )
            {
                n = n >> 1;
                numZeros++;
            }
            
            // Replace the indexed rows random value
            // Subtract and add back to pinkRunningSum instead of adding all 
            // the random values together. only one changes each time
            _pinkRunningSum -= _pinkRows[numZeros];
            newRandom = ((long)[self randomNumber]) >> kPinkRandomShift;
            _pinkRunningSum += newRandom;
            _pinkRows[numZeros] = newRandom;
        }
        
        // Add extra white noise value
        newRandom = ((long)[self randomNumber]) >> kPinkRandomShift;
        sum = _pinkRunningSum + newRandom;
        
        // Scale to range of -1.0 to 0.999 and factor in volume
        sample = _pinkScalar * sum * _volume;
        
        // Write to all channels
        for( channel = 0; channel < numChannels; channel++ )
            *buffer++ = sample;
    }
    
    return kAudioHardwareNoError;
}


- (OSStatus) defaultOutputDeviceChanged
{
    [self stopAudio];
    [self destroyAudio];
    [self createAudio];
    
    if (_type != NoNoiseType) [self startAudio];

    return kAudioHardwareNoError;
}


- (unsigned long) randomNumber
{
    long randomNumber;
    fread(&randomNumber, sizeof(long), 1, _devRandom);
    return randomNumber;
}


- (void)setVolume:(double)volume
{
    // Set the volume along a parabolic curve
    _volume = volume * volume;
}


- (void) setType:(NoiseType)newType
{
    NoiseType oldType = _type;

    if (oldType != newType) {
        _type = newType;
        if (newType == NoNoiseType) [self stopAudio];
        if (oldType == NoNoiseType) [self startAudio];
    }
}


- (double) volume
{
    return _volume;
}


- (NoiseType) type
{
    return _type;
}


@end
