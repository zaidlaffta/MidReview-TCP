//Auth: Zaid Laffta
// Winter 2024
// CSE 160

#include "../../includes/packet_id.h"

// Define the configuration for the Flooding component
configuration FloodingC {
        // Provide the Flooding interface to make it accessible to other modules
    provides interface Flooding;
}

implementation {
    components FloodingP;
    // Connect the Flooding interface to FloodingP
    Flooding = FloodingP;

    // Create a new instance of SimpleSendC to handle packet sending,
    // specifying AM_PACK as the active message type
    components new SimpleSendC(AM_PACK);
    FloodingP.Sender -> SimpleSendC; // Link the Sender interface in FloodingP to SimpleSendC

    // Create a new list component to track previously sent packets,
    // with a capacity of 64 entries and each entry identified by packID
    components new ListC(packID, 64);
    FloodingP.PreviousPackets -> ListC; // Link the PreviousPackets interface in FloodingP to ListC
}