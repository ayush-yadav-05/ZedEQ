# UART Protocol

Baud rate: 115200, 8 data bits, no parity, 1 stop bit.

PC to FPGA packet:

```text
A5 CMD INDEX DATA3 DATA2 DATA1 DATA0 CHECK
```

`CHECK` is XOR of the first seven bytes.

Commands:

```text
01  set coefficient
02  set master volume
03  set flags
04  reset flat
```

Coefficient indexes:

```text
band 0: 0..4
band 1: 5..9
band 2: 10..14
band 3: 15..19
band 4: 20..24
```

Coefficient order in each band:

```text
b0, b1, b2, a1, a2
```

Coefficients and volume use signed Q4.28 format. The filter implements:

```text
y[n] = b0*x[n] + b1*x[n-1] + b2*x[n-2] - a1*y[n-1] - a2*y[n-2]
```

Flag bits:

```text
bit 0: bypass
bit 1: mute
bit 2: clear filters
```

FPGA to PC status packet:

```text
5A VU FLAGS CHECK
```

`FLAGS[0]` is bypass, `FLAGS[1]` is mute, and `FLAGS[2]` is codec ready.

