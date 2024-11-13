//Auth: Zaid Laffta
// Winter 2024
// CSE 160

#include <Timer.h>
#include "../../includes/route.h"
#include "../../includes/packet.h"

#undef min
#define min(a,b) ((a) < (b) ? (a) : (b))

module RoutingP {
    provides interface Routing;

    uses interface List<Route> as RoutingTable;
    uses interface SimpleSend as Sender;
    uses interface Random;
    uses interface Timer<TMilli> as TriggeredEventTimer;
    uses interface Timer<TMilli> as RegularTimer;
}

implementation {
    /** The number of router that can fit in a packet's payload */
    uint16_t routesPerPacket = 1;

    
    uint32_t randNum(uint32_t min, uint32_t max) {
        return ( call Random.rand16() % (max-min+1) ) + min;
    }

   
    bool inTable(uint16_t dest) {
        uint16_t size = call RoutingTable.size();
        uint16_t i;
        bool isInTable = FALSE;

        for (i = 0; i < size; i++) {
            Route route = call RoutingTable.get(i);

            if (route.dest == dest) {
                isInTable = TRUE;
                break;
            }
        }

        return isInTable;
    }

    
    Route getRoute(uint16_t dest) {
        Route return_route;
        uint16_t size = call RoutingTable.size();
        uint16_t i;

        for (i = 0; i < size; i++) {
            Route route = call RoutingTable.get(i);

            if (route.dest == dest) {
                return_route = route;
                break;
            }
        }

        return return_route;
    }

   
    void removeRoute(uint16_t dest) {
        uint16_t size = call RoutingTable.size();
        uint16_t i;

        for (i = 0; i < size; i++) {
            Route route = call RoutingTable.get(i);

            if (route.dest == dest) {
                call RoutingTable.remove(i);
                return;
            }
        }

        dbg(ROUTING_CHANNEL, "ERROR - Can't remove nonexistent route %d\n", dest);
    }

   
    void updateRoute(Route route) {
        uint16_t size = call RoutingTable.size();
        uint16_t i;

        for (i = 0; i < size; i++) {
            Route current_route = call RoutingTable.get(i);

            if (route.dest == current_route.dest) {
                call RoutingTable.set(i, route);
                return;
            }
        }

        dbg(ROUTING_CHANNEL, "ERROR - Update attempt on nonexistent route %d\n", route.dest);
    }


    void resetRouteUpdates() {
        uint16_t size = call RoutingTable.size();
        uint16_t i;

        for (i = 0; i < size; i++) {
            Route route = call RoutingTable.get(i);
            route.route_changed = FALSE;
            call RoutingTable.set(i, route);
        }
    }

 
    void triggeredUpdate() {
        call TriggeredEventTimer.startOneShot( randNum(1000, 5000) );
    }


    void decrementTimer(Route route) {
        route.TTL = route.TTL-1;
        updateRoute(route);

        // Timeout timer expired, start garbage collection timer
        if (route.TTL == 0 && route.cost != ROUTE_MAX_COST) {
            uint16_t size = call RoutingTable.size();
            uint16_t i;

            route.TTL = ROUTE_GARBAGE_COLLECT;
            route.cost = ROUTE_MAX_COST;
            route.route_changed = TRUE;

            updateRoute(route);
            triggeredUpdate();

            // Invalidate routes that had a next hop with that node
            for (i = 0; i < size; i++) {
                Route current_route = call RoutingTable.get(i);

                if (current_route.next_hop == route.next_hop && current_route.cost != ROUTE_MAX_COST) {
                    current_route.TTL = ROUTE_GARBAGE_COLLECT;
                    current_route.cost = ROUTE_MAX_COST;
                    current_route.route_changed = TRUE;

                    updateRoute(current_route);
                    triggeredUpdate();
                }
            }
        }
        // Garbage collection timer expired, remove route
        // else if (route.TTL == 0 && route.cost == ROUTE_MAX_COST) {
        //     removeRoute(route.dest);
        // }     
    }


    void decrementRouteTimers() {
        uint16_t i;

        for (i = 0; i < call RoutingTable.size(); i++) {
            Route route = call RoutingTable.get(i);

            decrementTimer(route);
        }
    }


    void invalidate(Route route) {
        route.TTL = 1;
        decrementTimer(route);
    }


    command void Routing.start() {
        if (call RoutingTable.size() == 0) {
            dbg(ROUTING_CHANNEL, "ERROR - Can't route with no neighbors! Make sure to updateNeighbors first.\n");
            return;
        }

        if (!call RegularTimer.isRunning()) {
            dbg (ROUTING_CHANNEL, "Intiating routing protocol...\n");
            call RegularTimer.startPeriodic( randNum(25000, 35000) );
        }
    }


    command void Routing.send(pack* msg) {
        Route route;

        if (!inTable(msg->dest)) {
            dbg(ROUTING_CHANNEL, "Cannot send packet from %d to %d: no connection\n", msg->src, msg->dest);
            return;
        }

        route = getRoute(msg->dest);

        if (route.cost == ROUTE_MAX_COST) {
            dbg(ROUTING_CHANNEL, "Cannot send packet from %d to %d: cost infinity\n", msg->src, msg->dest);
            return;
        }
        
        dbg(ROUTING_CHANNEL, "Routing Packet: src: %d, dest: %d, seq: %d, next_hop: %d, cost: %d\n", msg->src, msg->dest, msg->seq, route.next_hop, route.cost);

        call Sender.send(*msg, route.next_hop);
    }


    command void Routing.receive(pack* routing_packet) {
        uint16_t i;

        // Iterate over each route in the payload
        for (i = 0; i < routesPerPacket; i++) {
            Route current_route;
            memcpy(&current_route, (&routing_packet->payload) + i*ROUTE_SIZE, ROUTE_SIZE);
            
            // Blank route
            if (current_route.dest == 0) {
                continue;
            }

            // Don't need to add yourself
            if (current_route.dest == TOS_NODE_ID) {
                continue;
            }

            // Cost should never be higher than the maximum
            if (current_route.cost > ROUTE_MAX_COST) {
                dbg(ROUTING_CHANNEL, "ERROR - Invalid route cost of %d from %d\n", current_route.cost, current_route.dest);
                continue;
            }

            // Split Horizon w/ Poison Reverse
            // Done at recieving end because packets are sent to AM_BROADCAST_ADDR
            if (current_route.next_hop == TOS_NODE_ID) {
                current_route.cost = ROUTE_MAX_COST;
            }

            // Cap the cost at ROUTE_MAX_COST (default: 16)
            current_route.cost = min(current_route.cost + 1, ROUTE_MAX_COST);

            // No existing route
            if (!inTable(current_route.dest)) {
                // No need to add a new entry for a dead route
                if (current_route.cost == ROUTE_MAX_COST) {
                    continue;
                }

                current_route.dest = routing_packet->dest;
                current_route.next_hop = routing_packet->src;
                current_route.TTL = ROUTE_TIMEOUT;
                current_route.route_changed = TRUE;

                call RoutingTable.pushback(current_route);

                triggeredUpdate();
                continue;
            } 

            // Route Already Exists
            else {
                Route existing_route = getRoute(current_route.dest);

                // Update to existing route, reset TTL
                if (existing_route.next_hop == routing_packet->src) {
                    existing_route.TTL = ROUTE_TIMEOUT;
                }

                // Updated cost to existing route, or new cheaper cost
                if ((existing_route.next_hop == routing_packet->src
                    && existing_route.cost != current_route.cost)
                    || existing_route.cost > current_route.cost) {
                    
                    existing_route.next_hop = routing_packet->src;
                    existing_route.TTL = ROUTE_TIMEOUT;
                    existing_route.route_changed = TRUE;

                    // Dead route, start garbage collection timer
                    // Don't reset timer if cost was already ROUTE_MAX_COST
                    if (current_route.cost == ROUTE_MAX_COST &&
                        existing_route.cost != ROUTE_MAX_COST) {

                        existing_route.TTL = ROUTE_GARBAGE_COLLECT;
                    }

                    existing_route.cost = current_route.cost;
                
                // No updated cost, just reinitialize the timer
                } else {
                    existing_route.TTL = ROUTE_TIMEOUT;
                }

                updateRoute(existing_route);
            } 
        }
    }


    command void Routing.updateNeighbors(uint32_t* neighbors, uint16_t numNeighbors) {
        uint16_t i;
        uint16_t size = call RoutingTable.size();

        // Add neighbors to routing table
        for (i = 0; i < numNeighbors; i++) {
            Route route;

            route.dest = neighbors[i];
            route.cost = 1;
            route.next_hop = neighbors[i];
            route.TTL = ROUTE_TIMEOUT;
            route.route_changed = TRUE;

            if (inTable(route.dest)) {
                Route existing_route = getRoute(route.dest);

                // Existing node suddenly became a new neighbor
                if (existing_route.cost != route.cost) {
                    updateRoute(route);
                    triggeredUpdate();
                }
            }
            // New neighbor 
            else {
                call RoutingTable.pushback(route);
                triggeredUpdate();
            }
        }

        // Invalidate missing neighbors (in case one is dropped)
        for (i = 0; i < size; i++) {
            Route route = call RoutingTable.get(i);
            uint16_t j;

            // Don't immediately re-invalidate an invalid entry
            if (route.cost == ROUTE_MAX_COST) {
                continue;
            }

            // Invalidate the route if it's no longer a neighbor
            if (route.cost == 1) {
                bool isNeighbor = FALSE;

                for (j = 0; j < numNeighbors; j++) {
                    if (route.dest == neighbors[j]) {
                        isNeighbor = TRUE;
                        break;
                    }
                }

                if (!isNeighbor) {
                    invalidate(route);
                }
            }
        }
    }


    command void Routing.printRoutingTable() {
        uint16_t size = call RoutingTable.size();
        uint16_t i;

        dbg(GENERAL_CHANNEL, "--- dest\tnext hop\tcost ---\n");
        for (i = 0; i < size; i++) {
            Route route = call RoutingTable.get(i);
            dbg(GENERAL_CHANNEL, "--- %d\t\t%d\t\t\t%d\n", route.dest, route.next_hop, route.cost);
        }
        dbg(GENERAL_CHANNEL, "--------------------------------\n");
    }


    event void TriggeredEventTimer.fired() {
        uint16_t size = call RoutingTable.size();
        uint16_t packet_index = 0;
        uint16_t current_route;
        pack msg;

        msg.src = TOS_NODE_ID;
        msg.TTL = 1;
        msg.protocol = PROTOCOL_DV;
        msg.seq = signal Routing.getSequence();

        memset((&msg.payload), '\0', PACKET_MAX_PAYLOAD_SIZE);

        // Go through all routes looking for changed ones
        for (current_route = 0; current_route < size; current_route++) {
            Route route = call RoutingTable.get(current_route);

            msg.dest = route.dest;

            if (route.route_changed) {

                memcpy((&msg.payload) + packet_index*ROUTE_SIZE, &route, ROUTE_SIZE);

                packet_index++;
                if (packet_index == routesPerPacket) {
                    packet_index = 0;

                    call Sender.send(msg, AM_BROADCAST_ADDR);
                    memset((&msg.payload), '\0', PACKET_MAX_PAYLOAD_SIZE);
                }
            }
        }

        resetRouteUpdates();
    }


    // Timer event to decrement TTL and initiate updates
    event void RegularTimer.fired() {
        call TriggeredEventTimer.stop();
        decrementRouteTimers();
        for (uint16_t i = 0; i < call RoutingTable.size(); i++) {
            Route route = call RoutingTable.get(i);
            route.route_changed = TRUE;
            updateRoute(route);
        }
        signal TriggeredEventTimer.fired();
    }
}
