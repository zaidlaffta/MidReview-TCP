

// Auth: Zaid Laffta
// Winter 2024
// CSE 160

#include "../../includes/packet.h" // Packet structure definitions

// Define the NeighborDiscoveryP module, providing the NeighborDiscovery interface
module NeighborDiscoveryP {
    provides interface NeighborDiscovery;

    // Using SimpleSend for sending packets, aliased as Sender
    uses interface SimpleSend as Sender;

    // Using Hashmap to store neighbors and their timeout values
    uses interface Hashmap<uint16_t> as Neighbors;
}

implementation {
    const uint16_t TIMEOUT_CYCLES = 5; // Number of missed replies before dropping a neighbor
    uint16_t* node_seq;                // Sequence number for packet tracking

    // Converts a received neighbor discovery packet into a reply and sends it
    void pingReply(pack* msg) {
        msg->src = TOS_NODE_ID;
        msg->protocol = PROTOCOL_PINGREPLY;
        call Sender.send(*msg, AM_BROADCAST_ADDR);
    }

    // Logs neighbor discovery packet information for debugging purposes
    void logNeighborDiscovery(pack* msg) {
        dbg(NEIGHBOR_CHANNEL, "Neighbor discovery packet - Source: %d, Protocol: %d\n", msg->src, msg->protocol);
    }

    // Processes incoming neighbor discovery packets
    // Neighbor discovery is implemented with ping and ping replies only
    void protocolHandler(pack* msg) {
        logNeighborDiscovery(msg); // Log packet details
        switch(msg->protocol) {
            case PROTOCOL_PING:
                dbg(NEIGHBOR_CHANNEL, "Discovery from %d. Adding to list & replying...\n", msg->src);
                call Neighbors.insert(msg->src, TIMEOUT_CYCLES);
                pingReply(msg);
                break;

            case PROTOCOL_PINGREPLY:
                dbg(NEIGHBOR_CHANNEL, "Reply from %d. Adding to neighbor list...\n", msg->src);
                call Neighbors.insert(msg->src, TIMEOUT_CYCLES);
                break;

            default:
                dbg(GENERAL_CHANNEL, "Unknown protocol in discovery: %d\n", msg->protocol);
        }
    }

    // Reduces timeout for all neighbors, removing any that reach zero
    void decrement_timeout() {
        uint16_t i;
        uint32_t* neighbors = call Neighbors.getKeys();

        for (i = 0; i < call Neighbors.size(); i++) {
            uint16_t timeout = call Neighbors.get(neighbors[i]);
            call Neighbors.insert(neighbors[i], timeout - 1);

            // Remove neighbor if timeout reaches zero
            if (timeout - 1 <= 0) {
                call Neighbors.remove(neighbors[i]);
            }
        }
    }

    // Resets timeout for all neighbors to the initial TIMEOUT_CYCLES value
    void resetTimeoutForAllNeighbors() {
        uint16_t i;
        uint32_t* neighbors = call Neighbors.getKeys();
        
        for (i = 0; i < call Neighbors.size(); i++) {
            call Neighbors.insert(neighbors[i], TIMEOUT_CYCLES);
        }
        dbg(NEIGHBOR_CHANNEL, "All neighbor timeouts reset to initial value.\n");
    }

    // Creates and configures a neighbor discovery packet for broadcasting
    void createNeighborPack(pack* neighborPack) {
        neighborPack->src = TOS_NODE_ID;
        neighborPack->dest = AM_BROADCAST_ADDR;
        neighborPack->TTL = 1;
        neighborPack->seq = signal NeighborDiscovery.getSequence();
        neighborPack->protocol = PROTOCOL_PING;
        memcpy(neighborPack->payload, "Neighbor Discovery\n", 19);
    }

    // Sends a neighbor discovery packet with the current sequence number
    command void NeighborDiscovery.discover() {
        pack neighborPack;
        decrement_timeout();             // Update timeouts for neighbors
        createNeighborPack(&neighborPack); // Prepare discovery packet
        call Sender.send(neighborPack, AM_BROADCAST_ADDR);
    }

    // Handles incoming neighbor discovery packets
    command void NeighborDiscovery.receive(pack* msg) {
        protocolHandler(msg); // Process packet using protocolHandler
    }

    // Retrieves a list of current neighbors. Use with numNeighbors() for iteration
    command uint32_t* NeighborDiscovery.getNeighbors() {
        return call Neighbors.getKeys();
    }

    // Returns the count of known neighbors for this node
    command uint16_t NeighborDiscovery.numNeighbors() {
        return call Neighbors.size();
    }

    // Prints the list of all neighbors for the current node
    command void NeighborDiscovery.printNeighbors() {
        uint16_t i;
        uint32_t* neighbors = call NeighborDiscovery.getNeighbors();

        dbg(GENERAL_CHANNEL, "--- Neighbors of Node %d ---\n", TOS_NODE_ID);
        for (i = 0; i < call NeighborDiscovery.numNeighbors(); i++) {
            dbg(GENERAL_CHANNEL, "%d\n", neighbors[i]);
        }
        dbg(GENERAL_CHANNEL, "---------------------------\n");
    }
}
