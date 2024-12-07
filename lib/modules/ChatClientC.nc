//Auth: Zaid Laffta
// Winter 2024
// CSE 160

#include "../../includes/CommandMsg.h"
#include "../includes/packet.h"


configuration ChatClientC {
    provides interface ChatClient;
}

implementation {
    // Connect ChatClientP module to the ChatClient interface
    components ChatClientP;
    ChatClient = ChatClientP;

    // Connect the SimpleSend component for message sending
    components new SimpleSendC(AM_PACK);
    ChatClientP.Sender -> SimpleSendC;

    // Connect the Transport component for transport layer functionalities
    components TransportC;
    ChatClientP.Transport -> TransportC;

    // Initialize a hashmap for user table with 10 entries
    components new HashmapC(uint16_t, 10) as userTableC;
    ChatClientP.userTable -> userTableC;

    // Initialize a hashmap for node-to-port table with 10 entries
    components new HashmapC(uint16_t, 10) as nodePortTableC;
    ChatClientP.nodePortTable -> nodePortTableC;

    // Initialize a list for managing broadcast messages with 500 entries
    components new ListC(uint32_t, 500) as broadcastListC;
    ChatClientP.broadcastList -> broadcastListC; 

    // Initialize a millisecond timer for broadcast management
    components new TimerMilliC() as broadcastTimer;
    ChatClientP.broadcastTimer -> broadcastTimer;
}
