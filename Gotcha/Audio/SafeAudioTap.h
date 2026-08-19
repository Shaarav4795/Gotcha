#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

BOOL SafeInstallTap(AVAudioEngine *engine,
                    AVAudioNode *node,
                    AVAudioFormat *format,
                    void (^block)(AVAudioPCMBuffer *buffer, AVAudioTime *when));

NS_ASSUME_NONNULL_END
