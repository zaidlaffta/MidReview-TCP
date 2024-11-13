//Auth: Zaid Laffta
// Winter 2024
// CSE 160

#include "../../includes/packet.h"

// Define the Routing interface, used for handling routing operations
interface Routing {
    // Command to initiate the routing process
    command void start();

    // Command to send a routing-related message
    command void send(pack* msg);

    // Command to process a received routing packet
    command void receive(pack* routing_packet);

    // Command to update the routing table with a new set of neighbors
    command void updateNeighbors(uint32_t* neighbors, uint16_t numNeighbors);

    // Command to print the current routing table for debugging and analysis
    command void printRoutingTable();

    // Event to get the sequence number associated with the current routing state
    event uint16_t getSequence();
}
