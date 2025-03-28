#include "PR/os_internal.h"
#include "src/io/controller.h"
#include "PR/os_voice.h"
#include "voiceinternal.h"
#include "src/io/controller_voice.h"
#include "src/io/siint.h"

#define WRITE4FORMAT(p) ((__OSVoiceWrite4Format*)(ptr))

s32 __osVoiceContWrite4(OSMesgQueue* mq, int channel, u16 address, u8 dst[4]) {
    s32 ret;
    u8 status;
    int i;
    u8* ptr;
    s32 retry = 2;
    u8 crc;

    __osSiGetAccess();

    do {

        ptr = (u8*)&__osPfsPifRam;

        if ((__osContLastCmd != CONT_CMD_WRITE4_VOICE) || (__osPfsLastChannel != channel)) {
            __osContLastCmd = CONT_CMD_WRITE4_VOICE;
            __osPfsLastChannel = channel;

            for (i = 0; i < channel; i++) {
                *ptr++ = 0;
            }

            __osPfsPifRam.pifstatus = CONT_CMD_EXE;

            WRITE4FORMAT(ptr)->dummy = CONT_CMD_NOP;
            WRITE4FORMAT(ptr)->txsize = CONT_CMD_WRITE4_VOICE_TX;
            WRITE4FORMAT(ptr)->rxsize = CONT_CMD_WRITE4_VOICE_RX;
            WRITE4FORMAT(ptr)->cmd = CONT_CMD_WRITE4_VOICE;
            WRITE4FORMAT(ptr)->datacrc = 0xFF;

            ptr[sizeof(__OSVoiceWrite4Format)] = CONT_CMD_END;
        } else {
            ptr = (u8*)&__osPfsPifRam + channel;
        }

        WRITE4FORMAT(ptr)->addrh = address >> 3;
        WRITE4FORMAT(ptr)->addrl = __osContAddressCrc(address) | (address << 5);

        bcopy(dst, &WRITE4FORMAT(ptr)->data, 4);

        __osSiRawStartDma(OS_WRITE, &__osPfsPifRam);
        crc = __osVoiceContDataCrc(dst, 4);
        osRecvMesg(mq, NULL, OS_MESG_BLOCK);
        __osSiRawStartDma(OS_READ, &__osPfsPifRam);
        osRecvMesg(mq, NULL, OS_MESG_BLOCK);

        ret = (WRITE4FORMAT(ptr)->rxsize & 0xC0) >> 4;

        if (ret == 0) {
            if (crc != WRITE4FORMAT(ptr)->datacrc) {
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
