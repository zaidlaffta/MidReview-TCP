//Auth: Zaid Laffta
// Winter 2024
// CSE 160

#include "../../includes/packet_id.h"

configuration FloodingC {
    provides interface Flooding;
}

implementation {
    components FloodingP;
    Flooding = FloodingP;

    components new SimpleSendC(AM_PACK);
    FloodingP.Sender -> SimpleSendC;

    components new ListC(packID, 64);
    FloodingP.PreviousPackets -> ListC;
}
