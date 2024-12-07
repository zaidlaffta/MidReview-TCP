// Authored by: Zaid Laffta
// CSE 160 - Winter 2024

#include <Timer.h>
#include "../../includes/socket.h"
#include "../../includes/packet.h"
#include "../../includes/tcp_header.h"

module TransportP {
    provides interface Transport;

    uses interface Timer<TMilli> as SrcTimeout;
    uses interface Hashmap<socket_store_t> as SocketMap;
}

implementation {

    // Allocates a new socket, returning a socket descriptor if successful
    command socket_t socket() {
        uint32_t* existing_fds = call SocketMap.getKeys();
        uint16_t map_size = call SocketMap.size();
        socket_t fd;
        uint8_t idx;

        if (map_size >= MAX_NUM_OF_SOCKETS) {
            dbg(TRANSPORT_CHANNEL, "[Error] socket: Max sockets reached\n");
            return NULL;
        }

        // Look for an available file descriptor (starting from 1)
        for (fd = 1; fd > 0; fd++) {
            bool is_used = FALSE;
            for (idx = 0; idx < map_size; idx++) {
                if (fd == (socket_t)existing_fds[idx]) {
                    is_used = TRUE;
                    break;
                }
            }

            // Found a free descriptor, initialize it
            if (!is_used) {
                socket_store_t new_socket;

                new_socket.flag = FALSE;               // Not in use
                new_socket.state = CLOSED;
                new_socket.src = TOS_NODE_ID;
                new_socket.dest.port = ROOT_SOCKET_PORT;
                new_socket.dest.addr = ROOT_SOCKET_ADDR;
                new_socket.lastWritten = 0;
                new_socket.lastAck = 0;
                new_socket.lastSent = 0;
                new_socket.lastRead = 0;
                new_socket.leastRcvd = 0;
                new_socket.nextExpected = 0;
                new_socket.RTT = 0;
                new_socket.effectiveWindow = 0;

                // Clear send and receive buffers
                memset(&new_socket.sendBuff, '\0', SOCKET_BUFFER_SIZE);
                memset(&new_socket.rcvdBuff, '\0', SOCKET_BUFFER_SIZE);

                call SocketMap.insert(fd, new_socket);
                return fd;
            }
        }

        dbg(TRANSPORT_CHANNEL, "[Error] socket: No valid file descriptor found\n");
        return NULL;
    }

    // Binds a socket to a provided address
    command error_t bind(socket_t fd, socket_addr_t *addr) {
        if (!fd) {
            dbg(TRANSPORT_CHANNEL, "[Error] bind: Invalid fd\n");
            return FAIL;
        }

        socket_store_t socket = call SocketMap.get(fd);
        socket.src = addr->port;
        call SocketMap.insert(fd, socket);
        return SUCCESS;
    }

    // Accepts an incoming connection request on a listening socket
    command socket_t accept(socket_t fd) {
        if (!fd) {
            dbg(TRANSPORT_CHANNEL, "[Error] accept: Invalid server fd\n");
            return NULL;
        }

        socket_store_t socket = call SocketMap.get(fd);

        if (socket.flag) {
            dbg(TRANSPORT_CHANNEL, "[Error] accept: Socket already in use\n");
            return NULL;
        }

        socket_t new_fd = call Transport.socket();

        if (!new_fd) {
            dbg(TRANSPORT_CHANNEL, "[Error] accept: Failed to allocate new fd\n");
            return NULL;
        }

        socket.flag = TRUE;
        socket.dest.addr = 0; // FIXME: Obtain address dynamically
        socket.dest.port = 0;
        call SocketMap.insert(new_fd, socket);

        return new_fd;
    }

    // Writes data from buffer to socket's send buffer
    command uint16_t write(socket_t fd, uint8_t *buff, uint16_t bufflen) {
        if (!fd) {
            dbg(TRANSPORT_CHANNEL, "[Error] write: Invalid fd\n");
            return NULL;
        }

        socket_store_t socket = call SocketMap.get(fd);
        uint8_t buffer_start = socket.lastWritten + 1;

        // Check if buffer has enough space to fit the data
        if (bufflen < SOCKET_BUFFER_SIZE - buffer_start) {
            memcpy(socket.sendBuff + buffer_start, buff, bufflen);
            socket.lastWritten = buffer_start + bufflen;
            call SocketMap.insert(fd, socket);
            return bufflen;
        }

        // Handle cases where buffer size exceeds capacity (not implemented)
        return NULL;
    }

    // Processes an incoming TCP packet
    command error_t receive(pack* package) {
        tcp_header header;
        memcpy(&header, &package->payload, PACKET_MAX_PAYLOAD_SIZE);
        // Process the packet further as needed (not fully implemented)
    }

    // Reads data from socket's receive buffer into provided buffer
    command uint16_t read(socket_t fd, uint8_t *buff, uint16_t bufflen) {
        if (!fd) {
            dbg(TRANSPORT_CHANNEL, "[Error] read: Invalid fd\n");
            return NULL;
        }

        socket_store_t socket = call SocketMap.get(fd);
        uint8_t buffer_start = socket.lastWritten + 1;

        // Check if buffer has enough space to read the data
        if (bufflen < SOCKET_BUFFER_SIZE - buffer_start) {
            memcpy(socket.sendBuff + buffer_start, buff, bufflen);
            socket.lastWritten = buffer_start + bufflen;
            call SocketMap.insert(fd, socket);
            return bufflen;
        }

        // Handle cases where buffer size exceeds capacity (not implemented)
        return NULL;
    }

    // Initiates a connection to a remote address
    command error_t connect(socket_t fd, socket_addr_t *addr) {
        if (!fd) {
            dbg(TRANSPORT_CHANNEL, "[Error] connect: Invalid fd\n");
            return FAIL;
        }

        socket_store_t socket = call SocketMap.get(fd);

        // Connection logic to be implemented here
        dbg(TRANSPORT_CHANNEL, "Error: Connect function not yet implemented\n");
    }

    // Closes the specified socket
    command error_t close(socket_t fd) {
        dbg(TRANSPORT_CHANNEL, "Error: Close function not yet implemented\n");
    }

    // Releases the specified socket (forceful disconnect)
    command error_t release(socket_t fd) {
        dbg(TRANSPORT_CHANNEL, "Error: Release function not yet implemented\n");
    }

    // Puts the socket into a listening state, awaiting connections
    command error_t listen(socket_t fd) {
        dbg(TRANSPORT_CHANNEL, "Error: Listen function not yet implemented\n");
    }
}
