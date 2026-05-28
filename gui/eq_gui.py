import math
import queue
import struct
import threading
import time
import tkinter as tk
from tkinter import ttk, messagebox

try:
    import serial
    from serial.tools import list_ports
except ImportError:
    serial = None
    list_ports = None


FS = 48828.125
FREQS = [100.0, 300.0, 1000.0, 3000.0, 8000.0]
Q = 1.0
Q28 = 1 << 28


def q28(x):
    v = int(round(x * Q28))
    if v < -2147483648:
        v = -2147483648
    if v > 2147483647:
        v = 2147483647
    return v & 0xFFFFFFFF


def packet(cmd, index, value):
    data = [0xA5, cmd & 0xFF, index & 0xFF]
    data += list(struct.pack(">I", value & 0xFFFFFFFF))
    chk = 0
    for b in data:
        chk ^= b
    data.append(chk)
    return bytes(data)


def peaking_eq(freq, gain_db):
    a = 10 ** (gain_db / 40.0)
    w0 = 2.0 * math.pi * freq / FS
    alpha = math.sin(w0) / (2.0 * Q)
    c = math.cos(w0)

    b0 = 1.0 + alpha * a
    b1 = -2.0 * c
    b2 = 1.0 - alpha * a
    a0 = 1.0 + alpha / a
    a1 = -2.0 * c
    a2 = 1.0 - alpha / a

    return [b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0]


