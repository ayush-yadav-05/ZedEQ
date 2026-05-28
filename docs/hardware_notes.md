# Hardware Notes

Target board: ZedBoard, XC7Z020-CLG484-1.

The design uses the ADAU1761 audio codec pins connected to PL:

```text
AC_MCLK     AB2
AC_BCLK     AA6
AC_LRCLK    Y6
AC_SDATA_I  AA7
AC_SDATA_O  Y8
AC_ADR0     AB1
AC_ADR1     Y5
AC_SCL      AB4
AC_SDA      AB5
```

`AC_ADR0` and `AC_ADR1` are driven high, so the ADAU1761 7-bit I2C address is `0x3B`.

The VU meter drives LD0 to LD7 as an output audio bar graph.

The ZedBoard USB-UART connector is wired to the PS MIO UART. This RTL project exposes UART on PMOD JA instead:

```text
JA1 / Y11   UART_RX from USB-UART TX
JA2 / AA11  UART_TX to USB-UART RX
GND         common ground
```

Use a 3.3 V USB-UART adapter.

The current clock divider generates about 12.5 MHz MCLK from the 100 MHz board clock. For tighter audio-rate accuracy, replace the divider with a Vivado Clocking Wizard output of 12.288 MHz and adjust `audio_codec_if` clocking.
