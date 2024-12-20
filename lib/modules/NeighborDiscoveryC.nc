//Auth: Zaid Laffta
// Winter 2024
// CSE 160

#include "../../includes/packet.h"

configuration NeighborDiscoveryC {
    provides interface NeighborDiscovery;
}

implementation {
    components NeighborDiscoveryP;
    NeighborDiscovery = NeighborDiscoveryP;

    components new SimpleSendC(AM_PACK);
    NeighborDiscoveryP.Sender -> SimpleSendC;

    components new HashmapC(uint16_t, 256) as Neighbors;
    NeighborDiscoveryP.Neighbors-> Neighbors;
}
