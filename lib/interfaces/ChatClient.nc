
interface ChatClient{
    command error_t handleMsg(char* payload);

    command uint8_t checkCommand(char* payload, char* cmd);

    command uint8_t checkCommandServ(char* payload, char* cmd);

    command void updateUsernames(char* payload, uint8_t startIdx, uint8_t len, uint16_t userNode);

    command void broadcastMsg(char* payload, uint8_t payloadLen);

    command void whisper(char* payload, uint8_t startIdx, uint8_t len);

    command void listOfUsers(uint16_t node);

    command void recievedList(char* payload, uint16_t characterCount);

    command uint16_t getBroadcastState();

    command void updateFlag(uint8_t state);
}