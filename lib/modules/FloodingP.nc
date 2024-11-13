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
}*/

// Author: Zaid Laffta
// Course: CSE 160 - Winter 2024

#include "../../includes/packet.h"         // Include packet structure definitions
#include "../../includes/packet_id.h"      // Include packet ID definitions

module FloodingP {
    provides interface Flooding;

    uses interface SimpleSend as PacketSender;
    uses interface List<packID> as PacketHistory;
}

implementation {

    // Check if a packet with the given source and sequence number is a duplicate
    bool packetIsDuplicate(uint16_t sourceID, uint16_t sequenceNum) {
        uint16_t index;

        // Iterate through stored packet IDs to check for duplicates
        for (index = 0; index < call PacketHistory.size(); index++) {
            packID historyEntry = call PacketHistory.get(index);

            // Match both source and sequence to identify duplicates
            if (historyEntry.src == sourceID && historyEntry.seq == sequenceNum) {
                return TRUE;
            }
        }
        return FALSE;
    }

    // Validate whether the received packet should be processed or dropped
    bool packetIsValid(pack* packet) {
        if (packetIsDuplicate(packet->src, packet->seq)) {
            dbg(FLOODING_CHANNEL, "Duplicate detected. Packet discarded.\n");
            return FALSE;
        }
        return TRUE;
    }

    // Flood the packet to all nodes in the network
    void initiateFlood(pack* packet) {
        if (packet->dest != AM_BROADCAST_ADDR && packet->src != TOS_NODE_ID) {
            dbg(FLOODING_CHANNEL, "Received from %d, destination: %d. Initiating flood...\n", packet->src, packet->dest);
        } 
        call PacketSender.send(*packet, AM_BROADCAST_ADDR); // Broadcast packet
    }

    // Main flood command that initiates packet flooding if valid
    command void Flooding.flood(pack* packet) {
        if (packetIsValid(packet)) {
            packID packetRecord;
            packetRecord.src = packet->src;
            packetRecord.seq = packet->seq;
            
            // Store packet ID in history to prevent re-flooding duplicates
            call PacketHistory.pushbackdrop(packetRecord);

            // Begin the flooding process for this packet
            initiateFlood(packet);
        }
    }
}
