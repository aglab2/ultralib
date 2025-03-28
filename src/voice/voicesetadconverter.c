#include "PR/os_internal.h"
#include "src/io/controller.h"
#include "PR/os_voice.h"
#include "voiceinternal.h"
#include "src/io/controller_voice.h"
#include "src/io/siint.h"

#define SWRITEFORMAT(p) ((__OSVoiceSWriteFormat*)(p))

s32 __osVoiceSetADConverter(OSMesgQueue* mq, int channel, u8 data) {
    s32 ret;
    int i;
    u8* ptr;
    u8 status;
    int retry = 2;

    __osSiGetAccess();

    do {

        ptr = (u8*)__osPfsPifRam.ramarray;

        if ((__osContLastCmd != CONT_CMD_SWRITE_VOICE) || (__osPfsLastChannel != channel)) {
            __osContLastCmd = CONT_CMD_SWRITE_VOICE;
            __osPfsLastChannel = channel;

            for (i = 0; i < channel; i++) {
                *ptr++ = 0;
            }

            __osPfsPifRam.pifstatus = CONT_CMD_EXE;

            SWRITEFORMAT(ptr)->txsize = CONT_CMD_SWRITE_VOICE_TX;
            SWRITEFORMAT(ptr)->rxsize = CONT_CMD_SWRITE_VOICE_RX;
            SWRITEFORMAT(ptr)->cmd = CONT_CMD_SWRITE_VOICE;
            SWRITEFORMAT(ptr)->datacrc = 0;

            ptr[sizeof(__OSVoiceSWriteFormat)] = CONT_CMD_END;
        } else {
            ptr = (u8*)&__osPfsPifRam + channel;
        }

        SWRITEFORMAT(ptr)->data = data;
        SWRITEFORMAT(ptr)->scrc = __osContAddressCrc(data * 8);

        __osSiRawStartDma(OS_WRITE, &__osPfsPifRam);
        osRecvMesg(mq, NULL, OS_MESG_BLOCK);
        __osSiRawStartDma(OS_READ, &__osPfsPifRam);
        osRecvMesg(mq, NULL, OS_MESG_BLOCK);

        ret = CHNL_ERR(*SWRITEFORMAT(ptr));

        if (ret == 0) {
            if (SWRITEFORMAT(ptr)->datacrc & 1) {
                ret = __osVoiceGetStatus(mq, channel, &status);
                if (ret != 0) {
                    break;
                }

                ret = CONT_ERR_CONTRFAIL;
            }
        } else {
            ret = CONT_ERR_NO_CONTROLLER;
        }

    } while ((ret == CONT_ERR_CONTRFAIL) && (retry-- >= 0));

    __osSiRelAccess();

    return ret;
}
