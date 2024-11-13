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
    uint16_t routesPerPacket = 1;

    
    uint32_t randNum(uint32_t min, uint32_t max) {
        return ( call Random.rand16() % (max-min+1) ) + min;
    }

   
    // Checks if a given destination exists in the routing table
bool inTable(uint16_t dest) {
    uint16_t size = call RoutingTable.size(); // Get the size of the routing table
    uint16_t i;
    bool isInTable = FALSE; // Initialize a flag to indicate if the destination is in the table

    // Loop through each route in the table
    for (i = 0; i < size; i++) {
        Route route = call RoutingTable.get(i); // Get the route at the current index

        // Check if the route's destination matches the target destination
        if (route.dest == dest) {
            isInTable = TRUE; // Set flag to true if a match is found
            break; // Exit the loop as the destination is found
        }
    }

    return isInTable; // Return whether the destination is in the table
}

   // Retrieves the route for a given destination from the routing table
Route getRoute(uint16_t dest) {
    Route return_route; // Initialize a variable to store the found route
    uint16_t size = call RoutingTable.size(); // Get the size of the routing table
    uint16_t i;

    // Loop through each route in the routing table
    for (i = 0; i < size; i++) {
        Route route = call RoutingTable.get(i); // Get the route at the current index

        // Check if the route's destination matches the target destination
        if (route.dest == dest) {
            return_route = route; // Set the return route to the matching route
            break; // Exit the loop as the matching route has been found
        }
    }

    return return_route; // Return the found route (or a default route if none matched)
}

   // Removes a route for a specified destination from the routing table
