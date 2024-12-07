import sys
from TOSSIM import *
from CommandMsg import *


class TestSim:
    moteids = []
    # COMMAND TYPES
    CMD_PING = 0
    CMD_NEIGHBOR_DUMP = 1
    CMD_ROUTE_DUMP = 3
    CMD_BROADCAST = 4  # Added for broadcast testing
    CMD_WHISPER = 5    # Added for whisper testing
    CMD_LIST_USERS = 6 # Added for listUsers testing

    # CHANNELS
    COMMAND_CHANNEL = "command"
    GENERAL_CHANNEL = "general"
    TRANSPORT_CHANNEL = "transport"
    BROADCAST_CHANNEL = "broadcast"

    numMote = 0  # Initialize mote count

    def __init__(self):
        self.t = Tossim([])
        self.r = self.t.radio()

        # Create a Command Packet
        self.msg = CommandMsg()
        self.pkt = self.t.newPacket()
        self.pkt.setType(self.msg.get_amType())

    def loadTopo(self, topoFile):
        print('Creating Topo!')
        topoFile = 'topo/' + topoFile
        f = open(topoFile, "r")
        self.numMote = int(f.readline())
        print('Number of Motes', self.numMote)
        for line in f:
            s = line.split()
            if s:
                self.r.add(int(s[0]), int(s[1]), float(s[2]))
                if int(s[0]) not in self.moteids:
                    self.moteids.append(int(s[0]))
                if int(s[1]) not in self.moteids:
                    self.moteids.append(int(s[1]))

    def loadNoise(self, noiseFile):
        if self.numMote == 0:
            print("Create a topo first")
            return
        noiseFile = 'noise/' + noiseFile
        noise = open(noiseFile, "r")
        for line in noise:
            str1 = line.strip()
            if str1:
                val = int(str1)
            for i in self.moteids:
                self.t.getNode(i).addNoiseTraceReading(val)
        for i in self.moteids:
            print("Creating noise model for ", i)
            self.t.getNode(i).createNoiseModel()

    def bootNode(self, nodeID):
        self.t.getNode(nodeID).bootAtTime(1333 * nodeID)

    def bootAll(self):
        for i in self.moteids:
            self.bootNode(i)

    def run(self, ticks):
        for i in range(ticks):
            self.t.runNextEvent()

    def runTime(self, amount):
        self.run(amount * 1000)

    def sendCMD(self, ID, dest, payloadStr):
        self.msg.set_dest(dest)
        self.msg.set_id(ID)
        self.msg.setString_payload(payloadStr)

        self.pkt.setData(self.msg.data)
        self.pkt.setDestination(dest)
        self.pkt.deliver(dest, self.t.time() + 5)

    def ping(self, source, dest, msg):
        self.sendCMD(self.CMD_PING, source, f"{chr(dest)}{msg}")

    def broadcastMsg(self, source, msg):
        self.sendCMD(self.CMD_BROADCAST, source, msg)

    def whisper(self, source, dest, msg):
        self.sendCMD(self.CMD_WHISPER, source, f"{chr(dest)}{msg}")

    def listOfUsers(self, source):
        self.sendCMD(self.CMD_LIST_USERS, source, "list users")

    def addChannel(self, channelName, out=sys.stdout):
        print('Adding Channel', channelName)
        self.t.addChannel(channelName, out)


def main():
    s = TestSim()
    s.loadTopo("example.topo")  # Load topology file
    s.loadNoise("no_noise.txt") # Load noise file
    s.bootAll()                 # Boot all nodes
    s.addChannel(s.GENERAL_CHANNEL)
    s.addChannel(s.COMMAND_CHANNEL)
    s.addChannel(s.TRANSPORT_CHANNEL)
    s.addChannel(s.BROADCAST_CHANNEL)

    s.runTime(10)  # Run the simulation for 10 seconds

    # Test commands
    print("\n--- Testing Ping ---")
    s.ping(1, 2, "Hello from Node 1 to Node 2!")

    s.runTime(5)

    print("\n--- Testing Broadcast Message ---")
    s.broadcastMsg(1, "This is a broadcast message from Node 1!")

    s.runTime(5)

    print("\n--- Testing Whisper Command ---")
    s.whisper(1, 3, "Private message from Node 1 to Node 3!")

    s.runTime(5)

    print("\n--- Testing List of Users ---")
    s.listOfUsers(1)

    s.runTime(5)

    print("\n--- Turning Off Node 3 ---")
    s.moteOff(3)

    s.runTime(5)

    print("\n--- Rebooting Node 3 ---")
    s.bootNode(3)

    s.runTime(10)

if __name__ == '__main__':
    main()
