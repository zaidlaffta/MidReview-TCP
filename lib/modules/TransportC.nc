

#include <Timer.h>
#include "../../includes/CommandMsg.h"
#include "../includes/packet.h"
#include "../includes/socket.h"

configuration TransportC {
    provides interface Transport;
}

implementation {
    components TransportP;
    Transport = TransportP;

    components new SimpleSendC(AM_PACK);
    TransportP.TransportSend -> SimpleSendC;

    // components NeighborDiscoveryC;
    // TransportP.NeighborDiscovery -> NeighborDiscoveryC;

    components FloodingC;
    TransportP.Flooding -> FloodingC;

    components RoutingC;
    TransportP.Routing -> RoutingC;

    components ChatClientC;
    TransportP.ChatClient -> ChatClientC;

    components new TimerMilliC() as ConnectionTimer;
    TransportP.ConnectionTimer -> ConnectionTimer;

    components new TimerMilliC() as DataTimer;
    TransportP.DataTimer -> DataTimer;

    components new TimerMilliC() as WriteTimer;
    TransportP.WriteTimer -> WriteTimer;

    components new HashmapC(uint32_t, 10) as connectionTableC;
    TransportP.connectionTable -> connectionTableC;

    // these two are for reliability
    components new ListC(uint16_t, 500) as seqTimerC;
    TransportP.seqTimer -> seqTimerC; 

    components new HashmapC(uint16_t, 500) as AckSeqHashC;
    TransportP.AckSeqHash -> AckSeqHashC;

    components new HashmapC(uint16_t, 500) as SeqBuffPosHashC;
    TransportP.SeqBuffPosHash -> SeqBuffPosHashC;

}