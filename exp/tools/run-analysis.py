from TeacpAnalysis import *

### Import the log files under the specified directory
### The second parameter is to specify the message format for parsing, if the
### log files are from experiments, use 'exp'. If the log files are from
### simulations, use 'sim'.
analysis = TeacpAnalysis("../log/example/", 'exp')

### Specify the packet ID range for the analysis
#analysis.set_pkt_range([0, 1800])

### A shortcut for calculating all the statistics
analysis.calc_all()

### Print analysis results on the screen
analysis.print_result()

### Save the analysis results into a file
analysis.print_result_to_file()

### Draw the delay histogram for each source node
analysis.draw_delay_histogram()

### Generate the animation showing network topology evolution
analysis.create_topology_animation()

### Generate a full network topology depicting packet routes from each
### source node
analysis.create_full_topology()
