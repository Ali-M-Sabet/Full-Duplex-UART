file mkdir build
create_project -in_memory -part xc7a35tcpg236-1
read_verilog [glob rtl/tx/*.v rtl/rx/*.v rtl/*.v]
read_verilog -sv [glob rtl/tx/*.sv rtl/rx/*.sv]
synth_design -top uart_top -mode out_of_context
report_utilization -file build/utilization.rpt
close_project
puts "PASS: UART synthesis"
