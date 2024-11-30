#Zaid Laffta
#Winter 2024
# CSE 160
#This code is given by Dr. Cerpa
from TestSim import TestSim

def main():
    # Initialize the simulation environment.
    sim = TestSim()

    # Start the simulation.
    sim.runTime(1)

    # Load the network topology and noise model.
    sim.loadTopo("pizza.topo")  # Load the network topology file.
    sim.loadNoise("meyer-heavy.txt")  # Add noise model to all motes.

    # Boot all sensors in the network.
    sim.bootAll()

    # Add channels for debugging and monitoring.
    sim.addChannel(sim.COMMAND_CHANNEL)
    sim.addChannel(sim.GENERAL_CHANNEL)
    sim.addChannel(sim.TRANSPORT_CHANNEL)

    # Allow the network to stabilize.
    sim.runTime(300)

    # Set up a server on a specific address and port.
    server_address = 7
    server_port = 80
    sim.testServer(address=7, port=80)

    # Give the server time to initialize.
    sim.runTime(60)

    # Client sends data to the server.
    client_address = 3
    src_port = 20
    transfer_amount = 12
    sim.testClient(clientAddress=3, dest=7, srcPort=20, destPort=80, transfer=12)

    # Simulate for some time to allow the data transfer to complete.
    sim.runTime(5)

    # Close the client connection.
    sim.closeClient(clientAddress=3, dest=7, srcPort=20, destPort=80, transfer=12)

    # Simulate for a little more time to wrap up.
    sim.runTime(5)

if __name__ == '__main__':
    main()
