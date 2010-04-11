/*
 * Modifications to original file:
 *     Copyright (c) 2008, Noisy Developers
 *     All rights reserved.
 *
 * Original file:
 *     NoiseGenerator.h
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
 

#import <Cocoa/Cocoa.h>
#import <AudioToolbox/AudioToolbox.h>


#define kPinkMaxRandomRows		32
#define kPinkRandomBits			30
#define kPinkRandomShift		((sizeof(long)*8)-kPinkRandomBits)

#define kNumberOfBuffers     2
#define kBytesPerBuffer      (2*8*1024)


typedef enum {
    NoNoiseType,
    WhiteNoiseType,
    PinkNoiseType,
} NoiseType;


@interface NoiseGenerator : NSObject
{
    AudioQueueRef        _queue;
    AudioQueueBufferRef  _buffer[kNumberOfBuffers];
	
    long            _pinkRows[kPinkMaxRandomRows];
	long            _pinkRunningSum;	// Used to optimize summing of generators
	int             _pinkIndex;			// Incremented each sample
	int             _pinkIndexMask;		// Index wrapped by &ing with this mask
	float           _pinkScalar;		// Used to scale within range of -1.0 to 1.0

    NoiseType       _type;
	double          _volume;
    BOOL            _isPlaying;
}

- (double) volume;
- (void) setVolume:(double)volume;

- (NoiseType) type;
- (void) setType:(NoiseType)type;

@end
