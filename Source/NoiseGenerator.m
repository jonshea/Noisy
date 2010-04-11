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


@interface NoiseGenerator (Internal)
- (void)initRandomEnv:(long)numRows;
- (void)createAudio;
- (void)destroyAudio;
- (void)startAudio;
- (void)stopAudio;
- (void)_processBuffer:(AudioQueueBufferRef)buffer;
- (OSStatus)defaultOutputDeviceChanged;
@end


static unsigned long sGetNextRandomNumber()
{
	static unsigned long randSeed = 22222;  /* Change this for different random sequences. */
	randSeed = (randSeed * 196314165) + 907633515;
	return randSeed;
}


static void sAudioQueueOutputCallback(void *inUserData, AudioQueueRef inAQ, AudioQueueBufferRef inBuffer)
{
    NoiseGenerator *generator = (NoiseGenerator *)inUserData;
    [generator _processBuffer:inBuffer];
}


static OSStatus sDefaultOutputDeviceChanged(AudioHardwarePropertyID inPropertyID, void *inClientData)
{
    NoiseGenerator *generator = (NoiseGenerator *)inClientData;
    return [generator defaultOutputDeviceChanged];    
}


@implementation NoiseGenerator

- (id) init
{
    if (self = [super init]) {
        [self initRandomEnv:5];
    }

    return self;
}


- (void)dealloc
{
    [self stopAudio];
    [super dealloc];    
}


- (void)initRandomEnv:(long)numRows
{
    _pinkIndex = 0;
    _pinkIndexMask = (1 << numRows) - 1;
    _type = NoNoiseType;
    _volume = 0.33;
    
    // Calculate max possible signed random value. extra 1 for white noise always added
    long pmax = (numRows + 1) * (1 << (kPinkRandomBits-1));
    _pinkScalar = 1.0f / pmax;
    
    // Initialize rows
    int index;
    for (index = 0; index < numRows; index++) {
        _pinkRows[index] = 0;
    }

    _pinkRunningSum = 0;
}


- (void) startAudio
{
    if (!_isPlaying) {
        AudioStreamBasicDescription description;

        description.mSampleRate       = 44100;
        description.mFormatID         = kAudioFormatLinearPCM; 
        description.mFormatFlags      = kAudioFormatFlagIsFloat;
        description.mBytesPerPacket   = sizeof(float);
        description.mFramesPerPacket  = 1;
        description.mBytesPerFrame    = sizeof(float);
        description.mChannelsPerFrame = 1;
        description.mBitsPerChannel   = sizeof(float) * 8;

        _isPlaying = YES;
        OSStatus err = AudioQueueNewOutput(&description, sAudioQueueOutputCallback, self, CFRunLoopGetCurrent(), kCFRunLoopCommonModes, 0, &_queue);
        if (err) { NSLog(@"AudioQueueNewOutput returned %d", err); return; }

        NSUInteger i;
        for (i = 0; i < kNumberOfBuffers; i++) {
            err = AudioQueueAllocateBuffer(_queue, kBytesPerBuffer, &_buffer[i]);
            if (err) { NSLog(@"AudioQueueAllocateBuffer returned %d", err); return; }

            [self _processBuffer:_buffer[i]];
        }

        err = AudioQueueStart(_queue, NULL);
        if (err) { NSLog(@"AudioQueueStart returned %d", err); return; }
    }
}


- (void) stopAudio
{
    if (_isPlaying) {
        AudioQueueDispose(_queue, YES);
        _isPlaying = NO;
    }
}


- (void) _processBuffer:(AudioQueueBufferRef)audioQueueBuffer
{
    UInt32  bufferSize   = audioQueueBuffer->mAudioDataBytesCapacity;
    UInt32  bufferFrames = bufferSize / sizeof(float);
    float  *buffer       = (float *)audioQueueBuffer->mAudioData;
    float   sample;
    UInt32  i;
    
    // White Noise
    if (_type == WhiteNoiseType) {
        for (i = 0; i < bufferFrames; i++) {
            sample = ((long)sGetNextRandomNumber()) * (float)(1.0f / 0x7FFFFFFF) * _volume;
            *buffer++ = sample;
        }

    // Pink Noise
    } else {
        for (i = 0; i < bufferFrames; i++) {
            // Increment and mask index
            _pinkIndex = (_pinkIndex + 1) & _pinkIndexMask;
            
            // If index is zero, don't update any random values
            if (_pinkIndex) {
                int numZeros = 0;
                int n = _pinkIndex;
                
                // Determine how many trailing zeros in pinkIndex
                // this will hang if n == 0 so test first
                while((n & 1) == 0) {
                    n = n >> 1;
                    numZeros++;
                }
                
                // Replace the indexed rows random value
                // Subtract and add back to pinkRunningSum instead of adding all 
                // the random values together. only one changes each time
                _pinkRunningSum -= _pinkRows[numZeros];
                long newRandom = ((long)sGetNextRandomNumber()) >> kPinkRandomShift;
                _pinkRunningSum += newRandom;
                _pinkRows[numZeros] = newRandom;
            }
            
            // Add extra white noise value
            long newRandom = ((long)sGetNextRandomNumber()) >> kPinkRandomShift;
            long sum = _pinkRunningSum + newRandom;
            
            // Scale to range of -1.0 to 0.999 and factor in volume
            sample = _pinkScalar * sum * _volume;

            // Write to all channels
            *buffer++ = sample;
        }
    }

    audioQueueBuffer->mAudioDataByteSize = (i * sizeof(float));
    AudioQueueEnqueueBuffer(_queue, audioQueueBuffer, 0, NULL);
}


- (OSStatus) defaultOutputDeviceChanged
{
    [self stopAudio];
    if (_type != NoNoiseType) [self startAudio];

    return kAudioHardwareNoError;
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
