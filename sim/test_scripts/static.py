#!/usr/bin/python2.7

###-----------------------------------------------------------------------------
### The simulation script for static RSSI traces
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

default_arg = {
    'protocol': 'ctp',
    'log_filename': 'log/temp/simulation.log',
    'noise_filename': 'noise-100dBm.txt',
    'link_filename': 'static/perfect-grid-25nodes.txt',
    'finish_time': 500,
    'link_gain_adjust': 0
    }


if len(sys.argv) == 1:

    protocol         = default_arg['protocol']
    log_file         = open('../' + default_arg['log_filename'], 'w')
    noise_file       = open('../config/noise/' + default_arg['noise_filename'], 'r')
    link_file        = open('../config/linkgain/' + default_arg['link_filename'], 'r')
    finish_time      = int(default_arg['finish_time'])
    link_gain_adjust = int(default_arg['link_gain_adjust'])

    sys.path.append('../nesc/' + protocol + '/')

else:

    protocol         = sys.argv[1]
    log_file         = open('../' + sys.argv[2], 'w')
    noise_file       = open('../config/noise/' + sys.argv[3], 'r')
    link_file        = open('../config/linkgain/' + sys.argv[4], 'r')
    finish_time      = int(sys.argv[5])
    link_gain_adjust = int(sys.argv[6])

    sys.path.append('../nesc/' + protocol + '/')


from TOSSIM import *

# Create a TOSSIM simulator object
simulator = Tossim([])

# Obtain the radio module from the simulator
radio_module = simulator.radio()

# Link the dbg('TeacpApp', '...') in NesC code to the log file
simulator.addChannel('TeacpApp', log_file)


###-----------------------------------------------------------------------------
### Obtain the list of node IDs from the link gain configuration file, link_file
###-----------------------------------------------------------------------------

node_list = [0]
link_file_lines = link_file.readlines()

for line in link_file_lines:

    s = line.split()

    if len(s) == 4 and s[0] == 'gain':

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

    if(s != ''):
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
### Configure the static link gains between the pairs of nodes
###-----------------------------------------------------------------------------

for line in link_file_lines:

    s = line.split()
    
    if len(s) == 4 and s[0] == 'gain':

        node_id1 = int(s[1])
        node_id2 = int(s[2])
        rssi     = float(s[3])

        radio_module.add(node_id1, node_id2, rssi + link_gain_adjust)


###-----------------------------------------------------------------------------
### Run the simulation
###-----------------------------------------------------------------------------

time = 0

### The simulation starts

while time <= finish_time * 1000:
    simulator.runNextEvent() 
    time = float(simulator.time()) / float(simulator.ticksPerSecond()) * 1000

### The simulation ends
    
link_file.close()
log_file.close()
noise_file.close()
