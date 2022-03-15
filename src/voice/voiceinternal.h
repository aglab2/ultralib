#ifndef VOICE_INTERNAL_H
#define VOICE_INTERNAL_H

// Various prototypes and externs that don't show up in os_voice.h
extern s32 __osPfsLastChannel;

u8 __osVoiceContDataCrc(u8* data, u32 length);
s32 __osVoiceCheckResult(OSVoiceHandle* hd, u8* stat);
s32 __osVoiceSetADConverter(OSMesgQueue*, int ch, u8 cmd);
s32 __osVoiceGetStatus(OSMesgQueue* mq, s32 port, u8* status);
s32 __osVoiceContRead2(OSMesgQueue* mq, int channel, u16 address, u8* buffer);
s32 __osVoiceContWrite4(OSMesgQueue* mq, int channel, u16 address, u8 dst[4]);
s32 __osVoiceContWrite20(OSMesgQueue* mq, int channel, u16 address, u8* buffer);
s32 __osVoiceContRead36(OSMesgQueue* mq, s32 channel, u16 address, u8* buffer);
s32 __osContChannelReset(OSMesgQueue* mq, int channel);


#endif
