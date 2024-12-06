

#include "../../includes/CommandMsg.h"
#include "../includes/packet.h"


configuration ChatClientC {
    provides interface ChatClient;
}

implementation {
    components ChatClientP;
    ChatClient = ChatClientP;

    components new SimpleSendC(AM_PACK);
    ChatClientP.Sender -> SimpleSendC;

    components TransportC;
    ChatClientP.Transport -> TransportC;

    components new HashmapC(uint16_t, 10) as userTableC;
    ChatClientP.userTable -> userTableC;

    components new HashmapC(uint16_t, 10) as nodePortTableC;
    ChatClientP.nodePortTable -> nodePortTableC;

    components new ListC(uint32_t, 500) as broadcastListC;
    ChatClientP.broadcastList -> broadcastListC; 

    components new TimerMilliC() as broadcastTimer;
    ChatClientP.broadcastTimer -> broadcastTimer;


}