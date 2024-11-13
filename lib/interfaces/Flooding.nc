//Auth: Zaid Laffta
// Winter 2024
// CSE 160

#include "../../includes/packet.h"

// Define the Flooding interface, used for flooding messages across the network
interface Flooding {
    // Command to initiate the flooding
    command void flood(pack* msg);
}