void removeRoute(uint16_t dest) {
    uint16_t size = call RoutingTable.size(); // Get the current size of the routing table
    uint16_t i;

    // Loop through each route in the routing table
    for (i = 0; i < size; i++) {
        Route route = call RoutingTable.get(i); // Retrieve the route at the current index

        // Check if the route's destination matches the target destination
        if (route.dest == dest) {
            call RoutingTable.remove(i); // Remove the matching route from the table
            return; // Exit the function after successfully removing the route
        }
    }

    // Log an error if the specified destination was not found in the routing table
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

// Resets the 'route_changed' flag for all routes in the routing table
void resetRouteUpdates() {
    uint16_t size = call RoutingTable.size(); // Get the current size of the routing table
    uint16_t i;

    // Loop through each route in the routing table
    for (i = 0; i < size; i++) {
        Route route = call RoutingTable.get(i); // Retrieve the route at the current index
        route.route_changed = FALSE; // Reset the 'route_changed' flag to indicate no recent changes
        call RoutingTable.set(i, route); // Update the route in the table with the reset flag
    }
}

 
    void triggeredUpdate() {
        call TriggeredEventTimer.startOneShot( randNum(500, 3000) );
    }


    // Decrements the TTL (Time-To-Live) of a given route, initiating garbage collection if expired
void decrementTimer(Route route) {
    route.TTL = route.TTL - 1; // Decrease the TTL of the route by 1
    updateRoute(route); // Update the modified route in the routing table

    // Check if the route TTL has expired and if it is still a valid route
    if (route.TTL == 0 && route.cost != ROUTE_MAX_COST) {
        uint16_t size = call RoutingTable.size();
        uint16_t i;

        // Set the route to "garbage collection" mode
        route.TTL = ROUTE_GARBAGE_COLLECT; // Set TTL for garbage collection duration
        route.cost = ROUTE_MAX_COST; // Mark the route cost as maximum to indicate unreachability
        route.route_changed = TRUE; // Flag the route as changed

        updateRoute(route); // Update the route in the routing table
        triggeredUpdate(); // Trigger an update to notify neighbors of the route change

        // Check all other routes to update those that use the same next hop
        for (i = 0; i < size; i++) {
            Route current_route = call RoutingTable.get(i);

            // If the route depends on the same next hop, mark it for garbage collection as well
            if (current_route.next_hop == route.next_hop && current_route.cost != ROUTE_MAX_COST) {
                current_route.TTL = ROUTE_GARBAGE_COLLECT; // Set TTL for garbage collection
                current_route.cost = ROUTE_MAX_COST; // Set cost to maximum
                current_route.route_changed = TRUE; // Mark as changed

                updateRoute(current_route); // Update the dependent route in the table
                triggeredUpdate(); // Trigger an update for this route change
            }
        }
    }
}

   // Decrements the TTL for all routes in the routing table
void decrementRouteTimers() {
    uint16_t i;

    // Loop through each route in the table and decrement its TTL
    for (i = 0; i < call RoutingTable.size(); i++) {
        Route route = call RoutingTable.get(i);
        decrementTimer(route); // Apply TTL decrement and potential garbage collection
    }
}

// Marks a specific route as invalid by setting its TTL to 1 and initiating a decrement
void invalidate(Route route) {
    route.TTL = 1; // Set the TTL to 1 to mark it as invalid
    decrementTimer(route); // Call decrement to process the invalidation
}

// Starts the routing protocol, ensuring neighbors are updated first and initiating the periodic timer
command void Routing.start() {
    // Check if there are any neighbors; if not, log an error and return
    if (call RoutingTable.size() == 0) {
        dbg(ROUTING_CHANNEL, "ERROR - Can't route with no neighbors! Make sure to updateNeighbors first.\n");
        return;
    }

    // Start the regular timer if it's not already running
    if (!call RegularTimer.isRunning()) {
        dbg(ROUTING_CHANNEL, "Initiating routing protocol...\n");
        call RegularTimer.startPeriodic(randNum(25000, 35000)); // Set timer with a random interval
    }
}

// Sends a packet based on the destination, using the routing table to determine the next hop
command void Routing.send(pack* msg) {
    Route route;

    // Check if the destination is in the routing table
    if (!inTable(msg->dest)) {
        dbg(ROUTING_CHANNEL, "Cannot send packet from %d to %d: no connection\n", msg->src, msg->dest);
        return; // Exit if there is no route to the destination
    }

    // Retrieve the route information for the specified destination
    route = getRoute(msg->dest);

    // Check if the route cost is set to infinity, indicating an unreachable route
    if (route.cost == ROUTE_MAX_COST) {
        dbg(ROUTING_CHANNEL, "Cannot send packet from %d to %d: cost infinity\n", msg->src, msg->dest);
        return; // Exit if the route is unreachable
    }

    // Log the packet details and the routing decision
    dbg(ROUTING_CHANNEL, "Routing Packet: src: %d, dest: %d, seq: %d, next_hop: %d, cost: %d\n", 
        msg->src, msg->dest, msg->seq, route.next_hop, route.cost);

    // Send the packet to the next hop determined by the routing table
    call Sender.send(*msg, route.next_hop);
}


// Processes a received routing packet, updating or adding routes based on its content
command void Routing.receive(pack* routing_packet) {
    uint16_t i;

    // Loop through each route entry in the packet payload
    for (i = 0; i < routesPerPacket; i++) {
        Route current_route;
        // Copy the route entry from the payload into current_route
        memcpy(&current_route, (&routing_packet->payload) + i * ROUTE_SIZE, ROUTE_SIZE);
        
        // Skip if the route destination is 0 (invalid or blank)
        if (current_route.dest == 0) {
            continue;
        }

        // Skip if the route destination is the current node (self-route)
        if (current_route.dest == TOS_NODE_ID) {
            continue;
        }

        // Skip if the route cost is above the maximum allowable cost
        if (current_route.cost > ROUTE_MAX_COST) {
            dbg(ROUTING_CHANNEL, "ERROR - Invalid route cost of %d from %d\n", current_route.cost, current_route.dest);
            continue;
        }

        // Apply "Split Horizon with Poison Reverse" by setting cost to max if next hop is self
        if (current_route.next_hop == TOS_NODE_ID) {
            current_route.cost = ROUTE_MAX_COST;
        }

        // Increment the route cost, capping at ROUTE_MAX_COST
        current_route.cost = min(current_route.cost + 1, ROUTE_MAX_COST);

        // Check if the route destination is not currently in the routing table
        if (!inTable(current_route.dest)) {
            // Skip adding if the route cost is max, indicating it is unreachable
            if (current_route.cost == ROUTE_MAX_COST) {
                continue;
            }

            // Set the current route's destination, next hop, and TTL
            current_route.dest = routing_packet->dest;
            current_route.next_hop = routing_packet->src;
            current_route.TTL = ROUTE_TIMEOUT;
            current_route.route_changed = TRUE;

            // Add the new route to the routing table
            call RoutingTable.pushback(current_route);

            // Trigger an update to inform neighbors of the new route
            triggeredUpdate();
            continue;
        } 

        // If the route already exists in the routing table, update it if necessary
        else {
            Route existing_route = getRoute(current_route.dest);

            // Reset TTL if the route has the same next hop
            if (existing_route.next_hop == routing_packet->src) {
                existing_route.TTL = ROUTE_TIMEOUT;
            }

            // Update route if there is a new cost or a cheaper path
            if ((existing_route.next_hop == routing_packet->src
                && existing_route.cost != current_route.cost)
                || existing_route.cost > current_route.cost) {
                
                existing_route.next_hop = routing_packet->src;
                existing_route.TTL = ROUTE_TIMEOUT;
                existing_route.route_changed = TRUE;

                // Start garbage collection timer if route becomes unreachable
                if (current_route.cost == ROUTE_MAX_COST &&
                    existing_route.cost != ROUTE_MAX_COST) {
                    existing_route.TTL = ROUTE_GARBAGE_COLLECT;
                }

                existing_route.cost = current_route.cost;
            
            } else {
                // If no cost update, just reset TTL
                existing_route.TTL = ROUTE_TIMEOUT;
            }

            // Update the existing route in the routing table
            updateRoute(existing_route);
        } 
    }
}


    command void Routing.updateNeighbors(uint32_t* neighbors, uint16_t numNeighbors) {
        uint16_t i;
        uint16_t size = call RoutingTable.size();

        for (i = 0; i < numNeighbors; i++) {
            Route route;

            route.dest = neighbors[i];
            route.cost = 1;
            route.next_hop = neighbors[i];
            route.TTL = ROUTE_TIMEOUT;
            route.route_changed = TRUE;

            if (inTable(route.dest)) {
                Route existing_route = getRoute(route.dest);

                if (existing_route.cost != route.cost) {
                    updateRoute(route);
                    triggeredUpdate();
                }
            }
            else {
                call RoutingTable.pushback(route);
                triggeredUpdate();
            }
        }

        for (i = 0; i < size; i++) {
            Route route = call RoutingTable.get(i);
            uint16_t j;

            if (route.cost == ROUTE_MAX_COST) {
                continue;
            }

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

        dbg(GENERAL_CHANNEL, "----- dest\tnext hop\tcost ------\n");
        for (i = 0; i < size; i++) {
            Route route = call RoutingTable.get(i);
            dbg(GENERAL_CHANNEL, "--- %d\t\t%d\t\t\t%d\n", route.dest, route.next_hop, route.cost);
        }
        dbg(GENERAL_CHANNEL, "----------------------------------\n");
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


    event void RegularTimer.fired() {
        uint16_t size = call RoutingTable.size();
        uint16_t i;
        call TriggeredEventTimer.stop();
        decrementRouteTimers();
        for (i = 0; i < size; i++) {
            Route route = call RoutingTable.get(i);
            route.route_changed = TRUE;
            updateRoute(route);
        }

        signal TriggeredEventTimer.fired();
    }
}