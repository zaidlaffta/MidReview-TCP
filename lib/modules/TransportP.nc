/**
 * ANDES Lab - University of California, Merced
 *
 * @author Raivat Alwar
 * @date   2023/10/29
 *
 */

#include <Timer.h>
#include "../../includes/CommandMsg.h"
#include "../../includes/command.h"
#include "../../includes/channels.h"
#include "../../includes/socket.h"
#include "../../includes/transportPacket.h"
#include "../../includes/packet.h"
#include "../../includes/protocol.h"

module TransportP{
    provides interface Transport;

    uses interface SimpleSend as TransportSend;
    // uses interface NeighborDiscovery;
    uses interface Flooding;
    uses interface Routing;
    uses interface ChatClient;

    uses interface Timer<TMilli> as ConnectionTimer; // temporaryname until connections are implemented
    uses interface Hashmap<uint32_t> as connectionTable;

    uses interface Timer<TMilli> as DataTimer; // printing out data when recieved

    uses interface Timer<TMilli> as WriteTimer; // writing the data into the sendbuff

    // these two are for reliability
    uses interface List<uint16_t> as seqTimer;
    uses interface Hashmap<uint16_t> as AckSeqHash;

    uses interface Hashmap<uint16_t> as SeqBuffPosHash;

    // this is for sliding window & process sequence
    // used interface Hashmap<uint16_t> as windowHash;
}

