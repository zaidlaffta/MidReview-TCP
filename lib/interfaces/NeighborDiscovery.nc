//Auth: Zaid Laffta
// Winter 2024
// CSE 160

#include "../../includes/packet.h"

// Define the NeighborDiscoveryHandler interface, used for neighbor discovery functionality
interface NeighborDiscoveryHandler {
    // Command to initiate the neighbor discovery process
    command void discover();

    // Command to handle the receipt of a message from a neighbor
    command void receive(pack* msg);

    // Command to retrieve an array of neighbor identifiers
    command uint32_t* getNeighbors();

    // Command to get the current count of discovered neighbors
    command uint16_t numNeighbors();

    // Command to print the list of discovered neighbors for debugging purposes
    command void printNeighbors();

    // Event to obtain the sequence number associated with the current discovery state
    event uint16_t getSequence();
}
