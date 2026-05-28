# ZedEQ — FPGA Based Audio Equalizer with GUI Control

**ZedEQ** is a real-time 5-band parametric audio equalizer built entirely in FPGA programmable logic on the ZedBoard (Xilinx Zynq-7000 XC7Z020). Audio from the onboard ADAU1761 codec passes through five cascaded pipelined biquad IIR filters running in the PL fabric. The PC plays no role in the audio path whatsoever; it only pushes new filter coefficients over UART when you move a slider.

A Python GUI handles the control side: EQ band gain, master volume, bypass, mute, and reset-to-flat. The ZedBoard's onboard LEDs show a live VU meter driven directly from the post-processed audio signal inside the FPGA.

![GUI Preview](docs/gui_preview.png)

---

## Overview

| | |
|---|---|
| **Board** | ZedBoard (Xilinx Zynq-7000 XC7Z020) |
| **HDL** | Verilog-2001 |
| **Toolchain** | Vivado (PL-only, no SDK/Vitis) |
| **Audio Codec** | ADAU1761 (onboard), configured over I2C |
| **EQ Bands** | 100 Hz, 300 Hz, 1 kHz, 3 kHz, 8 kHz |
| **Filter Type** | Cascaded second-order IIR biquad |
| **Coefficient Format** | Q4.28 signed fixed-point |
| **PC Interface** | UART via PMOD JA (3.3V USB-UART adapter) |
| **GUI** | Python + Tkinter + pyserial |
| **VU Meter** | LD0–LD7 onboard LEDs |

---

## Key Features

- All audio processing happens in FPGA fabric — the CPU is not involved at any point in the signal chain
- Five independent peaking-EQ bands implemented as pipelined biquad IIR filters
- Python GUI computes biquad coefficients locally and streams them to the FPGA over a lightweight UART packet protocol
- ADAU1761 codec configured at startup via a hardware I2C master — no software driver needed
- Master volume control with signed saturation protection to prevent wrap-around distortion
- Live VU meter on LD0–LD7, driven from the actual output signal inside the FPGA
- Mute, bypass (routes audio around the EQ entirely), and reset-to-flat controls
- Modular RTL structure — codec, DSP, and control logic are fully separated

---

## How It Works

Audio comes in through the ADAU1761 via an I2S-style serial interface, runs through five cascaded biquad stages, then goes through volume scaling and saturation before being sent back out through the codec. The LEDs continuously show the magnitude of the signal at that final output stage.

The Python GUI computes biquad coefficients from the peaking-EQ formula based on slider positions and packs them as Q4.28 fixed-point values into UART packets. The FPGA receives these, stores them in a register bank, and immediately uses them for the next audio samples. Round-trip latency on coefficient updates is negligible.

```
Python GUI  →  UART packets  →  FPGA UART RX  →  Control Register Bank
                                                          |
                                                          ↓
Audio In → ADAU1761 → I2S RX → 5-Band Biquad EQ → Volume / Sat → I2S TX → ADAU1761 → Audio Out
                                                                      |
                                                                      ↓
                                                                LED VU Meter
```

---

## EQ Bands

| Band | Center Frequency |
|------|-----------------|
| 1    | 100 Hz          |
| 2    | 300 Hz          |
| 3    | 1 kHz           |
| 4    | 3 kHz           |
| 5    | 8 kHz           |

Each band is an independent peaking EQ with adjustable gain. The difference equation per band:

```
y[n] = b0·x[n] + b1·x[n-1] + b2·x[n-2] - a1·y[n-1] - a2·y[n-2]
```

The biquad datapath is pipelined — running it combinationally will fail timing after place and route.

---

## Hardware

- ZedBoard (Xilinx Zynq-7000 XC7Z020)
- Onboard ADAU1761 audio codec
- 3.3V USB-UART adapter for GUI communication
- Audio source and headphones or speakers

### UART Wiring — Read This

The ZedBoard's onboard USB-UART connects to the PS MIO, not the PL. Since this is a pure PL design, GUI UART is routed through **PMOD JA** instead.

```
USB-UART TX  →  JA1  (FPGA UART_RX)
USB-UART RX  →  JA2  (FPGA UART_TX)
GND          →  GND
```

Use a 3.3V adapter. Don't use 5V logic on the PMOD pins.

---

## Build

Open Vivado and source the project creation script:

```tcl
cd "C:/path/to/your/project"
source vivado_create_project.tcl
```

Then run synthesis → implementation → generate bitstream → program. Top module is `top_zedboard_eq`.

---

## Running the GUI

```bash
pip install pyserial
python gui/eq_gui.py
```

Select your COM port and hit Connect. The sliders push coefficient updates to the FPGA live. The VU meter at the bottom reads directly from FPGA status packets — it reflects the actual output signal, not anything computed on the PC.

---

## UART Protocol

**PC → FPGA** (8 bytes):
```
A5  CMD  INDEX  DATA3  DATA2  DATA1  DATA0  CHECK
```
`CHECK` = XOR of bytes 0–6.

| CMD  | Action                    |
|------|---------------------------|
| `01` | Set EQ coefficient        |
| `02` | Set master volume         |
| `03` | Set flags (mute / bypass) |
| `04` | Reset to flat EQ          |

**FPGA → PC** status packet (4 bytes):
```
5A  VU  FLAGS  CHECK
```

Full details in [`docs/uart_protocol.md`](docs/uart_protocol.md).

---

## Current Status

RTL is complete and bitstream generates cleanly. GUI is working. If you get silence on first hardware bring-up, the most likely issue is the ADAU1761 analog routing — check the register configuration table in `rtl/codec/adau1761_config.v` first.

---

## Future Improvements

- **EQ presets** — save and load named presets (flat, bass boost, vocal, etc.) directly from the GUI
- **Frequency response plot** — live Bode plot in the GUI showing the combined EQ curve as you adjust sliders
- **Hardware controls** — map ZedBoard switches and buttons as fallback controls for band gain and volume, so the board works standalone without a PC
- **Exact audio master clock** — use the Clocking Wizard to generate a proper 12.288 MHz MCLK instead of the current approximation
- **Graphic EQ mode** — switch from 5 fixed peaking bands to a wider graphic EQ with more bands and fixed-bandwidth filters
- **More filter types** — add low-shelf and high-shelf options for Band 1 and Band 5
- **Codec self-test** — loopback mode that routes the TX signal back into the RX path for verifying the codec and I2S interface without an external audio source
- **FPGA resource usage report** — document LUT / DSP / BRAM utilization post-implementation in the README
