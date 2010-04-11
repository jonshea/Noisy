/*
 * Copyright (c) 2008, Noisy Developers
 * All rights reserved.
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


#import "NoisyApp.h"
#import "NoiseGenerator.h"

static NSString *sNoiseTypeKeyPath   = @"NoiseType";
static NSString *sNoiseVolumeKeyPath = @"NoiseVolume";


@implementation NoisyApp

+ (void) initialize
{
    NSMutableDictionary *defaults = [NSMutableDictionary dictionary];

    [defaults setObject:[NSNumber numberWithInteger:NoNoiseType] forKey:sNoiseTypeKeyPath];
    [defaults setObject:[NSNumber numberWithDouble:0.5] forKey:sNoiseVolumeKeyPath];

    [[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
}

- (void)awakeFromNib
{
    _generator = [[NoiseGenerator alloc] init];
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        
    [defaults addObserver:self forKeyPath:sNoiseTypeKeyPath   options:0 context:NULL];
    [defaults addObserver:self forKeyPath:sNoiseVolumeKeyPath options:0 context:NULL];

    [_generator setVolume: [[NSUserDefaults standardUserDefaults] doubleForKey:sNoiseVolumeKeyPath]];
    [_generator setType:   [[NSUserDefaults standardUserDefaults] integerForKey:sNoiseTypeKeyPath]];

    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(handleWorkspaceWillSleepNotification:) name:NSWorkspaceWillSleepNotification object:NULL];
}


- (void) dealloc
{
    [[NSUserDefaults standardUserDefaults] removeObserver:self forKeyPath:sNoiseVolumeKeyPath];
    [[NSUserDefaults standardUserDefaults] removeObserver:self forKeyPath:sNoiseTypeKeyPath];

    [[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self];

    [_generator release];

    [super dealloc];
}


- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:sNoiseTypeKeyPath]) {
        NoiseType type = [[NSUserDefaults standardUserDefaults] integerForKey:sNoiseTypeKeyPath];
        _generator.type = type;

    } else if ([keyPath isEqualToString:sNoiseVolumeKeyPath]) {
        double volume = [[NSUserDefaults standardUserDefaults] doubleForKey:sNoiseVolumeKeyPath];
        _generator.volume = volume;
    }
}


- (void)handleWorkspaceWillSleepNotification:(NSNotification *)notification
{
    [[NSUserDefaults standardUserDefaults] setInteger:NoNoiseType forKey:sNoiseTypeKeyPath];
}


#pragma mark -
#pragma mark IBActions

- (IBAction) openAboutWhiteNoise:(id)sender
{
    NSURL *url = [NSURL URLWithString:@"http://en.wikipedia.org/wiki/White_noise"];
    [[NSWorkspace sharedWorkspace] openURL:url];
}


- (IBAction) openAboutPinkNoise:(id)sender
{
    NSURL *url = [NSURL URLWithString:@"http://en.wikipedia.org/wiki/Pink_Noise"];
    [[NSWorkspace sharedWorkspace] openURL:url];
}


- (IBAction) openNoisyWebsite:(id)sender
{
    NSURL *url = [NSURL URLWithString:@"http://code.google.com/p/noisy/"];
    [[NSWorkspace sharedWorkspace] openURL:url];
}


#pragma mark -
#pragma mark Delegate Methods

- (void)windowWillClose:(NSNotification *)notification
{
    [NSApp terminate:self];
}


#pragma mark -
#pragma mark AppleScript

- (id) scriptNoiseType
{
    NoiseType type = [[NSUserDefaults standardUserDefaults] integerForKey:sNoiseTypeKeyPath];
    OSType scriptType;

    if (type == WhiteNoiseType) {
        scriptType = 'Nwht';
    } else if (type == PinkNoiseType) {
        scriptType = 'Npnk';
    } else {
        scriptType = 'Nnon';
    }

    return [[[NSNumber alloc] initWithUnsignedInteger:scriptType] autorelease];
}


- (void) setScriptNoiseType:(id)scriptTypeAsNumber
{
    OSType scriptType = [scriptTypeAsNumber unsignedIntegerValue];
    NoiseType type;
    
    if (scriptType == 'Nnon') {
        type = NoNoiseType;
    } else if (scriptType == 'Npnk') {
        type = PinkNoiseType;
    } else if (scriptType == 'Nwht') {
        type = WhiteNoiseType;
    } else {
        type = NoNoiseType;
    }

    [[NSUserDefaults standardUserDefaults] setInteger:type forKey:sNoiseTypeKeyPath];
}


- (id) scriptVolume
{
    double volume = [[NSUserDefaults standardUserDefaults] doubleForKey:sNoiseVolumeKeyPath];
    NSInteger roundedVolume = round(volume * 100);
    return [NSNumber numberWithInteger:roundedVolume];
}


- (void) setScriptVolume:(id)volumeAsNumber
{
    double volume = [volumeAsNumber doubleValue];

    volume /= 100.0;
    if (volume > 100.0) volume = 100.0;
    if (volume < 0.0)   volume = 0.0;

    [[NSUserDefaults standardUserDefaults] setDouble:volume forKey:sNoiseVolumeKeyPath];
}

@end