implementation{
    /* Transport.nc methods to implement:
     * socket(), bind(), accept(), write(), recieve(), read(), connect(), close(), release(), listen()
     */
    
    socket_store_t socketList[MAX_NUM_OF_SOCKETS]; // array of sockets (to make this usable when a node acts as a server and a client, we need to add a socket_store_t per port)
    uint16_t globalSeq = 1;
    uint16_t routingSeq = 1;
    uint16_t dataCount = 0;
    uint16_t newSeq = 401;
    uint8_t timerFlag = 0;
    uint8_t msgStatus; // 0: not completed | 1: completed (\r found)
    uint8_t methodCallStatus; // 0: not completed | 1: completed (ChatClient called)

    void clearTables(socket_t global_fd);

    event void WriteTimer.fired() { // client
        socket_t global_fd;
        uint32_t connectionID;
        // uint8_t tempData = 1;
        uint8_t i;
        uint8_t temp;

        //dbg(TRANSPORT_CHANNEL, "WriteTimer fired & timerFlag [%d]\n", timerFlag);

        connectionID = TOS_NODE_ID;
        global_fd = call connectionTable.get(connectionID);

        // if (timerFlag == 1)
        //     dbg(TRANSPORT_CHANNEL, "lastRead = [%d] | lastWritten = [%d] | sendBuff[lastWritten] = [%d] | maxByteTransfer [%d]\n", socketList[global_fd].lastRead, socketList[global_fd].lastWritten, socketList[global_fd].sendBuff[socketList[global_fd].lastWritten], socketList[global_fd].maxByteTransfer);

        if (timerFlag == 0){
            // writing into sendBuff
            //if (socketList[global_fd].maxByteTransfer <= SOCKET_BUFFER_SIZE){
                // socketList[global_fd].lastRead = -1;
                // dbg(TRANSPORT_CHANNEL, "lastRead as -1 [%d]\n", socketList[global_fd].lastRead);
                // dbg(TRANSPORT_CHANNEL, "lastRead as 0 [%d]\n", socketList[global_fd].lastRead + 1);
                socketList[global_fd].dataVal = 1;

            for(i=0; i<socketList[global_fd].maxByteTransfer; i++){
                if (i >= SOCKET_BUFFER_SIZE)
                    break;
                if (i == 0){
                    socketList[global_fd].sendBuff[i] = socketList[global_fd].dataVal;
                    socketList[global_fd].lastWritten = socketList[global_fd].lastWritten;
                }
                else {
                    socketList[global_fd].sendBuff[i] = socketList[global_fd].dataVal;
                    socketList[global_fd].lastWritten = socketList[global_fd].lastWritten + 1;
                }
                socketList[global_fd].dataVal = socketList[global_fd].dataVal + 1;
                // tempData++;
            }

            timerFlag = 1;
            //dbg(TRANSPORT_CHANNEL, "sendBuff[lastWritten] = [%d] | maxByteTransfer [%d]\n", socketList[global_fd].sendBuff[socketList[global_fd].lastWritten], socketList[global_fd].maxByteTransfer);
            // for(i=0; i<128; i++)
            //     dbg(TRANSPORT_CHANNEL, "WRITE | Pos[%d] Value[%d]\n", i, socketList[global_fd].sendBuff[i]);
        }
        else if (socketList[global_fd].sendBuff[socketList[global_fd].lastWritten] < socketList[global_fd].maxByteTransfer){ // goes in
            // dbg(GENERAL_CHANNEL, "IN ELSE IF\n");
            for(i=socketList[global_fd].lastWritten+1; i<=socketList[global_fd].lastWritten + SERV_WINDOW_SIZE; i++){
                
                if (i >= SOCKET_BUFFER_SIZE)
                    temp = i-SOCKET_BUFFER_SIZE;
                else
                    temp = i;

                // dbg(GENERAL_CHANNEL, "IN Loop i [%d] | Temp [%d] | Check[%d] | maxByteTransfer [%d]\n", i, temp, socketList[global_fd].lastRead + SERV_WINDOW_SIZE, socketList[global_fd].maxByteTransfer);
                // dbg(GENERAL_CHANNEL,"socketList[global_fd].sendBuff[temp] [%d]\n",socketList[global_fd].sendBuff[temp]);

                if (socketList[global_fd].sendBuff[temp] == 0){
                    dbg(GENERAL_CHANNEL, "Buff [temp] reset\n");
                    if (i == SOCKET_BUFFER_SIZE) {
                        socketList[global_fd].sendBuff[0] = socketList[global_fd].dataVal;
                        socketList[global_fd].lastWritten = 0;

                    }
                    else if (i > SOCKET_BUFFER_SIZE){
                        socketList[global_fd].sendBuff[i-SOCKET_BUFFER_SIZE] = socketList[global_fd].dataVal;
                        socketList[global_fd].lastWritten = i-SOCKET_BUFFER_SIZE;
                    }
                    else{
                        socketList[global_fd].sendBuff[temp] = socketList[global_fd].dataVal;
                        socketList[global_fd].lastWritten = temp;
                    }

                    socketList[global_fd].dataVal = socketList[global_fd].dataVal + 1;
                }
                //else
                //    break;
            }
        }

        // for(i = 0; i<socketList[global_fd].maxByteTransfer; i++){
        //     dbg(TRANSPORT_CHANNEL, "SENDBUFFPOS [%d] | Val [%d]\n", i, socketList[global_fd].sendBuff[i]);
        // }

        //call WriteTimer.stop();
    }

    event void DataTimer.fired() { // server side
        socket_t global_fd;
        uint8_t i;
        uint8_t j;
        uint8_t k;
        // uint8_t buff_len;
        char* message[SOCKET_BUFFER_SIZE];
        // uint16_t testMsg[SOCKET_BUFFER_SIZE];

        // dbg(ROUTING_CHANNEL, "DataTimer fired\n");

        for(i=0; i<MAX_NUM_OF_SOCKETS; i++){
            global_fd = (socket_t)i;
            
            if (socketList[global_fd].state == ESTABLISHED || socketList[global_fd].state == INIT_CLOSE){
                // dbg(TRANSPORT_CHANNEL, "[%d] <- fd exists | lastRead [%d] | window [%d]\n", i, socketList[global_fd].lastRead, socketList[global_fd].effectiveWindow);
                // Checking that the window's recieved buff all have values
                dbg(GENERAL_CHANNEL, "SERVER Printing   | socket [%d]\n", global_fd);
                for(j=0; j<socketList[global_fd].effectiveWindow; j++){
                    if (socketList[global_fd].lastRead + j >= 128){
                        if ((socketList[global_fd].rcvdBuff[socketList[global_fd].lastRead + j - 128] == 0) && (socketList[global_fd].state == ESTABLISHED)){
                            dbg(GENERAL_CHANNEL, "Bef Ret WrapAround | Array Pos [%d] | Array Pos + j - 128 [%d]\n", socketList[global_fd].lastRead, socketList[global_fd].lastRead + j - 128);
                            return;
                        }
                    }
                    else {
                        if ((socketList[global_fd].rcvdBuff[socketList[global_fd].lastRead + j] == 0) && (socketList[global_fd].state == ESTABLISHED)){
                            dbg(GENERAL_CHANNEL, "Bef Ret | Array Pos [%d] | Array Pos + j [%d]\n", socketList[global_fd].lastRead, socketList[global_fd].lastRead + j);
                            return;
                        }
                    }
                }
                // printing out the values in the window
                dbg(GENERAL_CHANNEL, "-------------------------------------------------------------------\n");
                k = 0;
                for(j=0; j<SOCKET_BUFFER_SIZE; j++){
                    if ((j > 0) && ((char*)socketList[global_fd].rcvdBuff[j-1] == '\n') && (socketList[global_fd].rcvdBuff[j] == 0)){
                        // dbg(CHAT_CHANNEL, "BREAKING OUT\n");
                        break;
                    }
                    if ((char*)socketList[global_fd].rcvdBuff[j] == '\n'){
                        msgStatus = 1;
                    }
                    message[j] = socketList[global_fd].rcvdBuff[j];
                    k++;
                    // testMsg[j] = socketList[global_fd].rcvdBuff[j];
                }

                if (msgStatus == 1 && methodCallStatus != 1){
                    // dbg(CHAT_CHANNEL, "MESSAGE ARRIVED IN TRANSPORT\n");
                    methodCallStatus = 1;
                    if (call ChatClient.checkCommandServ(message, "hello ") == 1)
                        call ChatClient.updateUsernames(message,48, socketList[global_fd].maxByteTransfer - 80, socketList[global_fd].src.addr); // Note: 80 = hello \n\r length
                    else if ((call ChatClient.checkCommandServ(message, "msg ") == 2)){
                        call ChatClient.broadcastMsg(message, j);
                        // while (call ChatClient.getBroadcastState() > 0)
                        //     call ChatClient.broadcastMsg(message, j);
                    }
                    else if (call ChatClient.checkCommandServ(message, "whisper ") == 3)
                        call ChatClient.whisper(message,64, k);
                    else if (call ChatClient.checkCommandServ(message, "listusr") == 4)
                        call ChatClient.listOfUsers(socketList[global_fd].src.addr);
                    else if (call ChatClient.checkCommandServ(message, "listUsrRply ") == 5)
                        call ChatClient.recievedList(message, j);
                }

                if (msgStatus == 1){
                    // for(j=0; j<socketList[global_fd].effectiveWindow; j++){
                    for(j=0; j<socketList[global_fd].maxByteTransfer-2; j++){
                        if (socketList[global_fd].lastRead + j >= 128) {
                            if (socketList[global_fd].rcvdBuff[socketList[global_fd].lastRead + j - 128] == 0){
                                dbg(GENERAL_CHANNEL, "Over 128 | Array Pos [%d] | Array Val [%d]\n", socketList[global_fd].lastRead + j - 128, (socketList[global_fd].rcvdBuff[socketList[global_fd].lastRead + j - 128]));
                                break;
                            }
                            //dbg(TRANSPORT_CHANNEL, "SERVER    | [IN NODE %d] READING DATA: %d\n", TOS_NODE_ID, socketList[global_fd].rcvdBuff[socketList[global_fd].lastRead + j - 128]);
                            // dbg(CHAT_CHANNEL, "SERVER    | [IN NODE %d] POS [%d] READING DATA: %c\n", TOS_NODE_ID, socketList[global_fd].lastRead + j - 128, socketList[global_fd].rcvdBuff[socketList[global_fd].lastRead + j - 128]); // test
                            socketList[global_fd].rcvdBuff[socketList[global_fd].lastRead + j - 128] = 0; // clearing buff (application finished clearing)
                        }
                        else {
                            if (socketList[global_fd].rcvdBuff[socketList[global_fd].lastRead + j] == 0){
                                dbg(GENERAL_CHANNEL, "Under 128 | Array Pos [%d] | Array Val [%d]\n", socketList[global_fd].lastRead + j, (socketList[global_fd].rcvdBuff[socketList[global_fd].lastRead + j]));
                                break;
                            }
                            //dbg(TRANSPORT_CHANNEL, "SERVER    | [IN NODE %d] READING DATA: %d\n", TOS_NODE_ID, socketList[global_fd].rcvdBuff[socketList[global_fd].lastRead + j]);
                            // dbg(CHAT_CHANNEL, "SERVER    | [IN NODE %d] POS [%d] READING DATA: %c\n", TOS_NODE_ID, socketList[global_fd].lastRead + j, socketList[global_fd].rcvdBuff[socketList[global_fd].lastRead + j]); // test
                            socketList[global_fd].rcvdBuff[socketList[global_fd].lastRead + j] = 0; // clearing buff (application finished clearing)
                        }
                        //dbg(TRANSPORT_CHANNEL, "%d, ", socketList[global_fd].rcvdBuff[socketList[global_fd].lastRead + j]);
                    }
                    // socketList[global_fd].lastRead = socketList[global_fd].lastRead + socketList[global_fd].effectiveWindow; // in the casethe effective window is larger (3 < 6 (win)) need to check and update
                    socketList[global_fd].lastRead = socketList[global_fd].lastRead + j;

                    j = j + 1;
                    while(j != 0){
                        if (call seqTimer.size() >= SOCKET_BUFFER_SIZE-socketList[global_fd].effectiveWindow){
                            dbg(TRANSPORT_CHANNEL, "SERVER    | Seq being popped out [%d]\n", call seqTimer.front());
                            dbg(TRANSPORT_CHANNEL, "SERVER    | Size seqTimer[%d] | Size seqBuffPosHash[%d]\n", call seqTimer.size(), call SeqBuffPosHash.size());
                            call SeqBuffPosHash.remove(call seqTimer.popfront());
                            dbg(TRANSPORT_CHANNEL, "SERVER    | Size of seqTimer [%d]\n", call seqTimer.size());
                        }
                        j--;
                    }
                    // socketList[global_fd].lastRead = socketList[global_fd].lastRead + j - 1;
                    
                    if (socketList[global_fd].lastRead >= 128)
                        socketList[global_fd].lastRead = socketList[global_fd].lastRead - 128;
                    dbg(GENERAL_CHANNEL, "-------------------------------------------------------------------\n");

                    // dbg(CHAT_CHANNEL, "PARAM[%c] | PARAM[%d]\n",(char*)socketList[global_fd].rcvdBuff, socketList[global_fd].src.addr);
                    // call ChatClient.updateUsernames(message,6, socketList[global_fd].maxByteTransfer - 8, socketList[global_fd].src.addr);
                }
            }

            // if (socketList[global_fd].state == ESTABLISHED || (socketList[global_fd].state == INIT_CLOSE) || (socketList[global_fd].state == CLOSED))
            //     dbg(GENERAL_CHANNEL, "EXPECTED STATE [%d] | CURRENT STATE [%d] | lastRead [%d] | lastWritten [%d]\n", INIT_CLOSE, socketList[global_fd].state, socketList[global_fd].lastRead-1, socketList[global_fd].lastWritten);
            
            if ((socketList[global_fd].state == INIT_CLOSE) && ((socketList[global_fd].lastRead-1 == socketList[global_fd].lastWritten) || (socketList[global_fd].lastRead == 0 && socketList[global_fd].lastWritten == 127))){
                clearTables(global_fd);
                socketList[global_fd].state = CLOSED;
                msgStatus = 0;
                methodCallStatus = 0;
                // call DataTimer.stop();
                dbg(GENERAL_CHANNEL, "SERVER    | CONNECTION FROM NODE [%d] -> NODE [%d] IS CLOSED\n", socketList[global_fd].src.addr, TOS_NODE_ID);
            }
        }

    }

    event void ConnectionTimer.fired() { // this is the client side timer after it fires (retry)
        // will always have TOS_NODE_ID for client
        socket_t global_fd;
        uint32_t connectionID;
        uint16_t i;

        dbg(ROUTING_CHANNEL, "Connection Timer fired\n");

        connectionID = TOS_NODE_ID;
        global_fd = call connectionTable.get(connectionID);

        if (call seqTimer.front()){
            dbg(TRANSPORT_CHANNEL, "Stored in seqTimer[%d]\n", call seqTimer.front());
            dbg(TRANSPORT_CHANNEL, "Size of seqTimer [%d] | Size of HashTable[%d], WindowSize[%d]\n", call seqTimer.size(), call SeqBuffPosHash.size(), socketList[global_fd].effectiveWindow);
            // for(i = 0; i< call seqTimer.size(); i++){
            //     dbg(TRANSPORT_CHANNEL, "SEQTIMER  | Prev | Position [%d] | Content [%d]\n", i, call seqTimer.get(i));
            // }

            if (call SeqBuffPosHash.contains(call seqTimer.front())){
                // bug found: the very first time we ack, data is still in transmission so the ack will not be recieved yet. This is where it errors out
                if (socketList[global_fd].flag == SYN_FLAG){
                    dbg(TRANSPORT_CHANNEL, "\n");
                    dbg(TRANSPORT_CHANNEL, ">>>>> Need to resend SYN for the seq [%d] <<<<<\n", call seqTimer.front());
                    dbg(TRANSPORT_CHANNEL, "\n");
                    call Transport.sendPayload(socketList[global_fd].src.port, socketList[global_fd].dest.port, call seqTimer.front(), call AckSeqHash.get(call seqTimer.front()), SYN_FLAG, SERV_WINDOW_SIZE, call SeqBuffPosHash.get(call seqTimer.front()),socketList[global_fd].dest.addr);
                    //call seqTimer.pushback(call seqTimer.front());
                    //call seqTimer.popfront();
                    // call Transport.startTimer(global_fd);
                }
                else if (socketList[global_fd].flag == DATA_FLAG){
                    dbg(TRANSPORT_CHANNEL, "\n");
                    dbg(TRANSPORT_CHANNEL, ">>>>> Need to resend DATA for the seq [%d] <<<<<\n", call seqTimer.front());
                    dbg(TRANSPORT_CHANNEL, "\n");
                    call Transport.sendPayload(socketList[global_fd].src.port, socketList[global_fd].dest.port, call seqTimer.front(), call AckSeqHash.get(call seqTimer.front()), DATA_FLAG, SERV_WINDOW_SIZE, socketList[global_fd].sendBuff[call SeqBuffPosHash.get(call seqTimer.front())], socketList[global_fd].dest.addr);
                    //call seqTimer.pushback(call seqTimer.front());
                    //call seqTimer.popfront();
                    // call Transport.startTimer(global_fd);
                }
            }
            else{
                // dbg(TRANSPORT_CHANNEL, " >>>>> ACK value for seq [%d] has been recieved <<<<<\n", call seqTimer.front());
                dbg(TRANSPORT_CHANNEL, "REMOVING seq [%d] from seqTimer\n", call seqTimer.front());
                call seqTimer.popfront();
                dbg(TRANSPORT_CHANNEL, "Check to see if seq [%d] is removed from seqTimer\n", call seqTimer.front());
                // call Transport.startTimer(global_fd);
            }

            // for(i = 0; i< call seqTimer.size(); i++){
            //     dbg(TRANSPORT_CHANNEL, "SEQTIMER  | Post | Position [%d] | Content [%d]\n", i, call seqTimer.get(i));
            // }
        }

        // if (socketList[global_fd].lastAck >= socketList[global_fd].lastAck) // socketList[global_fd].lastAck <- stored previously | check w/ 
    }

    command void Transport.startTimer(socket_t fd) {
        //dbg(ROUTING_CHANNEL, "Timer has been started\n");
        call ConnectionTimer.startOneShot(20); // this is the timer that gets started for client side
    }

    command void Transport.sendPayload(uint8_t srcPort, uint8_t destPort, uint16_t seq, uint16_t ACK, uint8_t flag, uint8_t window, uint8_t data, uint16_t destination){
        // creating a tcp pack (initializing variables)
        uint8_t buff_len = 7;
        uint8_t buff[buff_len];

        buff[0] = srcPort;
        buff[1] = destPort;
        buff[2] = seq;
        buff[3] = ACK; // ACK
        buff[4] = flag; // flag
        buff[5] = window; // window
        buff[6] = data; //data

        call Routing.initiateRouting(destination, 15, routingSeq, (uint8_t *)buff); //uint16_t destination, uint8_t TTL, uint16_t seqIN, uint8_t *payload
        routingSeq++;
    }

    // command void Transport.initiateSend(char* payload){
    //     socket_t global_fd;
    // }

    command void Transport.printPayload(void* payload, uint8_t postOrPre){
        pack* myMsg = (pack*) payload;

        dbg(TRANSPORT_CHANNEL, "\n");
        if (postOrPre == 0) // post
            dbg(TRANSPORT_CHANNEL, "NODE [%d] | POST-ROUTING BUFFER VALUES\n", TOS_NODE_ID);
        else
            dbg(TRANSPORT_CHANNEL, "NODE [%d] | PRE-ROUTING BUFFER VALUES\n", TOS_NODE_ID);

        // 7 values to print  (values in payload are correct values)
        dbg(TRANSPORT_CHANNEL, "srcPort[%d]\n", (myMsg->payload)[0]);
        dbg(TRANSPORT_CHANNEL, "destPort[%d]\n", (myMsg->payload)[1]);
        dbg(TRANSPORT_CHANNEL, "globalSeq[%d]\n", (myMsg->payload)[2]);
        dbg(TRANSPORT_CHANNEL, "ACK[%d]\n", (myMsg->payload)[3]);
        dbg(TRANSPORT_CHANNEL, "flag[%d]\n", (myMsg->payload)[4]);
        dbg(TRANSPORT_CHANNEL, "Window[%d]\n", (myMsg->payload)[5]);
        dbg(TRANSPORT_CHANNEL, "data[%d]\n", (myMsg->payload)[6]);
        dbg(TRANSPORT_CHANNEL, "\n");
    }
    
    command void Transport.flowControl(uint16_t src, void* payload){
        pack* myMsg = (pack*) payload;
        socket_t global_fd;
        uint32_t connectionID;
        uint8_t buffPos;
        uint8_t i;
        uint8_t limit;

        connectionID = TOS_NODE_ID;
        global_fd = call connectionTable.get(connectionID);

        if (socketList[global_fd].effectiveWindow > socketList[global_fd].congestionControl){
            dbg(TRANSPORT_CHANNEL, "TRANSPORT | IN flowControl | effect > congest\n", limit);
            if (socketList[global_fd].congestionControl > call SeqBuffPosHash.size()){
                limit = call SeqBuffPosHash.size();
                limit = socketList[global_fd].congestionControl - limit;
            }
            else
                limit = 0;
        }
        else {
            dbg(TRANSPORT_CHANNEL, "TRANSPORT | IN flowControl | else\n", limit);
            if (socketList[global_fd].effectiveWindow > call SeqBuffPosHash.size()){
                limit = call SeqBuffPosHash.size();
                limit = socketList[global_fd].effectiveWindow - limit;
            }
            else
                limit = 0;
        }
        
        dbg(TRANSPORT_CHANNEL, "TRANSPORT | IN flowControl | limit [%d]\n", limit);

        switch((myMsg->payload)[4]){
            case SYN_ACK_FLAG:
                for(i=0; i<limit; i++){
                    socketList[global_fd].lastSent = socketList[global_fd].lastSent + 1; // sequence
                    if (i != 0)
                        socketList[global_fd].lastAck = socketList[global_fd].lastAck + 1; // ack
                    socketList[global_fd].flag = DATA_FLAG;
                    // if (socketList[global_fd].sendBuff[dataCount] != 0){}
                    call Transport.sendPayload((myMsg->payload)[0], (myMsg->payload)[1], socketList[global_fd].lastSeq, socketList[global_fd].lastAck, DATA_FLAG, (myMsg->payload)[5], socketList[global_fd].sendBuff[dataCount], src);
                    socketList[global_fd].lastSeq = socketList[global_fd].lastSeq + 1;
                    socketList[global_fd].bytesSent = socketList[global_fd].bytesSent + 1;
                    dbg(TRANSPORT_CHANNEL, "TRANSPORT | FLOW SYN_ACK | bytesSent [%d]\n", socketList[global_fd].bytesSent);
                    // Adding into Lists + Hashtables for reliability
                    call seqTimer.pushback(socketList[global_fd].lastSeq-1); //<--------------------------------------
                    call SeqBuffPosHash.insert(socketList[global_fd].lastSeq-1, dataCount);
                    call AckSeqHash.insert(socketList[global_fd].lastSeq-1,socketList[global_fd].lastAck);

                    //dbg(TRANSPORT_CHANNEL, "TRANSPORT | FLOW SYN_ACK | [IN NODE %d] Startng Timer for Seq [%d]\n", TOS_NODE_ID, socketList[global_fd].lastSent);
                    dbg(TRANSPORT_CHANNEL, "TRANSPORT | FLOW SYN_ACK | SENDING PACKET NUM [%d] w/ SEQ [%d] w/ DATA [%d]\n", i, socketList[global_fd].lastSeq-1, socketList[global_fd].sendBuff[dataCount]);
                    
                    // accounting for wrap-around
                    if (dataCount == SOCKET_BUFFER_SIZE-1)
                        dataCount = 0;
                    else
                        dataCount++;
                }
                break;

            case ACK_FLAG:
                for(i=0; i<limit; i++){
                    if (i == 0){
                        socketList[global_fd].lastAck = (myMsg->payload)[2] + 1; // ack = 1 + seq
                        socketList[global_fd].lastSent = (myMsg->payload)[3]; // seq num = previous ack in the packet sent to this flag
                    }
                    else {
                        socketList[global_fd].lastSent = socketList[global_fd].lastSent + 1;
                        socketList[global_fd].lastAck = socketList[global_fd].lastAck + 1;
                    }
                    socketList[global_fd].flag = DATA_FLAG;

                    if (!call SeqBuffPosHash.contains(socketList[global_fd].lastSent)){
                        dbg(TRANSPORT_CHANNEL, "TRANSPORT | IN flowControl | HashTable contains prev seq sent\n", socketList[global_fd].sendBuff[dataCount]);
                        // if (socketList[global_fd].sendBuff[dataCount] == 0) {}
                        if (socketList[global_fd].bytesSent == socketList[global_fd].maxByteTransfer) {}
                        else {
                            if (socketList[global_fd].lastSeq > 128)
                                socketList[global_fd].lastSeq = 1;

                            if (socketList[global_fd].sendBuff[dataCount] == 0) {// added 11-26
                                dbg(TRANSPORT_CHANNEL, "TRANSPORT | IN flowControl | dataCount is 0 [%d]\n", socketList[global_fd].sendBuff[dataCount]);
                                return;
                            }

                            call Transport.sendPayload((myMsg->payload)[0], (myMsg->payload)[1], socketList[global_fd].lastSeq, socketList[global_fd].lastAck, DATA_FLAG, (myMsg->payload)[5], socketList[global_fd].sendBuff[dataCount], src);
                            socketList[global_fd].lastSeq = socketList[global_fd].lastSeq + 1;
                            socketList[global_fd].bytesSent = socketList[global_fd].bytesSent + 1;
                            dbg(TRANSPORT_CHANNEL, "TRANSPORT | FLOW ACK     | bytesSent [%d]\n", socketList[global_fd].bytesSent);

                            if (socketList[global_fd].lastSeq-1 == 1){
                                call seqTimer.pushback(1);
                                call SeqBuffPosHash.insert(1, dataCount);
                                call AckSeqHash.insert(1,socketList[global_fd].lastAck);
                            }
                            else {
                                call seqTimer.pushback(socketList[global_fd].lastSeq-1);
                                call SeqBuffPosHash.insert(socketList[global_fd].lastSeq-1, dataCount);
                                call AckSeqHash.insert(socketList[global_fd].lastSeq-1,socketList[global_fd].lastAck);
                            }

                            //dbg(TRANSPORT_CHANNEL, "TRANSPORT | FLOW ACK     | [IN NODE %d] Startng Timer for Seq [%d]\n", TOS_NODE_ID, socketList[global_fd].lastSent);
                            dbg(TRANSPORT_CHANNEL, "TRANSPORT | FLOW ACK     | SENDING PACKET NUM [%d] w/ SEQ [%d] w/ DATA [%d]\n", i, socketList[global_fd].lastSeq-1, socketList[global_fd].sendBuff[dataCount]);

                            // accounting for wrap-around
                            if (dataCount == SOCKET_BUFFER_SIZE-1)
                                dataCount = 0;
                            else
                                dataCount++;
                        }
                    }
                    //else
                    //    i--;
                }
                break;

            default:
                dbg(TRANSPORT_CHANNEL, "CMD_ERROR: Flag[%d] cannot be found. [FLOW CONTROL]\n", (myMsg->payload)[4]);
                break;
        }
    }

    command void Transport.processPacket(uint16_t src, void *payload){
        //uint8_t ackTemp; // this is temporary till socket deals with ack
        pack* myMsg = (pack*) payload;
        socket_t global_fd;
        //uint16_t temp;
        socket_addr_t socket_address;
        socket_addr_t server_address;
        uint32_t connectionID; 
        uint8_t buffPos;
        uint8_t i; // for testing
        uint16_t tempSeq;

        // call Transport.printPayload(payload, 0); // debugging

        switch((myMsg->payload)[4]) {
            case SYN_FLAG: // server recieves this
                //if (call connectionTable.contains(src)) {}
                //else {
                    global_fd = call Transport.startListening();
                    socket_address.port = (myMsg->payload)[0];
                    socket_address.addr = src;
                    server_address.port = (myMsg->payload)[1];
                    server_address.addr = TOS_NODE_ID;
                    call Transport.clientBind(global_fd, &socket_address, &server_address);
                    dbg(TRANSPORT_CHANNEL, "\n");
                    dbg(TRANSPORT_CHANNEL, "TRANSPORT | [IN NODE %d] SYN Packet Arrived from Node [%d] for Port [%d]\n", TOS_NODE_ID, src, socketList[global_fd].src.port);
                    socketList[global_fd].lastAck = (myMsg->payload)[2]+1;
                    // socketList[global_fd].lastSent = socketList[global_fd].lastSent;
                    socketList[global_fd].flag = SYN_ACK_FLAG;
                    socketList[global_fd].firstDataSeqExpected = (myMsg->payload)[6];

                    call Transport.sendPayload((myMsg->payload)[0], (myMsg->payload)[1], socketList[global_fd].lastSent, socketList[global_fd].lastAck, SYN_ACK_FLAG, socketList[global_fd].effectiveWindow, (myMsg->payload)[6], src);
                    // call Transport.startTimer(global_fd); // need to add later
                //}
                break;
           
            case SYN_ACK_FLAG: // client recieves this
                connectionID = TOS_NODE_ID;
                global_fd = call connectionTable.get(connectionID);
                dbg(TRANSPORT_CHANNEL, "TRANSPORT | [IN NODE %d] SYN_ACK Packet Arrived from Node [%d] for Port [%d]\n", TOS_NODE_ID, src, socketList[global_fd].dest.port);

                if (socketList[global_fd].state == ESTABLISHED) {}
                else {
                    socketList[global_fd].state = ESTABLISHED;
                    socketList[global_fd].effectiveWindow = (myMsg->payload)[5];
                    dbg(TRANSPORT_CHANNEL, "CLIENT    | CONNECTION FROM NODE [%d] -> NODE [%d] IS ESTABLISHED\n", TOS_NODE_ID, src);
                    dbg(TRANSPORT_CHANNEL, "\n");

                    call SeqBuffPosHash.remove((myMsg->payload)[3]-1); // removes seq id for syn packet
                    call AckSeqHash.remove((myMsg->payload)[3]-1);

                    // adding after midrev submitted
                    socketList[global_fd].lastRcvd = (myMsg->payload)[2]; // storing last seq recieved
                    
                    // ------------------------------------------------------------
                    socketList[global_fd].lastAck = (myMsg->payload)[2] + 1;
                    socketList[global_fd].lastSent = (myMsg->payload)[3];
                    socketList[global_fd].flag = CONN_ACK_FLAG;
                    
                    //call Transport.sendPayload((myMsg->payload)[0], (myMsg->payload)[1], socketList[global_fd].lastSent, socketList[global_fd].lastAck, CONN_ACK_FLAG, (myMsg->payload)[5], (myMsg->payload)[6], src);
                    call Transport.sendPayload((myMsg->payload)[0], (myMsg->payload)[1], socketList[global_fd].lastSent, socketList[global_fd].lastAck, CONN_ACK_FLAG, (myMsg->payload)[5], socketList[global_fd].lastSeq, src);
                    
                    // DATA TRANSMISSION SECTION
                    call Transport.flowControl(src, payload);
                    
                    // socketList[global_fd].lastSent = socketList[global_fd].lastSent + 1;
                    // socketList[global_fd].flag = DATA_FLAG;
                    // call Transport.sendPayload((myMsg->payload)[0], (myMsg->payload)[1], socketList[global_fd].lastSent, socketList[global_fd].lastAck, DATA_FLAG, (myMsg->payload)[5], socketList[global_fd].sendBuff[dataCount], src);
                    // dataCount++;
                    
                    // call seqTimer.pushback(socketList[global_fd].lastSent);
                    // call SeqBuffPosHash.insert(socketList[global_fd].lastSent, dataCount-1); // adds sequence id for data packet
                    // call AckSeqHash.insert(socketList[global_fd].lastSent,socketList[global_fd].lastAck);
                    
                    // dbg(TRANSPORT_CHANNEL, "TRANSPORT | [IN NODE %d] Startng Timer for Seq [%d]\n", TOS_NODE_ID, socketList[global_fd].lastSent);
                }
                break;

            case CONN_ACK_FLAG: // This is recieved in the server
                connectionID = src;
                global_fd = call connectionTable.get(connectionID);
                dbg(TRANSPORT_CHANNEL, "TRANSPORT | [IN NODE %d] CONN_ACK Packet Arrived from Node [%d] for Port [%d]\n", TOS_NODE_ID, src, socketList[global_fd].src.port);
                if ((socketList[global_fd].state != ESTABLISHED)&&(socketList[global_fd].state != CLOSED)){
                    socketList[global_fd].state = ESTABLISHED;
                    dbg(TRANSPORT_CHANNEL, "SERVER    | CONNECTION FROM NODE [%d] -> NODE [%d] IS ESTABLISHED\n", TOS_NODE_ID, src);
                    socketList[global_fd].firstDataSeqExpected = (myMsg->payload)[6];
                    dbg(TRANSPORT_CHANNEL, "\n");
                }
                else if (socketList[global_fd].state == ESTABLISHED){
                    dbg(TRANSPORT_CHANNEL, "SERVER    | CONNECTION FROM NODE [%d] -> NODE [%d] ALREADY ESTABLISHED\n", TOS_NODE_ID, src);
                    dbg(TRANSPORT_CHANNEL, "\n");
                }
                else {
                    dbg(TRANSPORT_CHANNEL, "SERVER    | CONNECTION FROM NODE [%d] -> NODE [%d] UNABLE TO BE ESTABLISHED\n", TOS_NODE_ID, src);
                    dbg(TRANSPORT_CHANNEL, "\n");
                }
                break;
            
            case ACK_FLAG: //client normally recieves this
                connectionID = TOS_NODE_ID;
                global_fd = call connectionTable.get(connectionID);
                dbg(GENERAL_CHANNEL, "TRANSPORT | [IN NODE %d] ACK Packet Arrived from Node [%d] for Port [%d]\n", TOS_NODE_ID, src, socketList[global_fd].src.port);
                dbg(GENERAL_CHANNEL, "TRANSPORT | [IN NODE %d] PREV SEQ [%d]\n", TOS_NODE_ID, (myMsg->payload)[3]-1);
                dbg(TRANSPORT_CHANNEL, "TRANSPORT | [IN NODE %d] MaxByteTransfer [%d]\n", TOS_NODE_ID, socketList[global_fd].maxByteTransfer);

                // if ((myMsg->payload)[3]-1 == 1)
                //     tempSeq = 250;
                // else
                    //tempSeq = (myMsg->payload)[3]-1;

                if (call SeqBuffPosHash.contains((myMsg->payload)[3]-1)){
                    //call AckSeqHash.remove((myMsg->payload)[3]-1);
                    socketList[global_fd].sendBuff[call SeqBuffPosHash.get((myMsg->payload)[3]-1)] = 0;
                    dbg(GENERAL_CHANNEL, "(myMsg->payload)[3]-1) [%d], SeqBuffPosHash.get(seq) [%d], buff [%d]\n",(myMsg->payload)[3]-1, call SeqBuffPosHash.get((myMsg->payload)[3]-1), socketList[global_fd].sendBuff[call SeqBuffPosHash.get((myMsg->payload)[3]-1)]);
                    socketList[global_fd].lastRead = call SeqBuffPosHash.get((myMsg->payload)[3]-1);

                    // removing the previous seq value from the hashtables since it has been acknowledged
                    dbg(TRANSPORT_CHANNEL, "TRANSPORT | [IN NODE %d] REMOVING SEQ [%d]\n", TOS_NODE_ID, (myMsg->payload)[3]-1);
                    call SeqBuffPosHash.remove((myMsg->payload)[3]-1);
                    call AckSeqHash.remove((myMsg->payload)[3]-1);
                    if (call SeqBuffPosHash.contains((myMsg->payload)[3]-1)) // added for testing
                        dbg(TRANSPORT_CHANNEL, "TRANSPORT | [IN NODE %d] FAILED TO REMOVE SEQ [%d]\n", TOS_NODE_ID, (myMsg->payload)[3]-1);

                    socketList[global_fd].bytesTransfered = socketList[global_fd].bytesTransfered + 1;
                    dbg(GENERAL_CHANNEL, "TRANSPORT | [IN NODE %d] UPDATED BYTES TRANSFERED [%d] | maxBytesTransfered [%d]\n", TOS_NODE_ID, socketList[global_fd].bytesTransfered, socketList[global_fd].maxByteTransfer);
                    
                    // socketList[global_fd].lastAck = (myMsg->payload)[2] + 1; // ack = 1 + seq
                    // socketList[global_fd].lastSent = (myMsg->payload)[3]; // seq num = previous ack in the packet sent to this flag
                    // socketList[global_fd].flag = DATA_FLAG;

                    //if ((TOS_NODE_ID == socketList[global_fd].src.addr) && (socketList[global_fd].sendBuff[dataCount] == 0)){
                    if ((TOS_NODE_ID == socketList[global_fd].src.addr) && (socketList[global_fd].maxByteTransfer == socketList[global_fd].bytesTransfered)){
                    //if ((TOS_NODE_ID == socketList[global_fd].src.addr) && (socketList[global_fd].bytesTransfered == 127)){
                        dbg(TRANSPORT_CHANNEL, "\n");
                        dbg(TRANSPORT_CHANNEL, "_________________________ INITIATING CLOSURE _________________________\n");
                        call WriteTimer.stop();
                        socketList[global_fd].lastAck = (myMsg->payload)[2] + 1; // ack = 1 + seq
                        socketList[global_fd].lastSent = (myMsg->payload)[3]; // seq num = previous ack in the packet sent to this flag
                        socketList[global_fd].flag = FIN_FLAG;
                        
                        call Transport.sendPayload((myMsg->payload)[0], (myMsg->payload)[1], socketList[global_fd].lastSent, socketList[global_fd].lastAck, FIN_FLAG, (myMsg->payload)[5], (myMsg->payload)[6], src);
                        call seqTimer.pushback(socketList[global_fd].lastSent);
                        call SeqBuffPosHash.insert(socketList[global_fd].lastSent, dataCount);
                        call AckSeqHash.insert(socketList[global_fd].lastSent,socketList[global_fd].lastAck);
                    }
                    else{
                        // call Transport.sendPayload((myMsg->payload)[0], (myMsg->payload)[1], socketList[global_fd].lastSent, socketList[global_fd].lastAck, DATA_FLAG, (myMsg->payload)[5], socketList[global_fd].sendBuff[dataCount], src);
                        // call seqTimer.pushback(socketList[global_fd].lastSent);
                        // call SeqBuffPosHash.insert(socketList[global_fd].lastSent, dataCount);
                        // call AckSeqHash.insert(socketList[global_fd].lastSent,socketList[global_fd].lastAck);

                        // // accounting for wrap-around
                        // if (dataCount == SOCKET_BUFFER_SIZE-1)
                        //     dataCount = 0;
                        // else
                        //     dataCount++;

                        // DATA TRANSMISSION
                        call Transport.flowControl(src, payload);
                    }

                   // dbg(TRANSPORT_CHANNEL, "TRANSPORT | [IN NODE %d] Startng Timer for Seq [%d]\n", TOS_NODE_ID, socketList[global_fd].lastSent);
                }
                
                break;
            
            case DATA_FLAG: // server recieves this
                connectionID = src;
                global_fd = call connectionTable.get(connectionID);
                // dbg(GENERAL_CHANNEL, "TRANSPORT | [IN NODE %d] [SEQ %d] DATA Packet Arrived from Node [%d] for Port [%d] w/ Data [%d]\n", TOS_NODE_ID, (myMsg->payload)[2], src, socketList[global_fd].dest.port, (myMsg->payload)[6]);
                
                buffPos = (myMsg->payload)[2] - socketList[global_fd].firstDataSeqExpected; // gives array position
                while(buffPos >= 128){
                    buffPos -= 128;
                }
                dbg(GENERAL_CHANNEL, "TRANSPORT | FIRST DATA SEQ [%d]\n", socketList[global_fd].firstDataSeqExpected);
                
                socketList[global_fd].lastAck = (myMsg->payload)[2] + 1; // ack value
                socketList[global_fd].lastSent = (myMsg->payload)[3]; // sequence num (server -> client)

                dbg(GENERAL_CHANNEL, "SERVER    | [IN NODE %d] [SEQ %d] DATA INCOMING FROM NODE [%d] : %d\n", TOS_NODE_ID, (myMsg->payload)[2], src, (myMsg->payload)[6]);
                // saving payload data in buff position
                if ((call SeqBuffPosHash.contains((myMsg->payload)[2] + socketList[global_fd].iterator)) || ((myMsg->payload)[6] == 0)){ // issue could be here or line 407
                    dbg(TRANSPORT_CHANNEL, "SERVER    | CHECKING IF SEQ IN SERVER-SIDE TABLE\n");
                    dbg(GENERAL_CHANNEL, "TRANSPORT | [IN NODE %d] [SEQ %d] DUPLICATE DATA Packet Arrived from Node [%d] for Port [%d] w/ Data [%d]\n", TOS_NODE_ID, (myMsg->payload)[2], src, socketList[global_fd].dest.port, (myMsg->payload)[6]);
                }
                else if (socketList[global_fd].rcvdBuff[buffPos] != 0)
                    break;
                else {
                    // dbg(DEBUG_CHANNEL, "SERVER    | [IN NODE %d] DATA INCOMING FROM NODE [%d] : %d\n", TOS_NODE_ID, src, (myMsg->payload)[6]);
                    dbg(TRANSPORT_CHANNEL, "SERVER    | SEQ NOT IN SERVER-SIDE TABLE\n");
                    // dbg(CHAT_CHANNEL, "TRANSPORT | [IN NODE %d] [SEQ %d] DATA Packet Arrived from Node [%d] for Port [%d] w/ Data [%d]\n", TOS_NODE_ID, (myMsg->payload)[2], src, socketList[global_fd].dest.port, (myMsg->payload)[6]);
                    socketList[global_fd].rcvdBuff[buffPos] = (myMsg->payload)[6];
                    // dbg(CHAT_CHANNEL, "PACKET SEQ NUM [%d] | BUFF STORED VAL [%d] | buffPos [%d] | VAL FROM PACKET [%d]\n", (myMsg->payload)[2], socketList[global_fd].rcvdBuff[buffPos], buffPos, (myMsg->payload)[6]);
                    dbg(GENERAL_CHANNEL, "TRANSPORT | [IN NODE %d] [SEQ %d] rcvdBuff[%d] = %d\n", TOS_NODE_ID, (myMsg->payload)[2], buffPos, socketList[global_fd].rcvdBuff[buffPos]);

                    // socketList[global_fd].lastWritten = socketList[global_fd].lastWritten + 1;
                    socketList[global_fd].lastWritten = buffPos;
                    dbg(TRANSPORT_CHANNEL, "OUT IF | PACKET SEQ Recieved [%d] | lastWritten [%d]\n", (myMsg->payload)[2], socketList[global_fd].lastWritten);
                    
                    // if (call seqTimer.size() >= 127){
                    //     dbg(TRANSPORT_CHANNEL, "SERVER    | Seq being popped out [%d]\n", call seqTimer.front());
                    //     call SeqBuffPosHash.remove(call seqTimer.popfront());
                    //     dbg(TRANSPORT_CHANNEL, "SERVER    | Size of seqTimer [%d]\n", call seqTimer.size());
                    // }

                    if ((myMsg->payload)[2] == 128)
                        socketList[global_fd].iterator = socketList[global_fd].iterator + 128;

                    call seqTimer.pushback((myMsg->payload)[2]+socketList[global_fd].iterator);
                    call SeqBuffPosHash.insert((myMsg->payload)[2]+socketList[global_fd].iterator,buffPos); // test ERROR IS HERE <------------------------------------------------------------------- (not getting inserted)
                    dbg(TRANSPORT_CHANNEL, "SERVER    | INSERTING [%d] INTO HASHMAP\n", (myMsg->payload)[2]);
                }
                dbg(TRANSPORT_CHANNEL, "\n");

                socketList[global_fd].flag = ACK_FLAG;
                dbg(TRANSPORT_CHANNEL, "TRANSPORT | [IN NODE %d] ACK BEING SENT [%d]\n", TOS_NODE_ID, socketList[global_fd].lastAck);

                if (socketList[global_fd].lastSent > 128)
                    socketList[global_fd].lastSent = 1;
                
                call Transport.sendPayload((myMsg->payload)[0], (myMsg->payload)[1], socketList[global_fd].lastSent, (myMsg->payload)[2] + 1, ACK_FLAG, (myMsg->payload)[5], (myMsg->payload)[6], src);
                break;

            case FIN_FLAG: // server recieves this
                connectionID = src;
                global_fd = call connectionTable.get(connectionID);
                dbg(TRANSPORT_CHANNEL, "TRANSPORT | [IN NODE %d] FIN Packet Arrived from Node [%d] for Port [%d]\n", TOS_NODE_ID, src, socketList[global_fd].dest.port);

                if ((socketList[global_fd].state == CLOSED)||(socketList[global_fd].state == INIT_CLOSE)) {}
                else {
                    socketList[global_fd].lastAck = (myMsg->payload)[2] + 1;
                    socketList[global_fd].lastSent = (myMsg->payload)[3];
                    socketList[global_fd].flag = FIN_ACK_FLAG;
                    call Transport.sendPayload((myMsg->payload)[0], (myMsg->payload)[1], socketList[global_fd].lastSent, socketList[global_fd].lastAck, FIN_ACK_FLAG, (myMsg->payload)[5], (myMsg->payload)[6], src);
                    
                    if (socketList[global_fd].state == CLOSED){
                        dbg(TRANSPORT_CHANNEL, "SERVER    | CONNECTION FROM NODE [%d] -> NODE [%d] IS ALREADY CLOSED\n", src, TOS_NODE_ID);
                        dbg(TRANSPORT_CHANNEL, "\n");
                    }
                    if (call Transport.close(global_fd) == SUCCESS){
                        dbg(TRANSPORT_CHANNEL, "SERVER    | CONNECTION FROM NODE [%d] -> NODE [%d] IS BEING CLOSED\n", src, TOS_NODE_ID);
                        dbg(TRANSPORT_CHANNEL, "\n");
                    }
                    else {
                        dbg(TRANSPORT_CHANNEL, "SERVER    | CONNECTION FROM NODE [%d] -> NODE [%d] UNABLE TO BE CLOSED\n", src, TOS_NODE_ID);
                        dbg(TRANSPORT_CHANNEL, "\n");
                    }
                }
                //call Transport.startTimer(global_fd); // this is supposed to be here (should call a server timer instead here tho)
                break;

            case FIN_ACK_FLAG: // client recieves this 
                connectionID = TOS_NODE_ID;
                global_fd = call connectionTable.get(connectionID);
                dbg(TRANSPORT_CHANNEL, "TRANSPORT | [IN NODE %d] FIN_ACK Packet Arrived from Node [%d] for Port [%d]\n", TOS_NODE_ID, src, socketList[global_fd].src.port);

                call ConnectionTimer.stop();

                if (socketList[global_fd].state == CLOSED){
                    dbg(TRANSPORT_CHANNEL, "CLIENT    | CONNECTION FROM NODE [%d] -> NODE [%d] IS ALREADY CLOSED\n", src, TOS_NODE_ID);
                    dbg(TRANSPORT_CHANNEL, "\n");
                }
                else if (call Transport.close(global_fd) == SUCCESS){
                    dbg(TRANSPORT_CHANNEL, "CLIENT    | CONNECTION FROM NODE [%d] -> NODE [%d] IS CLOSED\n", src, TOS_NODE_ID);
                    if (TOS_NODE_ID == 1){ // should only happen in the server
                        if (call ChatClient.getBroadcastState() > 0)
                            call ChatClient.updateFlag(2);
                        else
                            call ChatClient.updateFlag(3);
                    }
                    // somehow recall the sending of broadcast msg for a new list
                    dbg(TRANSPORT_CHANNEL, "\n");
                }
                else {
                    dbg(TRANSPORT_CHANNEL, "CLIENT    | CONNECTION FROM NODE [%d] -> NODE [%d] UNABLE TO BE CLOSED\n", src, TOS_NODE_ID);
                    dbg(TRANSPORT_CHANNEL, "\n");
                }
                break;

                // check to see if state is established, if not establish it, then begin sending data over.
            default:
                dbg(TRANSPORT_CHANNEL, "CMD_ERROR: Flag[%d] cannot be found.\n", (myMsg->payload)[4]);
                break;
        }
    }

    command socket_t Transport.startListening(){ // executed when 'server' recieves a SYN_FLAG
        uint8_t i;
        for(i=0; i<MAX_NUM_OF_SOCKETS; i++){ 
            if (socketList[i].state == PASSIVE_OPEN){
                socketList[i].state = LISTEN; // Question to ask, should i make a new state or is it fine to have it go from CLOSED to LISTEN?
                dbg(TRANSPORT_CHANNEL, "Transport.startListening() succeeded\n");
                return (socket_t)i;
            }
        }
        dbg(TRANSPORT_CHANNEL, "Transport.startListening() failed\n");
        return (socket_t)0;
        //call Transport.b

        // socket_addr_t socket_address;

        // dbg(TRANSPORT_CHANNEL, "in addServer() | port[%d] | global_fd[%d]\n", servPort, global_fd);
        // socket_address.port = servPort;
        // socket_address.addr = TOS_NODE_ID;
        // call Transport.bind(global_fd, &socket_address);
        // // socket_address = NODE_ID, [port] //Only source info.
        // // bind(fd, socket address); <--------------------------------- added till this (inclusive)
        // // startTimer(Attempt_Connection_Time);

    }

    command void Transport.addServer(uint8_t servPort){
        uint8_t i;
        //socket_t global_fd;
        socket_addr_t socket_address;

        dbg(TRANSPORT_CHANNEL, "in addServer() | port[%d]\n", servPort);
        socket_address.port = servPort;
        socket_address.addr = TOS_NODE_ID;

        for(i=0; i<MAX_NUM_OF_SOCKETS/2; i++){
            call Transport.serverBind(call Transport.socket(), &socket_address);
        }

        call DataTimer.startPeriodicAt(call DataTimer.getNow()+2000, 200);
        // socket_address = NODE_ID, [port] //Only source info.
        // bind(fd, socket address); <--------------------------------- added till this (inclusive)
        // startTimer(Attempt_Connection_Time);

    }

    command void Transport.addClient(uint16_t destination, uint8_t srcPort, uint8_t destPort, char* transfer){
        uint8_t i;
        uint8_t tempData = 1;
        socket_t global_fd = call Transport.socket();
        socket_addr_t socket_address;
        socket_addr_t server_address;
        
        // dbg(CHAT_CHANNEL, "transfer size[%d]\n", strlen(transfer));
        // dbg(CHAT_CHANNEL, "transfer[%s]\n", transfer);
        // dbg(CHAT_CHANNEL, "in addClient() | srcPort[%d] , destNode [%d], destPort[%d]\n", srcPort, destination, destPort);

        clearTables(global_fd);

        socket_address.port = srcPort;
        socket_address.addr = TOS_NODE_ID;
        //call Transport.bind(global_fd, &socket_address);
        //---------------------------------------------------------
        server_address.port = destPort;
        server_address.addr = destination;
        call Transport.clientBind(global_fd, &socket_address, &server_address);
        
        // socketList[global_fd].maxByteTransfer = transfer;
        socketList[global_fd].maxByteTransfer = strlen(transfer); // changed to length of transfer from 254
        
        socketList[global_fd].lastWritten = 0;
        socketList[global_fd].lastRead = 0;
        socketList[global_fd].bytesTransfered = 0;
        socketList[global_fd].congestionControl = 5;

        //call WriteTimer.startPeriodicAt(0, 150); // commented out to add characters instead of numbers
        for(i=0;i<socketList[global_fd].maxByteTransfer;i++){
            if (i == 0){
                // dbg(CHAT_CHANNEL, "VALUE BEING ADDED INTO sendBuff[%d] = [%d]\n", i, transfer[i]);
                socketList[global_fd].sendBuff[i] = transfer[i];
                socketList[global_fd].lastWritten = socketList[global_fd].lastWritten;
            }
            else {
                // dbg(CHAT_CHANNEL, "VALUE BEING ADDED INTO sendBuff[%d] = [%d]\n", i, transfer[i]);
                socketList[global_fd].sendBuff[i] = transfer[i];
                socketList[global_fd].lastWritten = socketList[global_fd].lastWritten + 1;
            }
        }

        // clearTables(global_fd);

        socketList[global_fd].flag = SYN_FLAG;
        socketList[global_fd].lastSeq = TOS_NODE_ID*30;
        dataCount = 0;
        //dbg(TRANSPORT_CHANNEL, "INITIAL CREATION | sizeof Buff[%d]\n", sizeof(socketList[global_fd].sendBuff));
        dbg(TRANSPORT_CHANNEL, "\n");
        dbg(TRANSPORT_CHANNEL, "GOAL NUM  | [%d]\n", socketList[global_fd].maxByteTransfer);
        dbg(TRANSPORT_CHANNEL, "________________________ INITIATING CONNECTION ________________________\n");
        dbg(TRANSPORT_CHANNEL, "TRANSPORT | [IN NODE %d] Starting Timer for Seq [%d]\n", TOS_NODE_ID, socketList[global_fd].lastSent);
        call Transport.sendPayload(srcPort, destPort, 1, 0, SYN_FLAG, 0, socketList[global_fd].lastSeq, destination);
        
        socketList[global_fd].lastSent = 1;
        call seqTimer.pushback(socketList[global_fd].lastSent);
        call SeqBuffPosHash.insert(socketList[global_fd].lastSent, 0);
        call AckSeqHash.insert(socketList[global_fd].lastSent, 0);
        //call Transport.startTimer(global_fd);

        dbg(TRANSPORT_CHANNEL, "TRANSPORT | [IN NODE %d] Startng Timer for Seq [%d]\n", TOS_NODE_ID, socketList[global_fd].lastSent);
        //call ConnectionTimer.startOneShot(call ConnectionTimer.getNow());
        //call ConnectionTimer.startPeriodicAt(call ConnectionTimer.getNow(), 250);
        call ConnectionTimer.startPeriodicAt(call ConnectionTimer.getNow(), 200);
    }

    void clearTables(socket_t global_fd){
        uint32_t i=0;
        // dbg(CHAT_CHANNEL, "clearing table\n");
        // dbg(CHAT_CHANNEL, "BEF maxByte[%d] | byteTransfered [%d]\n", socketList[global_fd].maxByteTransfer, socketList[global_fd].bytesTransfered);

        for(i=0; i< SOCKET_BUFFER_SIZE; i++){
            dbg("Clearing [%d] more entries\n", call SeqBuffPosHash.size());
            call SeqBuffPosHash.remove(call seqTimer.popfront());
        }
        
        socketList[global_fd].lastWritten = 0;
        socketList[global_fd].lastRead = 0;
        socketList[global_fd].lastAck = 0;
        socketList[global_fd].lastSent = 0;
        socketList[global_fd].lastRcvd = 0;
        socketList[global_fd].nextExpected = 0;
        socketList[global_fd].bytesTransfered = 0;
        socketList[global_fd].bytesSent = 0;
        socketList[global_fd].lastSeq = 0;
        socketList[global_fd].maxByteTransfer = 0;

        while (!call seqTimer.isEmpty()){
            if (!call SeqBuffPosHash.isEmpty())
                call SeqBuffPosHash.remove(call seqTimer.popfront());
            else
                call seqTimer.popfront();
        }

        // dbg(CHAT_CHANNEL, "END maxByte[%d] | byteTransfered [%d]\n", socketList[global_fd].maxByteTransfer, socketList[global_fd].bytesTransfered);
    }

    command socket_t Transport.socket(){
        uint8_t i;
        for(i=0; i<MAX_NUM_OF_SOCKETS; i++){ 
            if (socketList[i].state == CLOSED){
                socketList[i].state = PASSIVE_OPEN;
                dbg(TRANSPORT_CHANNEL, "Transport.socket() succeeded\n");
                return (socket_t) i;
            }
        }
        dbg(TRANSPORT_CHANNEL, "Transport.socket() failed\n");
        return 0; // temp return
    }

    command error_t Transport.serverBind(socket_t fd, socket_addr_t *addr){
        uint8_t i;
        dbg(TRANSPORT_CHANNEL, "IN Transport.serverBind() | *addr.port[%d], *addr.addr[%d]\n", addr->port, addr->addr);
        socketList[fd].dest.port = addr->port;
        socketList[fd].dest.addr = addr->addr;
        socketList[fd].effectiveWindow = SERV_WINDOW_SIZE;

        // testing
        // for(i=0; i<SOCKET_BUFFER_SIZE; i++){
        //     dbg(TRANSPORT_CHANNEL, "INIT SOCKET VAL | POS [%d] VAL [%d]\n", i, socketList[fd].rcvdBuff[i]);
        // }
    }

    command error_t Transport.clientBind(socket_t fd, socket_addr_t *clientAddr, socket_addr_t *serverAddr){
        //uint32_t *testMemCpy = clientAddr->port;
        //uint32_t *testMemCpy = clientAddr->addr;
        //uint32_t *testMemCpy = 76;
        uint32_t connectionID; 
        uint32_t tempID;
        
        dbg(TRANSPORT_CHANNEL, "NODE[%d] IN Transport.clientBind()\n", TOS_NODE_ID);
        dbg(TRANSPORT_CHANNEL, "server port: %d\n", serverAddr->port);
        socketList[fd].src.port = clientAddr->port;
        socketList[fd].src.addr = clientAddr->addr;
        socketList[fd].dest.port = serverAddr->port;
        socketList[fd].dest.addr = serverAddr->addr;

        socketList[fd].RTT = INITIAL_RTT;

        if (TOS_NODE_ID == serverAddr->addr)
            socketList[fd].lastSent = 1;
        else{
            socketList[fd].lastSent = 1;
        }

        socketList[fd].lastRead = 0;
        socketList[fd].lastWritten = 0;
        socketList[fd].lastSeq = 1;

        connectionID = clientAddr->addr;
        call connectionTable.insert(connectionID,fd); 
        dbg(TRANSPORT_CHANNEL, "CLIENT BIND | Node[%d] | connectionID[%d], fd[%d]\n", TOS_NODE_ID, connectionID, fd);
        // call connectionTable.insert(clientADDR.addr, fd); // TOS_NODE_ID , fd

        return SUCCESS;
    }

    command socket_t Transport.accept(socket_t fd){
        return 0; // temp return
    }

    command uint16_t Transport.write(socket_t fd, uint8_t *buff, uint16_t bufflen){
        return 0; // temp return
    }

    command error_t Transport.receive(pack* package){
        /* This command gets invoked at all times
         * When SYN+ACK is recieved (client node), update socket table w/ state as ESTABLISHED
        */
        return FAIL; // temp return
    }

    command uint16_t Transport.read(socket_t fd, uint8_t *buff, uint16_t bufflen){
        return 0; // temp return
    }

    command error_t Transport.connect(socket_t fd, socket_addr_t * addr){
        // Connection started here (Client side)
        // If a node is acting as a client, call this method to initiate a connection w/ address (addr) at socket/port (fd)
        // Send a SYN to server then update socket table to say that i am using x socket to talk w/ y server and the state is SYN_Sent
        return FAIL; // temp return
    }

    command error_t Transport.close(socket_t fd){
        uint32_t connectionID;
        //dbg(TRANSPORT_CHANNEL, "In close for Node [%d]\n", TOS_NODE_ID);
        connectionID = socketList[fd].src.addr;
        switch(socketList[fd].state){
            case LISTEN:
                // dbg(TRANSPORT_CHANNEL, "In Listen for Node [%d]\n", TOS_NODE_ID);
                // dbg(TRANSPORT_CHANNEL, "socketList[%d].src.addr = [%d]\n", fd, socketList[fd].src.addr);
                call connectionTable.remove(connectionID);
                socketList[fd].state = CLOSED;
                return SUCCESS;
            case ESTABLISHED:
                //dbg(TRANSPORT_CHANNEL, "In Established for Node [%d]\n", TOS_NODE_ID);
                //dbg(TRANSPORT_CHANNEL, "socketList[%d].src.addr = [%d] | connectionId = [%d]\n", fd, socketList[fd].src.addr, connectionID);
                call connectionTable.remove(connectionID);

                if (socketList[fd].dest.addr == TOS_NODE_ID)
                    socketList[fd].state = INIT_CLOSE;
                else
                    socketList[fd].state = CLOSED;
                return SUCCESS;
            // case CLOSED:
            //     return SUCCESS;
        }
        return FAIL; // temp return
    }

    command error_t Transport.release(socket_t fd){
        return FAIL; // temp return
    }

    command error_t Transport.listen(socket_t fd){
        return FAIL; // temp return
    }

    // CLARIFICATION: USED W/ Packet.h
    void makeTransportPack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length){
        Package->src = src;
        Package->dest = dest;
        Package->TTL = TTL;
        Package->seq = seq;
        Package->protocol = protocol;
        memcpy(Package->payload, payload, length);
   }
}