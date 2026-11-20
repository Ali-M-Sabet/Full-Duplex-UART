vlib work
vlog -sv -f rtl/files.f tb/tx/*.v tb/tx/*.sv tb/rx/*.sv tb/*.sv
vsim -voptargs=+acc work.tb_uart_top
add wave -r sim:/tb_uart_top/*
run -all
