// Auth: Zaid Laffta
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
    uint16_t routesPerPacket = 1; // Number of routes that can fit in a packet's payload

    // Generates a random number between 'min' and 'max'
    uint32_t randNum(uint32_t min, uint32_t max) {
        return ( call Random.rand16() % (max-min+1) ) + min;
    }

    // Checks if a destination is present in the routing table
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

    // Retrieves the route for the specified destination. Returns a '0' route if missing.
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

    // Removes the route associated with the specified destination
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

    // Updates an existing route with new information based on destination
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

    // Resets the 'route_changed' flag on all routes in the table
    void resetRouteUpdates() {
        uint16_t size = call RoutingTable.size();
        uint16_t i;

        for (i = 0; i < size; i++) {
            Route route = call RoutingTable.get(i);
            route.route_changed = FALSE;
            call RoutingTable.set(i, route);
        }
    }

    // Initiates a timer for a triggered update, randomized to avoid collisions
    void triggeredUpdate() {
        call TriggeredEventTimer.startOneShot( randNum(1000, 5000) );
    }

    // Decrements the TTL for the specified route and handles expired timers
    void decrementTimer(Route route) {
        route.TTL = route.TTL - 1;
        updateRoute(route);

        if (route.TTL == 0 && route.cost != ROUTE_MAX_COST) {
            uint16_t size = call RoutingTable.size();
            uint16_t i;

            route.TTL = ROUTE_GARBAGE_COLLECT;
            route.cost = ROUTE_MAX_COST;
            route.route_changed = TRUE;

            updateRoute(route);
            triggeredUpdate();

            // Mark dependent routes for garbage collection
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
    }

    // Decrements timers for all routes; if a timer expires, starts garbage collection
    void decrementRouteTimers() {
        uint16_t i;
        for (i = 0; i < call RoutingTable.size(); i++) {
            Route route = call RoutingTable.get(i);
            decrementTimer(route);
        }
    }

    // Marks the specified route as invalid and initiates timeout handling
    void invalidate(Route route) {
        route.TTL = 1;
        decrementTimer(route);
    }

    // Starts the routing process after neighbors are updated
    command void Routing.start() {
        if (call RoutingTable.size() == 0) {
            dbg(ROUTING_CHANNEL, "ERROR - Can't route with no neighbors! Make sure to updateNeighbors first.\n");
            return;
        }

        if (!call RegularTimer.isRunning()) {
            dbg(ROUTING_CHANNEL, "Initiating routing protocol...\n");
            call RegularTimer.startPeriodic( randNum(25000, 35000) );
        }
    }

    // Sends a packet based on routing table entries for the destination
    command void Routing.send(pack* msg) {
        if (!inTable(msg->dest)) {
            dbg(ROUTING_CHANNEL, "Cannot send packet from %d to %d: no connection\n", msg->src, msg->dest);
            return;
        }

        Route route = getRoute(msg->dest);
        if (route.cost == ROUTE_MAX_COST) {
            dbg(ROUTING_CHANNEL, "Cannot send packet from %d to %d: cost infinity\n", msg->src, msg->dest);
            return;
        }
        
        dbg(ROUTING_CHANNEL, "Routing Packet: src: %d, dest: %d, seq: %d, next_hop: %d, cost: %d\n", msg->src, msg->dest, msg->seq, route.next_hop, route.cost);
        call Sender.send(*msg, route.next_hop);
    }

    // Processes a received routing packet, updating routes as needed
    command void Routing.receive(pack* routing_packet) {
        uint16_t i;

        for (i = 0; i < routesPerPacket; i++) {
            Route current_route;
            memcpy(&current_route, (&routing_packet->payload) + i * ROUTE_SIZE, ROUTE_SIZE);

            if (current_route.dest == 0 || current_route.dest == TOS_NODE_ID) {
                continue; // Ignore blank or self-routes
            }

            if (current_route.cost > ROUTE_MAX_COST) {
                dbg(ROUTING_CHANNEL, "ERROR - Invalid route cost of %d from %d\n", current_route.cost, current_route.dest);
                continue;
            }

            current_route.cost = min(current_route.cost + 1, ROUTE_MAX_COST);

            if (!inTable(current_route.dest)) {
                if (current_route.cost == ROUTE_MAX_COST) continue; // Skip dead route

                current_route.dest = routing_packet->dest;
                current_route.next_hop = routing_packet->src;
                current_route.TTL = ROUTE_TIMEOUT;
                current_route.route_changed = TRUE;

                call RoutingTable.pushback(current_route);
                triggeredUpdate();
            } else {
                Route existing_route = getRoute(current_route.dest);

                if (existing_route.next_hop == routing_packet->src) {
                    existing_route.TTL = ROUTE_TIMEOUT;
                }

                if ((existing_route.next_hop == routing_packet->src && existing_route.cost != current_route.cost)
                    || existing_route.cost > current_route.cost) {

                    existing_route.next_hop = routing_packet->src;
                    existing_route.TTL = ROUTE_TIMEOUT;
                    existing_route.route_changed = TRUE;

                    if (current_route.cost == ROUTE_MAX_COST && existing_route.cost != ROUTE_MAX_COST) {
                        existing_route.TTL = ROUTE_GARBAGE_COLLECT;
                    }

                    existing_route.cost = current_route.cost;
                } else {
                    existing_route.TTL = ROUTE_TIMEOUT;
                }

                updateRoute(existing_route);
            }
        }
    }

    // Updates the routing table with new neighbor information
    command void Routing.updateNeighbors(uint32_t* neighbors, uint16_t numNeighbors) {
        uint16_t i, j;
        uint16_t size = call RoutingTable.size();

        for (i = 0; i < numNeighbors; i++) {
            Route route = {neighbors[i], 1, neighbors[i], ROUTE_TIMEOUT, TRUE};

            if (inTable(route.dest)) {
                Route existing_route = getRoute(route.dest);
                if (existing_route.cost != route.cost) {
                    updateRoute(route);
                    triggeredUpdate();
                }
            } else {
                call RoutingTable.pushback(route);
                triggeredUpdate();
            }
        }

        for (i = 0; i < size; i++) {
            Route route = call RoutingTable.get(i);
            if (route.cost == ROUTE_MAX_COST) continue;

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

    // Prints the routing table in a 'destination, next hop, cost' format
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

    // Sends all changed routes to neighbors, run as a one-time timer event
    event void TriggeredEventTimer.fired() {
        uint16_t size = call RoutingTable.size();
        uint16_t packet_index = 0;
        pack msg;

        msg.src = TOS_NODE_ID;
        msg.TTL = 1;
        msg.protocol = PROTOCOL_DV;
        msg.seq = signal Routing.getSequence();

        memset((&msg.payload), '\0', PACKET_MAX_PAYLOAD_SIZE);

        for (uint16_t i = 0; i < size; i++) {
            Route route = call RoutingTable.get(i);

            if (route.route_changed) {
                memcpy((&msg.payload) + packet_index * ROUTE_SIZE, &route, ROUTE_SIZE);

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

    // Periodic timer to decrement TTL and send entire routing table to neighbors
    event void RegularTimer.fired() {
        uint16_t size = call RoutingTable.size();
        call TriggeredEventTimer.stop();
        decrementRouteTimers();

        for (uint16_t i = 0; i < size; i++) {
            Route route = call RoutingTable.get(i);
            route.route_changed = TRUE;
            updateRoute(route);
        }

        signal TriggeredEventTimer.fired();
    }
}
