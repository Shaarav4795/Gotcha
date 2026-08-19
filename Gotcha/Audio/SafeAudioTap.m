#import "SafeAudioTap.h"

BOOL SafeInstallTap(AVAudioEngine *engine,
                    AVAudioNode *node,
                    AVAudioFormat *format,
                    void (^block)(AVAudioPCMBuffer *buffer, AVAudioTime *when)) {
    @try {
        [node installTapOnBus:0 bufferSize:4096 format:format block:block];
        return YES;
    } @catch (NSException *exception) {
        return NO;
    }
}
