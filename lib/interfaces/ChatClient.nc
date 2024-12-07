interface ChatClient {
    // Handle an incoming message
    command error_t handleMsg(char* payload);

    // Check if payload matches a command
    command uint8_t checkCommand(char* payload, char* cmd);

    // Check if payload matches a server command
    command uint8_t checkCommandServ(char* payload, char* cmd);

    // Update usernames in the chat group
    command void updateUsernames(char* payload, uint8_t startIdx, uint8_t len, uint16_t userNode);

    // Broadcast a message to all nodes
    command void broadcastMsg(char* payload, uint8_t payloadLen);

    // Send a private message (whisper)
    command void whisper(char* payload, uint8_t startIdx, uint8_t len);

    // Request the list of users from a node
    command void listOfUsers(uint16_t node);

    // Process received list of usernames
    command void recievedList(char* payload, uint16_t characterCount);

    // Get the current broadcast state
    command uint16_t getBroadcastState();

    // Update a flag state
    command void updateFlag(uint8_t state);
}
