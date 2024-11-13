//Auth: Zaid Laffta
// Winter 2024
// CSE 160
/*
#include "../../includes/packet.h"
#include "../../includes/packet_id.h"

module FloodingP {
    provides interface Flooding;

    uses interface SimpleSend as Sender;
    uses interface List<packID> as PreviousPackets;
}

implementation {

    bool isDuplicate(uint16_t src, uint16_t seq) {
        uint16_t i;
        // Loop over previous packets
        for (i = 0; i < call PreviousPackets.size(); i++) {
            packID prevPack = call PreviousPackets.get(i);

            // Packet can be identified by src && seq number
            if (prevPack.src == src && prevPack.seq == seq) {
                return TRUE;
            }
        }
        return FALSE;
    }

    bool isValid(pack* msg) {

        if (isDuplicate(msg->src, msg->seq)) {
            dbg(FLOODING_CHANNEL, "Duplicate packet. Dropping...\n");
            return FALSE;
        }

        return TRUE;
    }

    void sendFlood(pack* msg) {
        if (msg->dest != AM_BROADCAST_ADDR && msg->src != TOS_NODE_ID) {
            dbg(FLOODING_CHANNEL, "Packet recieved from %d. Destination: %d. Flooding...\n", msg->src, msg->dest);
        } 

        call Sender.send(*msg, AM_BROADCAST_ADDR);
    }

    command void Flooding.flood(pack* msg) {
        if (isValid(msg)) {
            packID packetID;
            packetID.src = msg->src;
            packetID.seq = msg->seq;
            
            call PreviousPackets.pushbackdrop(packetID);

            sendFlood(msg);
        }
    }
}
*/
// Auth: Zaid Laffta
// Winter 2024
// CSE 160

#include "../../includes/packet.h"         // Include packet structure definitions
#include "../../includes/packet_id.h"      // Include packet ID definitions

// Define the FloodingP module, which provides the Flooding interface
module FloodingP {
    provides interface Flooding;

    // Use the SimpleSend interface for sending packets, aliased as Sender
    uses interface SimpleSend as Sender;
    
    // Use the List interface to maintain a history of previously sent packet IDs
    uses interface List<packID> as PreviousPackets;
}

implementation {

    // Function to check if a packet is a duplicate based on its source and sequence number
    bool isDuplicate(uint16_t src, uint16_t seq) {
        uint16_t i;

        // Iterate through the list of previously received packets
        for (i = 0; i < call PreviousPackets.size(); i++) {
            packID prevPack = call PreviousPackets.get(i);

            // Check if both source and sequence number match any previously stored packet
            if (prevPack.src == src && prevPack.seq == seq) {
                return TRUE;  // Duplicate packet found
            }
        }
        return FALSE;  // No duplicate found
    }

    // Function to validate if the received packet is new and should be processed
    bool isValid(pack* msg) {
        // Check for duplicates and log if the packet is a duplicate
        if (isDuplicate(msg->src, msg->seq)) {
            dbg(FLOODING_CHANNEL, "Duplicate packet. Dropping...\n");
            return FALSE;  // Invalid due to duplication
        }

        return TRUE;  // Valid packet
    }

    // Function to broadcast (flood) the packet to all nodes
    void sendFlood(pack* msg) {
        // Log packet source and destination details if not a broadcast or from the local node
        if (msg->dest != AM_BROADCAST_ADDR && msg->src != TOS_NODE_ID) {
            dbg(FLOODING_CHANNEL, "Packet received from %d. Destination: %d. Flooding...\n", msg->src, msg->dest);
        } 

        // Send the packet to all nodes using the Sender interface
        call Sender.send(*msg, AM_BROADCAST_ADDR);
    }

    // Command to initiate flooding, ensuring the packet is valid and not a duplicate
    command void Flooding.flood(pack* msg) {
        // Check if the packet is valid for flooding
        if (isValid(msg)) {
            packID packetID;
            packetID.src = msg->src;  // Store source of the packet
            packetID.seq = msg->seq;  // Store sequence number of the packet
            
            // Add the packet ID to the history list to avoid re-flooding duplicates
            call PreviousPackets.pushbackdrop(packetID);

            // Begin the flooding process for the validated packet
            sendFlood(msg);
        }
    }
    // Function to log packet information for debugging
    void logPacketInfo(pack* msg) {
        dbg(FLOODING_CHANNEL, "Logging packet - Source: %d, Sequence: %d, Destination: %d\n", msg->src, msg->seq, msg->dest);
    }

}
