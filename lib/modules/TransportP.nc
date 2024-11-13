// Auth: Zaid Laffta
// Winter 2024
// CSE 160

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

    // Allocates a new socket if available
    command socket_t socket() {
        uint32_t* fds = call SocketMap.getKeys(); 
        uint16_t size = call SocketMap.size();
        socket_t fd;
        uint8_t i;

        if (size == MAX_NUM_OF_SOCKETS) {
            dbg(TRANSPORT_CHANNEL, "[Error] socket: No room for new socket\n");
            return NULL;
        }

        // Find unused file descriptor greater than 0
        for (fd = 1; fd > 0; fd++) {
            bool found = FALSE;
            for (i = 0; i < size; i++) {
                if (fd != (socket_t)fds[i]) {
                    found = TRUE;
                }
            }

            // Initialize and return available socket
            if (!found) {
                socket_store_t socket;

                socket.flag = FALSE;
                socket.state = CLOSED;
                socket.src = TOS_NODE_ID;
                socket.dest.port = ROOT_SOCKET_PORT;
                socket.dest.addr = ROOT_SOCKET_ADDR;
                socket.lastWritten = 0;
                socket.lastAck = 0;
                socket.lastSent = 0;
                socket.lastRead = 0;
                socket.leastRcvd = 0;
                socket.nextExpected = 0;
                socket.RTT = 0;
                socket.effectiveWindow = 0;
                memset(&socket.sendBuff, '\0', SOCKET_BUFFER_SIZE);
                memset(&socket.rcvdBuff, '\0', SOCKET_BUFFER_SIZE);

                call SocketMap.insert(fd, socket);
                return fd;
            }      
        }

        dbg(TRANSPORT_CHANNEL, "[Error] socket: No valid next file descriptor found\n");
        return NULL;
    }

    // Binds a socket to a specified address
    command error_t bind(socket_t fd, socket_addr_t *addr) {
        socket_store_t socket = call SocketMap.get(fd);

        if (!fd) {
            dbg(TRANSPORT_CHANNEL, "[Error] bind: Invalid file descriptor\n");
            return FAIL;
        }

        socket.src = addr->port;
        call SocketMap.insert(fd, socket);
        return SUCCESS;
    }

    // Accepts an incoming connection on a listening socket
    command socket_t accept(socket_t fd) {
        socket_store_t socket;
        socket_t new_fd = call Transport.socket();

        if (!fd) {
            dbg(TRANSPORT_CHANNEL, "[Error] accept: Invalid server file descriptor\n");
            return NULL;
        }

        socket = call SocketMap.get(fd);

        if (socket.flag) {
            dbg(TRANSPORT_CHANNEL, "[Error] accept: Root socket in use\n");
            return NULL;
        }

        if (!new_fd) {
            dbg(TRANSPORT_CHANNEL, "[Error] accept: Invalid new file descriptor\n");
            return NULL;
        }

        socket.flag = TRUE;
        socket.dest.addr = 0;
        socket.dest.port = 0;
        call SocketMap.insert(new_fd, socket);
        return new_fd;
    }

    // Writes data to the socket's send buffer
    command uint16_t write(socket_t fd, uint8_t *buff, uint16_t bufflen) {
        socket_store_t socket;

        if (!fd) {
            dbg(TRANSPORT_CHANNEL, "[Error] write: Invalid file descriptor\n");
            return NULL;
        }

        socket = call SocketMap.get(fd);
        uint8_t start = socket.lastWritten + 1;

        // Write buffer to send buffer if space permits
        if (bufflen < SOCKET_BUFFER_SIZE - start) {
            memcpy(socket.sendBuff + start, buff, bufflen);
            socket.lastWritten = start + bufflen;
            call SocketMap.insert(fd, socket);
            return bufflen;
        }

        return NULL;
    }

    // Handles an incoming TCP packet
    command error_t receive(pack* package) {
        tcp_header header;
        memcpy(&header, &package->payload, PACKET_MAX_PAYLOAD_SIZE);
    }

    // Reads data from the socket's receive buffer
    command uint16_t read(socket_t fd, uint8_t *buff, uint16_t bufflen) {
        socket_store_t socket;

        if (!fd) {
            dbg(TRANSPORT_CHANNEL, "[Error] read: Invalid file descriptor\n");
            return NULL;
        }

        socket = call SocketMap.get(fd);

        uint8_t start = socket.lastWritten + 1;

        // Read data into buffer if space permits
        if (bufflen < SOCKET_BUFFER_SIZE - start) {
            memcpy(socket.sendBuff + start, buff, bufflen);
            socket.lastWritten = start + bufflen;
            call SocketMap.insert(fd, socket);
            return bufflen;
        }

        return NULL;
    }

    // Attempts to connect to a remote address
    command error_t connect(socket_t fd, socket_addr_t * addr) {
        socket_store_t socket;
        if (!fd) {
            dbg(TRANSPORT_CHANNEL, "[Error] connect: Invalid file descriptor\n");
            return FAIL;
        }

        socket = SocketMap.get(fd);

        dbg(TRANSPORT_CHANNEL, "Error: Connect not implemented\n");
    }

    // Closes the socket
    command error_t close(socket_t fd) {
        dbg(TRANSPORT_CHANNEL, "Error: Close not implemented\n");
    }

    // Hard closes the socket (forceful disconnect)
    command error_t release(socket_t fd) {
        dbg(TRANSPORT_CHANNEL, "Error: Release not implemented\n");
    }

    // Puts the socket in listening mode
    command error_t listen(socket_t fd) {
        dbg(TRANSPORT_CHANNEL, "Error: Listen not implemented\n");
    }
}
