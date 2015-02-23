#!/usr/bin/python

###-----------------------------------------------------------------------------
### The script for running TOSSIM simulations and recording TeaCP analysis
### results
###-----------------------------------------------------------------------------

import os
from subprocess import call
import fileinput
import sys
sys.path.append(os.getcwd() + '/tools')
from TeacpAnalysis import *
from numpy import array
import matplotlib.pyplot as plt
import time
import math


###-----------------------------------------------------------------------------
### Simulation configuration
###
### protocol:          the collection protocol being tested in the simulation
###                    Options - ctp, bcp
### queue_type:        the local queueing policy (*only applies to BCP*)
###                    Options - LIFO, FIFO
### noise_filename:    the noise traces under teacp/sim/config/noise/
### link_filename:     the RSSI traces under teacp/sim/config/linkgain/
### log_dir:           the directory of the log file
### log_filename:      the log file under log_dir/
### result_filename:   the file containing results under log_dir/output/
### test_script:       the Python script for running a one-time simulation
###                    Options
###                    static.py  - running simulation on static RSSI traces
###                    dynamic.py - running simulation on time-varying traces
### num_packets:       the maximum number of packets a sensor node generates
###                    in the simulation
### pkt_id_range:      the packet ID range for analyzing the statistics
###                    e.g., [100, 400]
### simulation_times:  the number of times for running the simulation with 
###                    the same parameters. This is for obtaining confidence
###                    interval on the results.
### packet_timer_type: the type of packet timer in the NesC packet application.
###                    Options
###                    exponential - the packet interval will be an exponential
###                                  random variable with the average set to
###                                  the given 
###                    periodic    - the packet interval will stay the same
###                                  along the whole simulation.
###-----------------------------------------------------------------------------

protocol           = 'ctp' 
queue_type         = 'LIFO' 
noise_filename     = 'meyer-heavy.txt'
link_filename      = 'dynamic/intra_car_5nodes.txt'
log_dir            = 'log/temp/'
log_filename       = 'simulation.log'
result_filename    = 'result.txt'
test_script        = 'dynamic.py'
num_packets        = 3000 
pkt_id_range       = [100, num_packets-100]
simulation_times   = 5
pkt_timer_type     = 'periodic'
link_gain_shift    = 0
rng_seed           = 0
#pkt_rate_list      = [1, 2]
pkt_rate_list      = [1, 2, 3, 4, 5, 6, 7, 8, 10, 20, 50, 100]


###-----------------------------------------------------------------------------
### Configuring the packet generation interval and other parameters for a
### simulation by modifying test_config.h
###-----------------------------------------------------------------------------

def configure_simulation():

    for line in fileinput.input('test_config.h', inplace=1):

        if ('  PACKET_INTERVAL = ' in line):
            line = '  PACKET_INTERVAL = ' + str(pkt_interval) + ','

        elif ('#define LIFO' in line or '#define FIFO' in line):
            line = '#define ' + queue_type

        elif ('#define EXPONENTIAL_TIMER' in line or '#define PERIODIC_TIMER' in line):
            if (pkt_timer_type == 'exponential'):
                line = '#define EXPONENTIAL_TIMER'
            else:
                line = '#define PERIODIC_TIMER' 

        elif ('  RNG_SEED         = ' in line):
            line = '  RNG_SEED         = ' + str(rng_seed) + ','
            
        else:
            line = line.rstrip()

        print line


###-----------------------------------------------------------------------------
### Main body of simulation
###-----------------------------------------------------------------------------

if protocol == 'ctp':
    queue_type = 'N/A'


output_dir = log_dir + 'output'
if (not os.path.exists(output_dir)): 
    os.makedirs(output_dir)

result_file = open(output_dir+'/'+result_filename, 'a')
result_file.writelines('\n')
result_file.writelines('-' * 20)
result_file.writelines(time.asctime( time.localtime(time.time()) ))
result_file.writelines('-' * 20 + '\n')
result_file.writelines(('protocol: {:s}\n' +
                        'queue_type: {:s}\n' + 
                        'noise_trace: {:s}\n' + 
                        'rssi_trace: {:s}\n' + 
                        'simulation_times: {:d}\n').format(
                        protocol, queue_type,
                        noise_filename, link_filename, simulation_times
                        ))
result_file.writelines(('{:>10}{:>12}{:>9}{:>11}' +
                        '{:>9}{:>10}{:>9}\n').format(
                        'PktRate',
                        '%Delivery', 'Std',
                        'AvgDelay', 'Std',
                        'Goodput', 'Std'
                        ))
result_file.close()

pkt_rate = 0
pkt_interval = 0

start_time = time.time()

### Iterate over the list of packet generation rates
### You can change the independent variable to any type you want
### e.g., radio power.
for i in range(len(pkt_rate_list)):
    
    pkt_rate = pkt_rate_list[i]
    pkt_interval = int(math.ceil(1024 / pkt_rate))

    delivery_rate = []
    avg_delay     = []
    goodput       = []

    ### Run the simulation for a number of times
    for j in range(simulation_times):

        rng_seed += j * 101

        ### Configure the packet generation rate and the RNG seed in the header file
        os.chdir('nesc/')
        configure_simulation()

        ### Change to the directory of nesc code and compile
        os.chdir(protocol + '/')
        os.system('make micaz sim > make_log 2>&1')

        print 'Running simulation: protocol ' + protocol + ', queue ' + queue_type + \
              ', pkt_interval ' + str(pkt_interval) + ', #case ' + str(j+1)
        
        ### Change to the directory of the test scripts and run the simulation
        os.chdir('../../test_scripts')
        os.system('python ' + 
                  test_script + ' ' +
                  protocol + ' ' +
                  log_dir+log_filename + ' ' +  
                  noise_filename + ' ' +
                  link_filename + ' ' +
                  str(pkt_interval * num_packets / 1000) + ' ' +
                  str(link_gain_shift)
                  )

        ### Change back to the directory sim/
        os.chdir('..')
        analysis_tool = TeacpAnalysis(log_dir, 'sim')
        analysis_tool.set_pkt_range(pkt_id_range)
        analysis_tool.calc_all()

        delivery_rate.append(analysis_tool.network_statistics['delivery_rate'])
        avg_delay    .append(analysis_tool.network_statistics['avg_delay'])
        goodput      .append(analysis_tool.network_statistics['goodput'])


    result_file = open(output_dir+'/'+result_filename, 'a')
    
    result_file.writelines(('{:10.2f}{:12.4f}{:9.4f}{:11.2f}' 
                            '{:9.2f}{:10.2f}{:9.2f}' +  
                            '\n').format( 
                            pkt_rate, 
                            array(delivery_rate).mean(), array(delivery_rate).std(),
                            array(avg_delay).mean(), array(avg_delay).std(),
                            array(goodput).mean(), array(goodput).std(),
                            ))
    
    if (i == len(pkt_rate_list) - 1):
        result_file.writelines('\n\n')

    result_file.close()

finish_time = time.time()
print 'The whole simulation runs for %.2f secs.' % (finish_time - start_time)

print 'The results have been written into the file:' 
print '       ' + os.path.abspath(output_dir+'/'+result_filename)
