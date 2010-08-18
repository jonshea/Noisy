/*
 * Copyright (c) 2010, Jon Shea <http:jonshea.com>
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
static NSString *sPreviousNoiseTypeKeyPath = @"PreviousNoiseType";
static NSString *sNoiseVolumeKeyPath = @"NoiseVolume";

@implementation NoisyApp

+ (void)initialize
{
    NSMutableDictionary *defaults = [NSMutableDictionary dictionary];

    [defaults setObject:[NSNumber numberWithInteger:BrownNoiseType] forKey:sNoiseTypeKeyPath];
    [defaults setObject:[NSNumber numberWithInteger:BrownNoiseType] forKey:sNoiseTypeKeyPath];
    [defaults setObject:[NSNumber numberWithDouble:0.2] forKey:sNoiseVolumeKeyPath];

    [[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
}

- (void)awakeFromNib
{
    _generator = [[NoiseGenerator alloc] init];
    
    [self setVolume:[[NSUserDefaults standardUserDefaults] doubleForKey:sNoiseVolumeKeyPath]];
    
    //    int p = [[NSUserDefaults standardUserDefaults] integerForKey:sPreviousNoiseTypeKeyPath];
    [self setNoiseType:[[NSUserDefaults standardUserDefaults] integerForKey:sNoiseTypeKeyPath]];
    previousNoiseType = [[NSUserDefaults standardUserDefaults] integerForKey:sPreviousNoiseTypeKeyPath];
    
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(handleWorkspaceWillSleepNotification:) name:NSWorkspaceWillSleepNotification object:NULL];
}


- (void)dealloc
{
    [[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self];

    [_generator release];

    [super dealloc];
}

- (double)volume {
    return [_generator volume];
}

- (void)setVolume:(double)newVolume {
    if (newVolume < sNoiseMinVolume) {
        newVolume = sNoiseMinVolume;
    }
    else if (newVolume > sNoiseMaxVolume) {
        newVolume = sNoiseMaxVolume;
    }
    
    [[NSUserDefaults standardUserDefaults] setDouble:newVolume forKey:sNoiseVolumeKeyPath];
    [_generator setVolume:newVolume];
}

- (int)noiseType {
    return [_generator type];
}

- (void)setNoiseType:(int)newNoiseType {
    // Save the previous noise type, unless the previous noise type was 'NoNoise'
    if ([self noiseType] != NoNoiseType) {
        previousNoiseType = [self noiseType];
        [[NSUserDefaults standardUserDefaults] setInteger:previousNoiseType forKey:sPreviousNoiseTypeKeyPath];
    }
    
    [[NSUserDefaults standardUserDefaults] setInteger:newNoiseType forKey:sNoiseTypeKeyPath];
    [_generator setType:newNoiseType];
}

- (void)toggleMute {
    if ([self noiseType] != NoNoiseType) {
        [self setNoiseType:NoNoiseType];
    }
    else {
        [self setNoiseType:previousNoiseType];
    }
}
- (BOOL)applicationShouldHandleReopen:(NSApplication *)theApplication hasVisibleWindows:(BOOL)flag
{
    [oWindow makeKeyAndOrderFront:self];
    return YES;
}

- (void)handleWorkspaceWillSleepNotification:(NSNotification *)notification
{
    [[NSUserDefaults standardUserDefaults] setInteger:NoNoiseType forKey:sNoiseTypeKeyPath];
}

// Intercept events that correspond to keyboard commands
- (void)sendEvent:(NSEvent *)anEvent 
{
    if ([anEvent type] == NSKeyDown) {
        NSString *theKeys = [anEvent charactersIgnoringModifiers];
        unichar keyChar = 0;        
        if ([theKeys length] == 0) {
            return;            // reject dead keys
        }
        
        if ([theKeys length] == 1) {
            keyChar = [theKeys characterAtIndex:0];
            
            // CommandanEventshift arrow will set the volume to max or min
            if ([anEvent modifierFlags] & NSCommandKeyMask && [anEvent modifierFlags] & NSShiftKeyMask) {
                if (keyChar == NSLeftArrowFunctionKey || keyChar == NSDownArrowFunctionKey) {
                    [self setVolume:sNoiseMinVolume];
                    return;
                }
                if (keyChar == NSRightArrowFunctionKey || keyChar == NSUpArrowFunctionKey) {
                    [self setVolume:sNoiseMaxVolume];
                    return;
                }
            }
            
            // Anything else with an arrow will nudge the volume up or down
            if (keyChar == NSLeftArrowFunctionKey || keyChar == NSDownArrowFunctionKey) {
                [self setVolume:[self volume] - sNoiseVolumeStepSize];
                return;
            }
            if (keyChar == NSRightArrowFunctionKey || keyChar == NSUpArrowFunctionKey) {
                [self setVolume:[self volume] + sNoiseVolumeStepSize];
                return;
            }
            
            //Spacebar toggles mute.
            if ([anEvent keyCode] == 49) {
                [self toggleMute];
                return;
            }
        }
    }
    
    [super sendEvent:anEvent];
}

#pragma mark -
#pragma mark IBActions

- (IBAction)openAboutNoiseColors:(id)sender
{
    NSURL *url = [NSURL URLWithString:@"http://en.wikipedia.org/wiki/Colors_of_noise"];
    [[NSWorkspace sharedWorkspace] openURL:url];
}


- (IBAction)openNoisyWebsite:(id)sender
{
    NSURL *url = [NSURL URLWithString:@"http://github.com/jonshea/Noisy"];
    [[NSWorkspace sharedWorkspace] openURL:url];
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


- (void)setScriptNoiseType:(id)scriptTypeAsNumber
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


- (id)scriptVolume
{
    double volume = [[NSUserDefaults standardUserDefaults] doubleForKey:sNoiseVolumeKeyPath];
    NSInteger roundedVolume = round(volume * 100);
    return [NSNumber numberWithInteger:roundedVolume];
}


- (void)setScriptVolume:(id)volumeAsNumber
{
    double volume = [volumeAsNumber doubleValue];

    volume /= 100.0;
    if (volume > 100.0) volume = 100.0;
    if (volume < 0.0)   volume = 0.0;

    [[NSUserDefaults standardUserDefaults] setDouble:volume forKey:sNoiseVolumeKeyPath];
}

@end
