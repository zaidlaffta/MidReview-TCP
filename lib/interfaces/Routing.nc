//Auth: Zaid Laffta
// Winter 2024
// CSE 160

#include "../../includes/packet.h"

interface Routing {
    command void start();
    command void send(pack* msg);
    command void recieve(pack* routing_packet);
    command void updateNeighbors(uint32_t* neighbors, uint16_t numNeighbors);
    command void printRoutingTable();
    event uint16_t getSequence();
}