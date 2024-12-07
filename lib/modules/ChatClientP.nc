//Auth: Zaid Laffta
// Winter 2024
// CSE 160

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
   uses interface Hashmap<uint16_t> as userTable; 
   uses interface Hashmap<uint16_t> as nodePortTable; 
   uses interface List<uint32_t> as broadcastList;
   uses interface Timer<TMilli> as broadcastTimer;
}


implementation {
   // 2D array to store user keys (10 users, 15 characters each)
   uint8_t userKeyArray [10][15]; 
   uint8_t userIndex = 0; // Current index for user table
   uint8_t clientPort = 0; // Port used by the client
   uint16_t testNum = 0; // Test number variable (not currently used)
   uint16_t broadcastMsgLen = 0; // Length of the broadcast message
   uint16_t msgIndex = 0; // Index for message operations
   uint8_t broadcastFlag = 0; // State flag for broadcast
   char broadcastingMessage[SOCKET_BUFFER_SIZE]; // Buffer for the broadcast message

   // Retrieves client port from the payload
   uint8_t getClientPort(char* payload, uint8_t idx);

   // Finds a node based on username and its length
   uint16_t findNode(char* userToGoTo, uint16_t userGoLen);

   // Prints user key array for debugging
   void printUserKeyArr();

   // Prints table content for debugging
   void printTable();

   // Gets the length of the username, with a default size fallback
   uint16_t getUserNameLen(uint16_t defaultSize);

   // Event handler for the broadcast timer firing
   event void broadcastTimer.fired() {
      char messageSending[broadcastMsgLen]; // Temporary message buffer
      uint32_t* userKeys = call userTable.getKeys(); // Retrieve all user keys
      uint8_t i = 0; // Loop variable

      if (broadcastFlag == 2) { // If flag indicates a broadcast in progress
         for (i = 0; i < broadcastMsgLen; i++) {
            if (broadcastingMessage[i-1] == '\n') // Stop if a newline character is found
               break;
            else
               messageSending[i] = broadcastingMessage[i];
         }

         // Send a transport message to the client
         call Transport.addClient(
            call userTable.get(call broadcastList.front()), 
            41, 
            call nodePortTable.get(call userTable.get(call broadcastList.front())), 
            messageSending
         );

         call broadcastList.popfront(); // Remove the first entry from the broadcast list
         broadcastFlag = 1; // Update the flag to indicate completion
      }

      if (broadcastFlag == 3) // Stop timer if broadcastFlag indicates so
         call broadcastTimer.stop();
   }
}

   command error_t ChatClient.handleMsg(char* payload) {
   uint16_t len = strlen(payload); // Calculate the length of the payload
   uint8_t i;

   // Check if the command starts with "hello "
   if (call ChatClient.checkCommand(payload, "hello ") == 1) {
      getClientPort(payload, 5); // Extract client port starting at index 5
      call Transport.addServer(clientPort); // Add a server for the client port
      call Transport.addClient(1, clientPort, 41, payload); // Add client to the transport layer
   }
   // Check if the command starts with "msg "
   else if (call ChatClient.checkCommand(payload, "msg ") == 2)
      call Transport.addClient(1, clientPort, 41, payload); // Handle message command
   
   // Check if the command starts with "whisper "
   else if (call ChatClient.checkCommand(payload, "whisper ") == 3)
      call Transport.addClient(1, clientPort, 41, payload); // Handle whisper command
   
   // Check if the command is "listusr"
   else if (call ChatClient.checkCommand(payload, "listusr") == 4) {
      call Transport.addClient(1, clientPort, 41, payload); // Handle list users command
   }
   else
      dbg(GENERAL_CHANNEL, "Command Not Found\n"); // Print debug message if no valid command is found
}


   command uint8_t ChatClient.checkCommand(char* payload, char* cmd) {
   uint16_t len = strlen(payload); // Get the length of the payload
   uint8_t i;

   // If payload is shorter than the command, return 0 (not a match)
   if (len < strlen(cmd))
      return 0;

   // Check for a 6-character command
   if (strlen(cmd) == 6) {
      for (i = 0; i < 6; i++) {
         if (!(payload[i] == cmd[i])) // Compare each character
            return 0; // Not a match
      }
      return 1; // Match found, return 1
   }
   // Check for a 4-character command
   else if (strlen(cmd) == 4) {
      for (i = 0; i < 4; i++) {
         if (!(payload[i] == cmd[i])) 
            return 0;
      }
      return 2; // Match found, return 2
   }
   // Check for an 8-character command
   else if (strlen(cmd) == 8) {
      for (i = 0; i < 8; i++) {
         if (!(payload[i] == cmd[i])) 
            return 0;
      }
      return 3; // Match found, return 3
   }
   // Check for a 7-character command
   else if (strlen(cmd) == 7) {
      for (i = 0; i < 7; i++) {
         if (!(payload[i] == cmd[i])) 
            return 0;
      }
      return 4; // Match found, return 4
   }

   return 0; // No match found
}


   command uint8_t ChatClient.checkCommandServ(char* payload, char* cmd) {
   uint16_t len = strlen(payload); // Get the length of the payload
   uint8_t i;

   // Check if the command is 6 characters long
   if (strlen(cmd) == 6) {
      for (i = 0; i < 6; i++) {
         if (!(payload[8 * i] == cmd[i])) // Compare every 8th character in payload
            return 0; // Not a match
      }
      return 1; // Match found
   }
   // Check if the command is 4 characters long
   else if (strlen(cmd) == 4) {
      for (i = 0; i < 4; i++) {
         if (!(payload[8 * i] == cmd[i])) 
            return 0;
      }
      return 2; // Match found
   }
   // Check if the command is 'whisper ' (8 characters)
   else if (strlen(cmd) == 8) {
      for (i = 0; i < 8; i++) {
         if (!(payload[8 * i] == cmd[i])) 
            return 0;
      }
      return 3; // Match found
   }
   // Check if the command is 'listusr' (7 characters)
   else if (strlen(cmd) == 7) {
      for (i = 0; i < 7; i++) {
         if (!(payload[8 * i] == cmd[i])) 
            return 0;
      }
      return 4; // Match found
   }
   // Check if the command is 'listUsrRply ' (12 characters)
   else if (strlen(cmd) == 12) {
      for (i = 0; i < 12; i++) {
         if (!(payload[8 * i] == cmd[i])) 
            return 0;
      }
      return 5; // Match found
   }

   return 0; // No match found
}


  command void ChatClient.updateUsernames(char* payload, uint8_t startIdx, uint8_t len, uint16_t userNode) {
   uint8_t i, j;
   char* num[4];
   testNum = 0;

   // Extract username from payload and store in userKeyArray
   for (i = 0; i < len; i++) {
      if (payload[startIdx] == ' ') // Stop at a space
         break;
      userKeyArray[userIndex][i] = payload[startIdx];
      startIdx += 8; // Move to the next character position
   }

   call userTable.insert(userIndex + 1, (uint16_t)userNode); // Insert userNode into userTable
   userIndex = userIndex + 1;

   // Extract port number from the payload
   for (j = 0; j < 5; j++) {
      if (payload[startIdx] == ' ') {} // Skip spaces
      else if (num[j] == '\r') { // Stop at carriage return
         break;
      } else {
         if ((payload[startIdx] <= 57) && (payload[startIdx] >= 48)) { // Check if digit
            if (testNum == 0) {
               testNum = payload[startIdx] - 48; // First digit
            } else { 
               testNum = testNum * 10 + (payload[startIdx] - 48); // Accumulate multi-digit number
            }
         }
      }
      startIdx += 8; // Move to the next character position
   }

   call nodePortTable.insert(userNode, testNum); // Insert port number into nodePortTable

   num[j] = '\r'; // End line markers
   num[j + 1] = '\n';
}


  command void ChatClient.broadcastMsg(char* payload, uint8_t payloadLen) {
   char content[payloadLen]; // Temporary buffer to store message content
   uint8_t i, j;
   uint32_t* userKeys = call userTable.getKeys(); // Retrieve all user keys from the table

   broadcastMsgLen = payloadLen; // Store the length of the broadcast message

   // Copy message content into broadcastingMessage buffer
   for (i = 0; i < SOCKET_BUFFER_SIZE; i++) {
      if (payload[(8 * i) - 8] == '\n') // Stop copying at newline character
         break;
      else
         broadcastingMessage[i] = payload[8 * i]; // Copy spaced characters
   }

   // If this is the first broadcast
   if (broadcastFlag == 0) {
      // Copy payload into content buffer
      for (i = 0; i < SOCKET_BUFFER_SIZE; i++) {
         if (payload[(8 * i) - 8] == '\n') // Stop copying at newline
            break;
         else
            content[i] = payload[8 * i];
      }

      // Check if the node is not the server (empty userKeyArray)
      if ((char*)userKeyArray[0][0] == '\0') 
         dbg(GENERAL_CHANNEL, "ARRIVED MSG @ NODE[%d] | BROADCASTED MSG: %s", TOS_NODE_ID, content);
      else {
         // Push all user keys into the broadcast list
         for (i = 0; i < call userTable.size(); i++) {
            call broadcastList.pushback(userKeys[i]);
         }

         // Send the message to the first node in the list
         call Transport.addClient(
            call userTable.get(call broadcastList.front()), 
            41, 
            call nodePortTable.get(call userTable.get(call broadcastList.front())), 
            content
         );
         
         call broadcastList.popfront(); // Remove the first node after sending
         call broadcastTimer.startPeriodicAt(call broadcastTimer.getNow() + 200, 200); // Start periodic timer
         broadcastFlag = 1; // Set flag to indicate broadcast is ongoing
      }
   }
}

   command void ChatClient.whisper(char* payload, uint8_t startIdx, uint8_t len) {
   char userToSendTo[15];    // Buffer to store the username to whisper to
   char content[len];        // Buffer to store the message content
   uint8_t i, j, userLen = 0;
   uint16_t destNode;        // Destination node ID
   uint16_t nodeKey;         // Key of the destination user

   // Extract the recipient username from the payload
   for (i = 0; i < 15; i++) {
      if (payload[startIdx] == ' ') // Stop at the first space
         break;
      userToSendTo[i] = payload[startIdx];
      userLen++;
      startIdx += 8; // Move to the next spaced character
   }

   // Null-terminate the rest of the userToSendTo buffer
   for (i = i; i < 15; i++)
      userToSendTo[i] = '\0';

   // Extract the message content from the payload
   for (i = 0; i < SOCKET_BUFFER_SIZE; i++) {
      if (payload[(8 * i) - 8] == '\n') // Stop at newline character
         break;
      else
         content[i] = payload[8 * i]; // Copy spaced characters
   }

   // Find the destination node key based on the username
   nodeKey = findNode(userToSendTo, userLen);

   // If the node key is 100, this means the message is intended for the current node
   if (nodeKey == 100) {
      dbg(GENERAL_CHANNEL, "ARRIVED MSG @ NODE[%d] | WHISPERED MSG: %s", TOS_NODE_ID, content);
   } else {
      // Retrieve the destination node ID and send the message
      destNode = call userTable.get(nodeKey + 1);
      call Transport.addClient(destNode, 41, call nodePortTable.get(destNode), content);
   }
}


   command void ChatClient.listOfUsers(uint16_t node) {
   uint16_t msgSize = getUserNameLen(14); // Calculate the total message size
   char sendMsg[msgSize];                 // Buffer to store the message to send
   uint8_t i = 0;                         // Index for sendMsg buffer
   uint8_t r, c;                          // Row and column counters for userKeyArray

   // Add "listUsrRply " prefix to the message
   for (i = 0; i < 12; i++) 
      sendMsg[i] = ("listUsrRply ")[i];

   // Add usernames from userKeyArray to the message
   for (r = 0; r < 10; r++) {            // Loop through rows (users)
      for (c = 0; c < 15; c++) {         // Loop through columns (username characters)
         if (userKeyArray[r][c] == 0) {} // Skip empty characters
         else {
            sendMsg[i] = userKeyArray[r][c]; // Append valid characters
            i = i + 1;
         }
      }
      if (userKeyArray[r][c] == 0) {}    // Skip if the row is empty
      else {
         sendMsg[i] = ' '; // Add a space after each username
         i = i + 1;
      }
   }

   // Terminate the message with carriage return and newline
   sendMsg[i] = '\r';
   sendMsg[i + 1] = '\n';

   // Send the message to the specified node
   call Transport.addClient(node, 41, call nodePortTable.get(node), sendMsg);
}


   command void ChatClient.recievedList(char* payload, uint16_t characterCount) {
   uint8_t i;
   char userNameFromServ[characterCount]; // Buffer to store the user list

   // Extract user list from payload
   for (i = 0; i < SOCKET_BUFFER_SIZE; i++) {
      if (payload[(8 * i) - 8] == '\n') // Stop at newline character
         break;
      else
         userNameFromServ[i] = payload[8 * i]; // Copy spaced characters
   }

   // Print the received user list
   dbg(GENERAL_CHANNEL, "ARRIVED MSG @ NODE[%d] | USER LIST: %s", TOS_NODE_ID, userNameFromServ);
}

