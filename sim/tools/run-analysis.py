from TeacpAnalysis import *

analysis = TeacpAnalysis('../log/temp/', 'sim')
analysis.calc_all()
analysis.print_result()
analysis.print_result_to_file()
analysis.draw_delay_histogram()
analysis.create_topology_animation()
analysis.create_full_topology()
