//Auth: Zaid Laffta
// Winter 2024
// CSE 160

#include "../../includes/packet.h"

// Define the TCP interface, used for handling TCP-like communication operations
interface TCP {
    // Command to start a server on a specified port
    command void startServer(uint16_t port);
    // Command to initiate a client connection to a destination address and port
    // with a specified source port and transfer type
    command void startClient(uint16_t dest, uint16_t srcPort, uint16_t destPort, uint16_t transfer);
    command void closeClient(uint16_t dest, uint16_t srcPort, uint16_t destPort);
    command void receive(pack* msg);
   // command void recieve(pack* msg);
    event void route(pack* msg);
    event uint16_t getSequence();

}