command uint16_t ChatClient.getBroadcastState() {
   return call broadcastList.size(); // Return the size of the broadcast list
}

command void ChatClient.updateFlag(uint8_t state) {
   broadcastFlag = state; // Update the broadcast flag state
}

uint16_t findNode(char* userToGoTo, uint16_t userGoLen) {
   uint8_t i, j;
   uint16_t flag = 0;

   // Search for the username in userKeyArray
   for (i = 0; i < 10; i++) { // Loop through rows (user entries)
      flag = 0; 
      for (j = 0; j < 15; j++) { // Loop through columns (username characters)
         if ((flag != 2) && (userToGoTo[j] == userKeyArray[i][j])) // Compare characters
            flag = 1; // Partial match
         else
            flag = 2; // Mismatch
      }

      if (flag == 1) // If a full match is found, return the row index
         return i;
   }

   return 100; // Return 100 if no match is found
}

uint8_t getClientPort(char* payload, uint8_t idx) {
   uint16_t len = strlen(payload); // Get payload length
   uint8_t i;
   uint8_t spaceIndex = 0; // Index of the last space character
   uint8_t count = 1;      // Multiplier for port number parsing

   // Find the position of the last space and newline terminator
   for (i = idx; i < len - 1; i++) {
      if (payload[i] == ' ')
         spaceIndex = i;
      if ((payload[i] == '\r') && (payload[i + 1] == '\n')) 
         break;
   }

   // Extract and calculate client port from payload
   for (i = i - 1; i > spaceIndex; i--) {
      clientPort += (payload[i] - '0') * count; // Convert character to integer
      count *= 10; // Increase multiplier for the next digit
   }

   return clientPort; // Return the extracted port
}

