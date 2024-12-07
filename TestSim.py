#ANDES Lab - University of California, Merced
#Author: UCM ANDES Lab
#$Author: abeltran2 $
#$LastChangedDate: 2014-08-31 16:06:26 -0700 (Sun, 31 Aug 2014) $
#! /usr/bin/python
import sys
from TOSSIM import *
from CommandMsg import *

class TestSim:
    moteids=[]
    # COMMAND TYPES
    CMD_PING = 0
    CMD_NEIGHBOR_DUMP = 1
    CMD_ROUTE_DUMP=3
    CMD_TEST_CLIENT=4 #project 3
    CMD_TEST_SERVER=5 #project 3
    CMD_FLOOD=7
    CMD_ROUTE=8
    CMD_HELLO=9
    CMD_BROADCAST_MSG=10

    # CHANNELS - see includes/channels.h
    COMMAND_CHANNEL="command";
    GENERAL_CHANNEL="general";

    # Project 1
    NEIGHBOR_CHANNEL="neighbor";
    FLOODING_CHANNEL="flooding";

    # Project 2
    ROUTING_CHANNEL="routing";

    # Project 3
    TRANSPORT_CHANNEL="transport";
    DEBUG_CHANNEL="print";

    # Project 4
    CHAT_CHANNEL="chat";

    # Personal Debuggin Channels for some of the additional models implemented.
    HASHMAP_CHANNEL="hashmap";

    # Test Channel
    # DEBUG_CHANNEL="debug";

    # Initialize Vars
    numMote=0

    def __init__(self):
        self.t = Tossim([])
        self.r = self.t.radio()

        #Create a Command Packet
        self.msg = CommandMsg()
        self.pkt = self.t.newPacket()
        self.pkt.setType(self.msg.get_amType())

    # Load a topo file and use it.
    def loadTopo(self, topoFile):
        print 'Creating Topo!'
        # Read topology file.
        topoFile = 'topo/'+topoFile
        f = open(topoFile, "r")
        self.numMote = int(f.readline());
        print 'Number of Motes', self.numMote
        for line in f:
            s = line.split()
            if s:
                print " ", s[0], " ", s[1], " ", s[2];
                self.r.add(int(s[0]), int(s[1]), float(s[2]))
                if not int(s[0]) in self.moteids:
                    self.moteids=self.moteids+[int(s[0])]
                if not int(s[1]) in self.moteids:
                    self.moteids=self.moteids+[int(s[1])]

    # Load a noise file and apply it.
    def loadNoise(self, noiseFile):
        if self.numMote == 0:
            print "Create a topo first"
            return;

        # Get and Create a Noise Model
        noiseFile = 'noise/'+noiseFile;
        noise = open(noiseFile, "r")
        for line in noise:
            str1 = line.strip()
            if str1:
                val = int(str1)
            for i in self.moteids:
                self.t.getNode(i).addNoiseTraceReading(val)

        for i in self.moteids:
            print "Creating noise model for ",i;
            self.t.getNode(i).createNoiseModel()

    def bootNode(self, nodeID):
        if self.numMote == 0:
            print "Create a topo first"
            return;
        self.t.getNode(nodeID).bootAtTime(1333*nodeID);

    def bootAll(self):
        i=0;
        for i in self.moteids:
            self.bootNode(i);

    def moteOff(self, nodeID):
        self.t.getNode(nodeID).turnOff();

    def moteOn(self, nodeID):
        self.t.getNode(nodeID).turnOn();

    def run(self, ticks):
        for i in range(ticks):
            self.t.runNextEvent()

    # Rough run time. tickPerSecond does not work.
    def runTime(self, amount):
        self.run(amount*1000)

    # Generic Command
    def sendCMD(self, ID, dest, payloadStr):
        print 'in sendCMD';
        self.msg.set_dest(dest);
        self.msg.set_id(ID);
        self.msg.setString_payload(payloadStr)

        self.pkt.setData(self.msg.data)
        self.pkt.setDestination(dest)
        self.pkt.deliver(dest, self.t.time()+5)

    def ping(self, source, dest, msg):
        self.sendCMD(self.CMD_PING, source, "{0}{1}".format(chr(dest),msg));

    def neighborDMP(self, destination):
        self.sendCMD(self.CMD_NEIGHBOR_DUMP, destination, "neighbor command");

    def routeDMP(self, destination):
        self.sendCMD(self.CMD_ROUTE_DUMP, destination, "routing command");

    def addChannel(self, channelName, out=sys.stdout):
        print 'Adding Channel', channelName;
        self.t.addChannel(channelName, out);

    # For Project 1 (Flooding)
    def flood(self, source, dest, TTL, seqID, msg):
        print 'in flood method';
        self.sendCMD(self.CMD_FLOOD, source, "{0}{1}{2}{3}".format(chr(dest),chr(TTL),chr(seqID),msg));

    # For Project 2 (Routing)
    def routing(self, source, dest, TTL, seqID, msg):
        print 'in routing method';
        self.sendCMD(self.CMD_ROUTE, source, "{0}{1}{2}{3}".format(chr(dest),chr(TTL),chr(seqID),msg));

    # For Project 3 (Reliability / Transport)
    def createClient(self, client, server, clientPort, serverPort, transfer):
        print 'in createClient()';
        self.sendCMD(self.CMD_TEST_CLIENT, client, "{0}{1}{2}{3}".format(chr(server),chr(clientPort),chr(serverPort),chr(transfer)));

    def createServer(self, address, port):
        print 'in createServer()';
        self.sendCMD(self.CMD_TEST_SERVER, address, "{0}".format(chr(port)));

    # For Project 4 (Chat Client & Server)
    def serverConnection(self, username, clientPort, clientNode):
        print '\nPython: in serverConnection()';
        self.sendCMD(self.CMD_HELLO, clientNode, "{0}{1}".format(chr(clientPort),username));

    def broadcastMsg(self, clientNode, msg):
        print 'Python: in broadcastMsg()';
        self.sendCMD(self.CMD_BROADCAST_MSG, clientNode, "{0}".format(msg));

def main():
    s = TestSim();
    s.runTime(10);
    s.loadTopo("pizza.topo"); #commented out to test a smaller topology
    s.bootAll();
 
    s.addChannel(s.CHAT_CHANNEL);
    
    
    s.runTime(100);
    s.createServer(1,41); #initating server at node[1] and binding to port[41]
    s.runTime(10);
    s.serverConnection("hello ralwar 3\r\n",3,2); #clientPort [3] no longer being used, need to remove it
    s.runTime(100);
    s.serverConnection("hello rpatroo 21\r\n",21,3); #clientPort [21] no longer being used, need to remove it
    s.runTime(100);
    s.serverConnection("msg everyone\r\n",0,2); #clientPort [21] no longer being used, need to remove it
    s.runTime(100);
    s.serverConnection("whisper rpatroo Hi!\r\n",0,2); #clientPort [0] no longer being used, need to remove it
    s.runTime(100);
    s.serverConnection("listusr\r\n",3,2); #clientPort [3] no longer being used, can delete it
    s.runTime(1000);



if __name__ == '__main__':
    main()