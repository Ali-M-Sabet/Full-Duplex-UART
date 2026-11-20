# UART

An 8-bit full-duplex UART in Verilog and SystemVerilog, with separate
transmit and receive clocks.

- LSB-first data, one start bit, and one stop bit
- Optional even or odd parity, configured separately for TX and RX
- RX oversampling at 8, 16, or 32 clocks per bit
- Three-sample majority voting and serial-input synchronization
- Parity and framing error detection
- Asynchronous active-low reset

## Structure

```text
rtl/
  uart_top.v       Combined UART
  tx/              Transmitter modules
  rx/              Receiver modules
  files.f          RTL source list
tb/
  tb_uart_top.sv   Full-duplex test
  tx/              Transmitter tests
  rx/              Receiver and block tests
sim/
  run.do           ModelSim/Questa simulation
  synth.tcl        Vivado synthesis check
```

## Interface

| Port | Direction | Description |
| --- | --- | --- |
| `tx_clk` | Input | Transmit clock, one cycle per serial bit |
| `rx_clk` | Input | Receive sampling clock |
| `rst_n` | Input | Asynchronous active-low reset |
| `prescale[5:0]` | Input | RX clocks per bit: 8, 16, or 32 |
| `tx_data[7:0]` | Input | Byte to transmit |
| `tx_valid` | Input | One-TX-clock request pulse |
| `tx_par_en`, `tx_par_typ` | Input | Transmit parity enable and type |
| `rx_par_en`, `rx_par_typ` | Input | Receive parity enable and type |
| `rx_in` | Input | Serial receive line |
| `tx_out` | Output | Registered serial transmit line |
| `tx_busy` | Output | Transmitter is occupied |
| `rx_data[7:0]` | Output | Received byte |
| `rx_valid` | Output | One-RX-clock pulse for a valid byte |
| `rx_par_error` | Output | Receive parity error |
| `rx_stp_error` | Output | Receive framing error |

Parity type `0` selects even parity; `1` selects odd parity. Serial lines
idle high.

## Clocking and operation

Supply both clocks externally:

```text
tx_clk frequency = transmit baud rate
rx_clk frequency = receive baud rate * prescale
```

For 115200 baud and a prescale of 8, use a 115200 Hz TX clock and a
921600 Hz RX clock. There is no internal baud-rate divider.

TX accepts data on a rising `tx_clk` edge when `tx_valid && !tx_busy`.
It captures data and parity settings, asserts busy immediately, and starts
the serial frame on the following TX clock edge. Busy stays high through
the full stop bit. Requests while busy are ignored. Holding `tx_valid` high
requests another frame when TX becomes free.

RX captures prescale and parity settings when it detects a start bit after
input synchronization. Set them before reception begins. Read `rx_data`
only when `rx_valid` is high; the data register shifts during reception.
Bad frames do not assert valid. Error flags clear on a new detected start
and update when the corresponding frame bits are checked. There is no FIFO
or receive backpressure.

TX parallel signals belong to `tx_clk`; RX configuration and parallel
signals belong to `rx_clk`. Reset release must meet recovery and removal
requirements in both domains.

The combined module uses eight data bits. The standalone transmitter has a
positive `DATA_WIDTH` parameter, defaulting to eight.

## Simulation

Run from the repository root with ModelSim or Questa on `PATH`:

```text
vsim -c -do sim/run.do
```

The script compiles the project, loads `tb_uart_top` at the default prescale
of 8, adds waves, and runs the simulation. The testbench checks the results
and reports failures.
Each testbench prints one success line. The tests cover all byte values,
parity modes, bit timing, busy handling, reset during activity, majority
voting, corrupted frames, recovery, configuration capture, and consecutive
frames. The full-duplex test sends 768 bytes each way at each supported
prescale, using separate clock phases.

To run a different test after compilation, load its module with `vsim` and
use `run -all`. Available testbenches are `tb_uart_par_calc`, `tb_uart_tx`,
`tb_rx_blocks`, `tb_uart_rx`, and `tb_uart_top`. For a different RX prescale:

```text
vsim -voptargs=+acc work.tb_uart_top -gPRESCALE=16
run -all
```

Verification covered 10 configurations in ModelSim Intel FPGA Starter 10.5b
with no compiler warnings. The tests require no external source files.

## Synthesis

With Vivado on `PATH`, run:

```text
vivado -mode batch -source sim/synth.tcl
```

The script uses `xc7a35tcpg236-1` as a reference target and writes
`build/utilization.rpt`. Vivado 2018.2 synthesis passed
with zero warnings and no inferred latches: 81 LUTs and 58 flip-flops.

Board pin assignments, timing constraints, implementation, and hardware
testing must be supplied for the target board. Generated build files and
simulation outputs are excluded by `.gitignore`.
