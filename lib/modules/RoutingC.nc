//Auth: Zaid Laffta
// Winter 2024
// CSE 160

#include <Timer.h>
#include "../../includes/route.h"

configuration RoutingC {
    provides interface Routing;
}

implementation {
    // RoutingP module is the main implementation of the Routing functionality
    components RoutingP;
    Routing = RoutingP; // Connect the provided Routing interface to RoutingP

    // Random number generator component, used by RoutingP for randomness in routing decisions
    components RandomC;
    RoutingP.Random -> RandomC; // Link the Random interface in RoutingP to RandomC

    // List component to store routing entries with a capacity for up to 256 nodes
    // This list is used as the routing table to store route entries, with each entry of type Route
    components new ListC(Route, 256);
    RoutingP.RoutingTable -> ListC; // Link the RoutingTable interface in RoutingP to ListC

    // SimpleSend component to handle packet sending, configured for AM_PACK message type
    components new SimpleSendC(AM_PACK);
    RoutingP.Sender -> SimpleSendC; // Link the Sender interface in RoutingP to SimpleSendC

    // Timer component to trigger events at specific intervals, used as a triggered event timer
    components new TimerMilliC() as TriggeredEventTimer;
    RoutingP.TriggeredEventTimer -> TriggeredEventTimer; // Connect the TriggeredEventTimer interface in RoutingP to TimerMilliC

    // Another Timer component, used to trigger regular, repeating events
    components new TimerMilliC() as RegularTimer;
    RoutingP.RegularTimer -> RegularTimer; // Connect the RegularTimer interface in RoutingP to another instance of TimerMilliC
}