uint16_t getUserNameLen(uint16_t defaultSize) {
   uint16_t userNameCharacters = 0; // Counter for total username characters
   uint8_t i, j;

   // Count characters in userKeyArray (usernames)
   for (i = 0; i < 10; i++) {
      for (j = 0; j < 15; j++) {
         if (userKeyArray[i][j] != 0) // Count valid characters
            userNameCharacters++;
      }
      if (userKeyArray[i][j] == 0) // Stop when an empty entry is encountered
         break;
      else
         userNameCharacters++; // Include space after each username
   }
   return defaultSize + userNameCharacters; // Add default size and return
}

void printUserKeyArr() {
   uint8_t i, j;
   char user[15]; // Temporary buffer to store a username

   dbg(GENERAL_CHANNEL, "\nPRINT USERKEYARR [2D Array]\n");
   dbg(GENERAL_CHANNEL, "printUserKeyArr | userIndex [%d]\n", userIndex);

   // Iterate through the userKeyArray and print valid usernames
   for (i = 0; i < 10; i++) {
      for (j = 0; j < 15; j++) {
         if (userKeyArray[i][j] == 0) // Stop at null character
            break;
         user[j] = userKeyArray[i][j]; // Copy character into buffer
      }
      if (user[0] == '\0') // Stop if the first entry is empty
         break;

      dbg(GENERAL_CHANNEL, "Key [%d] | User [%s]\n", i, user);
      user[0] = '\0'; // Reset buffer for next username
   }
}

void printTable() {
   uint8_t row;

   dbg(GENERAL_CHANNEL, "\nPRINT USERTABLE [HashTable]\n");
   dbg(GENERAL_CHANNEL, "printTable | sizeOfTable [%d] | userIndex [%d]\n", 
       call userTable.size(), userIndex);

   // Iterate through the user table and print keys, node values, and ports
   for (row = 0; row < userIndex; row++) {
      if (call userTable.contains(row + 1)) { // Check if key exists in the table
         dbg(GENERAL_CHANNEL, "HashTable Key [%d] | Value (Node) [%d] | Port [%d]\n", 
             row, 
             call userTable.get(row + 1), 
             call nodePortTable.get(call userTable.get(row + 1)));
      }
   }
}
