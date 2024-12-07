

#include "../../includes/CommandMsg.h"
#include "../../includes/command.h"
#include "../../includes/channels.h"
#include "../../includes/socket.h"
#include "../../includes/transportPacket.h"
#include "../../includes/packet.h"
#include "../../includes/protocol.h"

module ChatClientP{
   provides interface ChatClient;

   uses interface SimpleSend as Sender;
   uses interface Transport;

   uses interface Hashmap<uint16_t> as userTable; // key [2D array index w/ userName] | value [node associated w/ userName]

   uses interface Hashmap<uint16_t> as nodePortTable; // key [node] | value [port id associated w/ node]

   uses interface List<uint32_t> as broadcastList;

   uses interface Timer<TMilli> as broadcastTimer;
}

implementation{
   uint8_t userKeyArray [10][15]; // [rows] [cols] //10 usernames to store w/ each username allowing 15 chars
   uint8_t userIndex = 0; // denotes last stored username [column]
   uint8_t clientPort = 0;
   uint16_t testNum=0;
   uint16_t broadcastMsgLen = 0;
   uint16_t msgIndex = 0; // this is for the timer's broadcast msg [index of the clientKey from userTable]
   uint8_t broadcastFlag = 0; // 0 : not started the broadcast | 1 : broadcasting in progress | 2 : no broadcasting in progress
   char broadcastingMessage[SOCKET_BUFFER_SIZE];

   // Prototypes
   uint8_t getClientPort(char* payload, uint8_t idx);
   uint16_t findNode(char* userToGoTo, uint16_t userGoLen);
   void printUserKeyArr();
   void printTable();
   uint16_t getUserNameLen(uint16_t defaultSize);
   // uint16_t getPayloadLen(uint16_t defaultSize);
   // char* truncate(char* payload);

   event void broadcastTimer.fired() {
      char messageSending[broadcastMsgLen];
      uint32_t* userKeys = call userTable.getKeys();
      uint8_t i=0;

      if (broadcastFlag == 2){
         for(i=0; i<broadcastMsgLen; i++){
            if (broadcastingMessage[i-1] == '\n')
               break;
            else
               messageSending[i] = broadcastingMessage[i];
         }
         // dbg(GENERAL_CHANNEL, "SUBSEQUENT call userTable.get(userKeys[call broadcastList.front()]) = [%d] | call nodePortTable.get(call userTable.get(call broadcastList.front())) = [%d]\n", call userTable.get(userKeys[call broadcastList.front()]), call nodePortTable.get(call userTable.get(call broadcastList.front())));
         // call Transport.addClient(call userTable.get(userKeys[call broadcastList.front()]), 41, call nodePortTable.get(call userTable.get(call broadcastList.front())), messageSending);
         
         // dbg(GENERAL_CHANNEL, "SUBSEQUENT call userTable.get(call broadcastList.front()) = [%d] | call nodePortTable.get(call userTable.get(call broadcastList.front())) = [%d]\n", call userTable.get(call broadcastList.front()), call nodePortTable.get(call userTable.get(call broadcastList.front())));
         call Transport.addClient(call userTable.get(call broadcastList.front()), 41, call nodePortTable.get(call userTable.get(call broadcastList.front())), messageSending);
         
         call broadcastList.popfront();
         broadcastFlag = 1;
      }

      if (broadcastFlag == 3)
         call broadcastTimer.stop();

   
   }

   command error_t ChatClient.handleMsg(char* payload){ // "executed from Python"
      uint16_t len = strlen(payload);
      uint8_t i;
      
      // dbg(GENERAL_CHANNEL, "MSG [%s]\n", payload);

      if (call ChatClient.checkCommand(payload, "hello ") == 1){
         getClientPort(payload, 5);
         // dbg(GENERAL_CHANNEL, "MSG [%s] | ClientPort [%d]\n", payload, clientPort);
         call Transport.addServer(clientPort);
         call Transport.addClient(1,clientPort,41,payload); //1: serverNode | clientPort:clientPort | 41:serverPort | payload:Msg being sent;
      }
      else if (call ChatClient.checkCommand(payload, "msg ") == 2)
         call Transport.addClient(1,clientPort,41,payload);
      else if (call ChatClient.checkCommand(payload, "whisper ") == 3)
         call Transport.addClient(1,clientPort,41,payload);
      else if (call ChatClient.checkCommand(payload, "listusr") == 4){
         call Transport.addClient(1,clientPort,41,payload);
      }
      else
         dbg(GENERAL_CHANNEL, "Command Not Found\n");
   }

   command uint8_t ChatClient.checkCommand(char* payload, char* cmd){
      uint16_t len = strlen(payload);
      uint8_t i;

      // check if valid command
      if (len < strlen(cmd))
         return 0;
      
      // check if 'hello '
      if (strlen(cmd) == 6){
         for(i=0; i<6; i++){
            if (!(payload[i] == cmd[i]))
               return 0;
         }
         // dbg(GENERAL_CHANNEL, "checkCmd | userIndex [%d]\n", userIndex);
         return 1;
      }
      // check if 'msg '
      else if (strlen(cmd) == 4){
         for(i=0; i<4; i++){
            if (!(payload[i] == cmd[i]))
               return 0;
         }
         return 2;
      }
      // check if 'whisper '
      else if (strlen(cmd) == 8){
         for(i=0; i<8; i++){
            if (!(payload[i] == cmd[i]))
               return 0;
         }
         return 3;
      }
      // check if 'listusr'
      else if (strlen(cmd) == 7){
         for(i=0; i<7; i++){
            if (!(payload[i] == cmd[i]))
               return 0;
         }
         return 4;
      }

      return 0;
   }

   command uint8_t ChatClient.checkCommandServ(char* payload, char* cmd){
      uint16_t len = strlen(payload);
      uint8_t i;

      // dbg(GENERAL_CHANNEL, "payload length[%d] | cmd length[%d]\n", strlen(payload), strlen(cmd));
      
      // check if 'hello '
      if (strlen(cmd) == 6){
         for(i=0; i<6; i++){
            if (!(payload[8*i] == cmd[i]))
               return 0;
         }
         return 1;
      }
      // check if 'msg '
      else if (strlen(cmd) == 4){
         for(i=0; i<4; i++){
            if (!(payload[8*i] == cmd[i]))
               return 0;
         }
         return 2;
      }
      // check if 'whisper '
      else if (strlen(cmd) == 8){
         for(i=0; i<8; i++){
            if (!(payload[8*i] == cmd[i]))
               return 0;
         }
         return 3;
      }
      // check if 'listusr'
      else if (strlen(cmd) == 7){
         for(i=0; i<7; i++){
            if (!(payload[8*i] == cmd[i]))
               return 0;
         }
         return 4;
      }
      // check if 'listUsrRply '
      else if (strlen(cmd) == 12){
         for(i=0; i<12; i++){
            if (!(payload[8*i] == cmd[i]))
               return 0;
         }
         return 5;
      }

      return 0;
   }

   command void ChatClient.updateUsernames(char* payload, uint8_t startIdx, uint8_t len, uint16_t userNode){
      uint8_t i, j;
      char* num[4];
      testNum = 0;
      // dbg(GENERAL_CHANNEL, "\nin updateUsernames()\n");

      // ---------------------------------------------- To get the username --------------------------------------------
      for(i=0; i<len; i++){
         if (payload[startIdx] == ' ')
            break;
         userKeyArray[userIndex][i] = payload[startIdx];
         startIdx+=8;
      }
      // dbg(GENERAL_CHANNEL, "At userTable.insert() userIndex[%d], userNode[%d]\n", userIndex+1, userNode);
      call userTable.insert(userIndex+1, (uint16_t)userNode);
      userIndex = userIndex + 1;
      // dbg(GENERAL_CHANNEL, "After userTable.insert() userIndex[%d], userNode[%d]\n", userIndex, call userTable.get(userIndex));

      // ---------------------------------------------- To get the client Port --------------------------------------------
      // Trying to get clientPort after the userName comes in
      for(j=0; j<5; j++){
         if (payload[startIdx] == ' ') {}
            // dbg(GENERAL_CHANNEL, "if   | payload[startIdx] c[%c] d[%d]\n", payload[startIdx], payload[startIdx]);
         else if (num[j] == '\r'){ 
            // dbg(GENERAL_CHANNEL, "elif | 'r'\n");
            break; 
         } // does not seem to be going into this break statement for some reason hence it continues to do logic and gets 2 large a num
         else {
            // dbg(GENERAL_CHANNEL, "else |payload[startIdx] c[%c] d[%d]\n", payload[startIdx], payload[startIdx]);
            if ((payload[startIdx] <= 57) && (payload[startIdx] >= 48)) {
               if (testNum == 0){
                  testNum = payload[startIdx] - 48;
                  // dbg(GENERAL_CHANNEL, "if | TestNum [%d] | payload[%d]\n", testNum, payload[startIdx]);
               }
               else { // gets the correct number by this point in testNum but does not retain it
                  testNum = testNum * 10;
                  // dbg(GENERAL_CHANNEL, "el | TestNum [%d] | payload[%d]\n", testNum, payload[startIdx]);
                  testNum = testNum + payload[startIdx] - 48;
                  // dbg(GENERAL_CHANNEL, "el | TestNum [%d] | payload[%d]\n", testNum, payload[startIdx]);
               }
            }
         }
         startIdx+=8;
      }
      // dbg(GENERAL_CHANNEL, "out | TestNum [%d]\n", testNum);
      call nodePortTable.insert(userNode, testNum);

      num[j] = '\r';
      num[j+1] = '\n';

      // printUserKeyArr(); // testing
      // printTable(); // testing
   }

   command void ChatClient.broadcastMsg(char* payload, uint8_t payloadLen){
      char content[payloadLen];
      uint8_t i, j;
      uint32_t* userKeys = call userTable.getKeys();

      // dbg(GENERAL_CHANNEL, "IN ChatClient.broadcastMsg\n");

      broadcastMsgLen = payloadLen;
      for(i=0; i<SOCKET_BUFFER_SIZE; i++){
         if (payload[(8*i)-8] == '\n')
            break;
         else
           broadcastingMessage[i] = payload[8*i];
      }

      if (broadcastFlag == 0){
         for(i=0; i<SOCKET_BUFFER_SIZE; i++){
            if (payload[(8*i)-8] == '\n')
               break;
            else
               content[i] = payload[8*i];
         } // gives me the payload to print it out as a single string

         if ((char*)userKeyArray[0][0] == '\0') // this means we are not the server
            dbg(GENERAL_CHANNEL, "ARRIVED MSG @ NODE[%d] | BROADCASTED MSG: %s", TOS_NODE_ID, content);
         else {
            for(i=0; i<call userTable.size(); i++){
            // for(msgIndex=0; msgIndex<call userTable.size(); msgIndex++){
               // dbg(GENERAL_CHANNEL, "UserNode [%d] | UserPort [%d]\n", call userTable.get(userKeys[msgIndex]), call nodePortTable.get(call userTable.get(userKeys[msgIndex])));
               // call broadcastTimer.startOneShot(msgIndex*500);
               
               // dbg(GENERAL_CHANNEL, "userkeys[%d] = [%d] | UserNode [%d] | UserPort [%d]\n", i, userKeys[i], call userTable.get(userKeys[i]), call nodePortTable.get(call userTable.get(userKeys[i])));
               call broadcastList.pushback(userKeys[i]);
               
               // call Transport.addClient(call userTable.get(userKeys[i]), 41, call nodePortTable.get(call userTable.get(userKeys[i])), content);
            }

            // for(i=0; i<call broadcastList.size(); i++)
            //    dbg(GENERAL_CHANNEL, "broadcastList[%d] = [%d]\n", i, call broadcastList.get(i));

            // call Transport.addClient(call userTable.get(userKeys[0]), 41, call nodePortTable.get(call userTable.get(userKeys[0])), content);
            // dbg(GENERAL_CHANNEL, "FIRST call userTable.get(call broadcastList.front()) = [%d] | call nodePortTable.get(call userTable.get(call broadcastList.front())) = [%d]\n", call userTable.get(call broadcastList.front()), call nodePortTable.get(call userTable.get(call broadcastList.front())));
            call Transport.addClient(call userTable.get(call broadcastList.front()), 41, call nodePortTable.get(call userTable.get(call broadcastList.front())), content);
            call broadcastList.popfront();
            call broadcastTimer.startPeriodicAt(call broadcastTimer.getNow() + 200, 200);
            broadcastFlag = 1;
         }
      }
      // else if (broadcastFlag == 2){
      //    call Transport.addClient(call userTable.get(userKeys[call broadcastList.popfront()]), 41, call nodePortTable.get(call userTable.get(call broadcastList.popfront())), content);
      //    broadcastFlag = 1;
      // }
      
   }

   command void ChatClient.whisper(char* payload, uint8_t startIdx, uint8_t len){
      char userToSendTo[15];
      char content[len];
      uint8_t i,j, userLen;
      uint16_t destNode;
      uint16_t nodeKey;
      // dbg(GENERAL_CHANNEL, "In ChatClient.whisper for payload length [%d]\n", len);
      
      // ---------------------------------------------- To get the username to send to --------------------------------------------
      for(i=0; i<15; i++){
         if (payload[startIdx] == ' ')
            break;
         userToSendTo[i] = payload[startIdx];
         userLen ++;
         startIdx+=8;
      } // correctly gets username
      for(i=i; i<15; i++)
         userToSendTo[i] = '\0';

      for(i=0; i<SOCKET_BUFFER_SIZE; i++){
         if (payload[(8*i)-8] == '\n')
            break;
         else
            content[i] = payload[8*i];
      }

      nodeKey = findNode(userToSendTo, userLen);

      if (nodeKey == 100){ // in theory this means it found no users hence I am the reciever
         dbg(GENERAL_CHANNEL, "ARRIVED MSG @ NODE[%d] | WHISPERED MSG: %s", TOS_NODE_ID, content);
         // dbg(GENERAL_CHANNEL, "%s", content);
      }
      else {
         destNode = call userTable.get(nodeKey+1);
         // dbg(GENERAL_CHANNEL, "destNode for user [%d]\n", destNode);
         call Transport.addClient(destNode, 41, call nodePortTable.get(destNode), content);
      }
   }

   command void ChatClient.listOfUsers(uint16_t node){
      uint16_t msgSize = getUserNameLen(14);
      char sendMsg[msgSize];
      uint8_t i;
      uint8_t r, c;

      for(i=0; i<12; i++)
         sendMsg[i] = ("listUsrRply ")[i];

      for (r=0; r<10; r++){
         for (c=0; c<15; c++){
            if (userKeyArray[r][c] == 0) {}
            else {
               sendMsg[i] = userKeyArray[r][c];
               i = i+1;
            }
         }
         if (userKeyArray[r][c] == 0) {}
         else {
            // dbg(GENERAL_CHANNEL, "In else block for combination (sendMsg)\n");
            sendMsg[i] = ' ';
            i = i+1;
         }
      }

      sendMsg[i] = '\r';
      sendMsg[i+1] = '\n';

      // dbg(GENERAL_CHANNEL, "CHECKING sendMsg for size %d after userName\n", msgSize);
      // for(i=0; i<msgSize; i++)
      //    dbg(GENERAL_CHANNEL, "%c\n", sendMsg[i]);

      // dbg(GENERAL_CHANNEL, "sendMsg size[%d]\n", strlen(sendMsg));
      call Transport.addClient(node,41, call nodePortTable.get(node),sendMsg);
   }

   command void ChatClient.recievedList(char* payload, uint16_t characterCount) {
      uint8_t i;
      char userNameFromServ[characterCount];

      for(i=0; i<SOCKET_BUFFER_SIZE; i++){
         if (payload[(8*i)-8] == '\n')
            break;
         else
            userNameFromServ[i] = payload[8*i];
      }

      // dbg(GENERAL_CHANNEL, "-----------------------------------\n");
      // dbg(GENERAL_CHANNEL, "I have returned to NODE [%d] w/ the list of users:\n", TOS_NODE_ID);
      dbg(GENERAL_CHANNEL, "ARRIVED MSG @ NODE[%d] | USER LIST: %s", TOS_NODE_ID, userNameFromServ);
      
      // dbg(GENERAL_CHANNEL, "%s", userNameFromServ);
      // for(i=0; i<characterCount; i++)
      //    dbg(GENERAL_CHANNEL, "in recievedList [%c]\n", payload[8*i]);

      // for (i=0; i<strlen(payload)-16; i+=8){
      //    dbg(GENERAL_CHANNEL, "in recievedList [%c]\n", payload[i]);
      // }
      // dbg(GENERAL_CHANNEL, "[%.10s]\n", payload);
      // dbg(GENERAL_CHANNEL, "-----------------------------------\n");
   }

   command uint16_t ChatClient.getBroadcastState(){
      // return broadcastState;
      return call broadcastList.size();
   }

   command void ChatClient.updateFlag(uint8_t state){
      broadcastFlag = state;
   }

   uint16_t findNode(char* userToGoTo, uint16_t userGoLen){
      uint8_t i, j;
      uint16_t flag = 0; // 0: Start of new user | 1: found correct characters | 2: at least one character inaccurate
      // dbg(GENERAL_CHANNEL, "\nfindNode\n");
      for(i=0; i<10; i++){ // row
         flag = 0;
         for(j=0; j<15; j++){ // col
            // dbg(GENERAL_CHANNEL, "flag [%d] | userToGoTo[%d] = [%c] | userKeyArray[%d][%d] = [%c]\n", flag, j, userToGoTo[j], i, j, userKeyArray[i][j]);
            if ((flag != 2) && (userToGoTo[j] == userKeyArray[i][j]))
               flag = 1;
            else
               flag = 2;
         }

         if (flag == 1)
            return i;
      }

      return 100;
   }

   uint8_t getClientPort(char* payload, uint8_t idx){
      uint16_t len = strlen(payload);
      uint8_t i;
      uint8_t spaceIndex=0;
      uint8_t count=1;

      for(i=idx; i<len-1; i++){
         if (payload[i] == ' ')
            spaceIndex = i;
         if ((payload[i] == '\r') && (payload[i+1] == '\n'))
            break;
      }

      for(i = i-1; i > spaceIndex; i--){
         clientPort += (payload[i]-'0') * (count);
         count *= 10;
      }

      return clientPort;
   }

   uint16_t getUserNameLen(uint16_t defaultSize){
      uint16_t userNameCharacters = 0;
      uint8_t i, j;

      for(i=0; i<10; i++){
         for(j=0; j<15; j++){
            if (userKeyArray[i][j] != 0)
               userNameCharacters++;
         }
         if (userKeyArray[i][j] == 0)
            break;
         else
            userNameCharacters++;
      }
      return defaultSize + userNameCharacters;
   }

   void printUserKeyArr() {
      uint8_t i, j;
      char user[15];
      dbg(GENERAL_CHANNEL, "\nPRINT USERKEYARR [2d Array]\n");
      dbg(GENERAL_CHANNEL, "printUserKeyArr | userIndex [%d]\n", userIndex);
      for(i=0; i<10; i++){ // row
         for(j=0; j<15; j++){ // col
            if (userKeyArray[i][j] == 0)
               break;
            user[j] = userKeyArray[i][j];
            //dbg(GENERAL_CHANNEL, "COL[%d] ROW[%d] | %c\n", i, j, (char*)userKeyArray[i][j]);
            // dbg(GENERAL_CHANNEL, "COL[%d] ROW[%d] | %d\n", i, j, userKeyArray[i][j]);
         }
         if (user[0] == '\0')
            break;

         dbg(GENERAL_CHANNEL, "Key [%d] | User [%s]\n", i, user);
         user[0] = '\0';
      }
   }

   void printTable() {
      uint8_t row;
      dbg(GENERAL_CHANNEL, "\nPRINT USERTABLE [HashTable]\n");
      dbg(GENERAL_CHANNEL, "printTable | sizeOfTable [%d] | userIndex [%d]\n", call userTable.size(), userIndex);
      for(row=0; row < userIndex; row++){
         if (call userTable.contains(row+1))
            dbg(GENERAL_CHANNEL, "HashTable Key [%d] | Value (Node) [%d] | Port [%d]\n", row, call userTable.get(row+1), call nodePortTable.get(call userTable.get(row+1)));
      }
   }
}