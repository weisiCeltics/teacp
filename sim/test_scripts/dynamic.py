#!/usr/bin/python2.7

###-----------------------------------------------------------------------------
### The simulation script for dynamic RSSI traces
###
### The dynamic RSSI trace is recorded in the following format:
###               <time>   <node_id1>  <node_id2>   <RSSI>
###                10000            3           2      -54
###                11345            5           1      -65
###                12978            3           2      -50
###
### This script updates the RSSI values between nodes based on the timestamps
### in the TOSSIM simulation.
###-----------------------------------------------------------------------------

import sys
import os
import random


###-----------------------------------------------------------------------------
### Simulation input
###
### protocol            the underlying collection protocol
### log_file            the file that stores the generated log messages
### noise_file          the file recording the noise traces
### link_file           the file recording the RSSI traces between nodes
### finish_time         the time when the simulation finishes
### link_gain_adjust    the manual adjustment to the link gains
###-----------------------------------------------------------------------------

default_arg = [ 
    "ctp",
    "log/temp/simulation.log",
    "noise-100dBm.txt",
    "dynamic/ctp_8pkts_p-10Trace.txt",
    500,
    0
    ]


if len(sys.argv) == 1:

    protocol         = default_arg[0]
    log_file         = open("../" + default_arg[1], 'w')
    noise_file       = open("../config/noise/" + default_arg[2], "r")
    link_file        = open("../config/linkgain/" + default_arg[3], "r")
    finish_time      = int(default_arg[4])
    link_gain_adjust = int(default_arg[5])

    sys.path.append("../nesc/" + protocol + '/')

else:

    protocol         = sys.argv[1]
    log_file         = open("../" + sys.argv[2], 'w')
    noise_file       = open("../config/noise/" + sys.argv[3], "r")
    link_file        = open("../config/linkgain/" + sys.argv[4], "r")
    finish_time      = int(sys.argv[5])
    link_gain_adjust = int(sys.argv[6])

    sys.path.append("../nesc/" + protocol + '/')


from TOSSIM import *

# Create a TOSSIM simulator object
simulator = Tossim([])

# Obtain the radio module from the simulator
radio_module = simulator.radio()

# Link the dbg("TeacpApp", "...") in NesC code to the log file
simulator.addChannel("TeacpApp", log_file)


###-----------------------------------------------------------------------------
### Obtain the list of node IDs from the link gain configuration file, link_file
###-----------------------------------------------------------------------------

node_list = [0]
link_file_lines = link_file.readlines()

for line in link_file_lines:

    s = line.split()

    node_id1 = int(s[1])
    node_id2 = int(s[2])

    if node_id1 not in node_list:
        node_list.append(node_id1)

    if node_id2 not in node_list:
        node_list.append(node_id2)


###-----------------------------------------------------------------------------
### Create the noise model for each model based on the noise traces
###-----------------------------------------------------------------------------

noise_file_lines = noise_file.readlines()

for line in noise_file_lines:

    s = line.strip()

    if(s != ""):
        val = int(s)

    for i in node_list:
        simulator.getNode(i).addNoiseTraceReading(val)

for i in node_list:
    simulator.getNode(i).createNoiseModel()


###-----------------------------------------------------------------------------
### Configure the booting time of each node
###-----------------------------------------------------------------------------

for i in node_list:
    simulator.getNode(i).bootAtTime(10000)


###-----------------------------------------------------------------------------
### Run the simulation
###-----------------------------------------------------------------------------

simulation_finished = False
time = 0
last_update_time = 0

### The simulation starts

while simulation_finished == False:

    # When we finish reading the dynamic RSSI trace but still the simulation
    # is not finished, we read again the trace from the beginning and continue
    # running the simulation.
    offset = last_update_time

    for line in link_file_lines:

        s = line.split()

        if len(s) == 4:

            next_update_time = int(s[0])
            node_id1         = int(s[1])
            node_id2         = int(s[2])
            rssi             = int(s[3])

            # Run the simulation until the next time stamp in the RSSI trace
            while time <= next_update_time + offset:
                simulator.runNextEvent()
                time = simulator.time() / simulator.ticksPerSecond() * 1000

            # Update the RSSI between this pair of nodes
            # Right now we use symmetric link gains.
            radio_module.add(node_id1, node_id2, rssi + link_gain_adjust)
            radio_module.add(node_id2, node_id1, rssi + link_gain_adjust)

            last_update_time = next_update_time + offset

            if last_update_time >= finish_time * 1000:
                simulation_finished = True
                break

### The simulation ends

link_file.close()
log_file.close()
noise_file.close()