class EqualizerGui:
    def __init__(self, root):
        self.root = root
        self.root.title("ZedBoard 5 Band EQ")
        self.ser = None
        self.reader_stop = threading.Event()
        self.rxq = queue.Queue()
        self.sliders = []
        self.vu = tk.IntVar(value=0)
        self.status = tk.StringVar(value="Disconnected")
        self.bypass = tk.BooleanVar(value=False)
        self.mute = tk.BooleanVar(value=False)
        self.volume = tk.DoubleVar(value=0.8)

        self.build()
        self.refresh_ports()
        self.root.after(50, self.poll_rx)

    def build(self):
        top = ttk.Frame(self.root, padding=12)
        top.grid(row=0, column=0, sticky="nsew")
        self.root.columnconfigure(0, weight=1)
        self.root.rowconfigure(0, weight=1)

        bar = ttk.Frame(top)
        bar.grid(row=0, column=0, sticky="ew")
        top.columnconfigure(0, weight=1)

        self.port_box = ttk.Combobox(bar, width=18, state="readonly")
        self.port_box.grid(row=0, column=0, padx=(0, 6))
        ttk.Button(bar, text="Refresh", command=self.refresh_ports).grid(row=0, column=1, padx=3)
        ttk.Button(bar, text="Connect", command=self.connect).grid(row=0, column=2, padx=3)
        ttk.Button(bar, text="Disconnect", command=self.disconnect).grid(row=0, column=3, padx=3)
        ttk.Label(bar, textvariable=self.status).grid(row=0, column=4, padx=12)

        bands = ttk.Frame(top)
        bands.grid(row=1, column=0, pady=16)

        names = ["100 Hz", "300 Hz", "1 kHz", "3 kHz", "8 kHz"]
        for i, name in enumerate(names):
            frame = ttk.Frame(bands)
            frame.grid(row=0, column=i, padx=10)
            ttk.Label(frame, text=name).grid(row=0, column=0)
            var = tk.DoubleVar(value=0.0)
            scale = ttk.Scale(frame, from_=12.0, to=-12.0, length=220, variable=var,
                              command=lambda _v, idx=i: self.band_changed(idx))
            scale.grid(row=1, column=0)
            label = ttk.Label(frame, text="0.0 dB")
            label.grid(row=2, column=0)
            self.sliders.append((var, label))

        ctl = ttk.Frame(top)
        ctl.grid(row=2, column=0, sticky="ew")

        ttk.Label(ctl, text="Volume").grid(row=0, column=0, sticky="w")
        ttk.Scale(ctl, from_=0.0, to=1.5, variable=self.volume,
                  command=lambda _v: self.volume_changed()).grid(row=0, column=1, sticky="ew", padx=8)
        ctl.columnconfigure(1, weight=1)

        ttk.Checkbutton(ctl, text="Bypass", variable=self.bypass, command=self.flags_changed).grid(row=1, column=0, pady=8)
        ttk.Checkbutton(ctl, text="Mute", variable=self.mute, command=self.flags_changed).grid(row=1, column=1, sticky="w")
        ttk.Button(ctl, text="Reset Flat", command=self.reset_flat).grid(row=1, column=2, padx=8)

        meter = ttk.Frame(top)
        meter.grid(row=3, column=0, sticky="ew", pady=(10, 0))
        ttk.Label(meter, text="VU").grid(row=0, column=0, padx=(0, 8))
        ttk.Progressbar(meter, maximum=255, variable=self.vu).grid(row=0, column=1, sticky="ew")
        meter.columnconfigure(1, weight=1)

    def refresh_ports(self):
        if list_ports is None:
            self.port_box["values"] = []
            return
        ports = [p.device for p in list_ports.comports()]
        self.port_box["values"] = ports
        if ports:
            self.port_box.current(0)

    def connect(self):
        if serial is None:
            messagebox.showerror("Missing pyserial", "Install with: pip install pyserial")
            return
        if self.ser:
            return
        port = self.port_box.get()
        if not port:
            return
        try:
            self.ser = serial.Serial(port, 115200, timeout=0.05)
            self.reader_stop.clear()
            threading.Thread(target=self.reader, daemon=True).start()
            self.status.set("Connected")
            self.send_all()
        except serial.SerialException as e:
            messagebox.showerror("Serial error", str(e))

    def disconnect(self):
        self.reader_stop.set()
        if self.ser:
            self.ser.close()
            self.ser = None
        self.status.set("Disconnected")

    def reader(self):
        buf = bytearray()
        while not self.reader_stop.is_set() and self.ser:
            b = self.ser.read(1)
            if not b:
                continue
            buf += b
            while len(buf) >= 4:
                if buf[0] != 0x5A:
                    del buf[0]
                    continue
                pkt = bytes(buf[:4])
                del buf[:4]
                if (pkt[0] ^ pkt[1] ^ pkt[2]) == pkt[3]:
                    self.rxq.put(pkt)

    def poll_rx(self):
        try:
            while True:
                pkt = self.rxq.get_nowait()
                self.vu.set(pkt[1])
                flags = pkt[2]
                self.status.set("Connected" if flags & 0x04 else "Codec wait")
        except queue.Empty:
            pass
        self.root.after(50, self.poll_rx)

    def write(self, data):
        if self.ser:
            self.ser.write(data)

    def band_changed(self, idx):
        var, label = self.sliders[idx]
        gain = var.get()
        label.configure(text=f"{gain:.1f} dB")
        coeffs = peaking_eq(FREQS[idx], gain)
        for cidx, coef in enumerate(coeffs):
            self.write(packet(0x01, idx * 5 + cidx, q28(coef)))

    def volume_changed(self):
        self.write(packet(0x02, 0, q28(self.volume.get())))

    def flags_changed(self):
        value = (1 if self.bypass.get() else 0) | (2 if self.mute.get() else 0)
        self.write(packet(0x03, 0, value))

    def reset_flat(self):
        for var, label in self.sliders:
            var.set(0.0)
            label.configure(text="0.0 dB")
        self.bypass.set(False)
        self.mute.set(False)
        self.volume.set(0.8)
        self.write(packet(0x04, 0, 0))
        time.sleep(0.02)
        self.send_all()

    def send_all(self):
        for i in range(5):
            self.band_changed(i)
        self.volume_changed()
        self.flags_changed()


if __name__ == "__main__":
    root = tk.Tk()
    app = EqualizerGui(root)
    root.protocol("WM_DELETE_WINDOW", lambda: (app.disconnect(), root.destroy()))
    root.mainloop()

