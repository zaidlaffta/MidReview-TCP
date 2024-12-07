//Auth: Zaid Laffta
// Winter 2024
// CSE 160

#include "../../includes/socket.h"

configuration TransportC{
    provides interface Transport;
}

implementation {
    components TransportP;
    Transport = TransportP;
    
    components ChatClientC;
    TransportP.ChatClient -> ChatClientC;
    components new HashmapC(socket_store_t, MAX_NUM_OF_SOCKETS);
    TransportP.SocketMap -> HashmapC;
}
