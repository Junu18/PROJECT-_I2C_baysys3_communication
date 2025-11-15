# Quick Start Guide

## 🎯 I2C Multi-Slave System for Basys3 FPGA

This guide will help you get started with the I2C multi-slave communication system.

---

## 📁 Project Structure

```
i2c_top/
├── rtl/                  # RTL source files
│   ├── master/           # I2C Master
│   ├── slaves/           # 3 I2C Slaves (LED, FND, Switch)
│   └── integration/      # Top-level modules
│
├── tb/                   # Testbenches
├── sim/                  # Simulation scripts
├── constraints/          # Basys3 XDC files
├── firmware/             # MicroBlaze C code examples
└── docs/                 # Documentation
```

---

## 🚀 Getting Started

### Option 1: Simulation (Development & Testing)

**1. Run individual slave tests:**
```bash
cd i2c_top/sim

# Test LED Slave
./run_led_slave.sh

# Test FND Slave
./run_fnd_slave.sh

# Test Switch Slave
./run_switch_slave.sh
```

**2. Run full system test:**
```bash
./run_system.sh
```

**3. Run all tests at once:**
```bash
./run_all_tests.sh
```

**4. View waveforms:**
```bash
gtkwave i2c_system_tb.vcd
```

---

### Option 2: Single-Board Demo (Basys3)

**Best for:** Learning, debugging, and demonstration

**Hardware Setup:**
- 1x Basys3 FPGA board
- USB cable

**Vivado Steps:**

1. Create new Vivado project
2. Add RTL sources:
   ```
   rtl/master/i2c_master.sv
   rtl/slaves/i2c_led_slave.sv
   rtl/slaves/i2c_fnd_slave.sv
   rtl/slaves/i2c_switch_slave.sv
   rtl/integration/i2c_system_top.sv
   ```

3. Add constraint file:
   ```
   constraints/basys3_integrated.xdc
   ```

4. Set `i2c_system_top` as top module

5. Run Synthesis → Implementation → Generate Bitstream

6. Program FPGA

**Testing:**
- Use SW[15:8] to set slave address (0x55, 0x56, 0x57)
- Use SW[7:0] for data
- Press BTNU to start I2C transaction
- Observe LED/FND outputs

---

### Option 3: Board-to-Board Communication

**Best for:** Realistic I2C system demonstration

**Hardware Setup:**
- 2x Basys3 FPGA boards
- PMOD cable (or jumper wires)
- 2x 4.7kΩ pull-up resistors (for SCL, SDA)

**Board #1: Master (with MicroBlaze)**

1. Create Vivado Block Design
2. Add MicroBlaze processor
3. Package `i2c_master.sv` as AXI IP:
   - Use Vivado IP Packager
   - Use S00_AXI template
   - Connect i2c_master as user logic
4. Connect I2C pins to PMOD JA
5. Generate bitstream
6. Export hardware and launch Vitis
7. Create application project
8. Add firmware files from `firmware/`
9. Program FPGA and run firmware

**Board #2: Slaves**

1. Create new Vivado project
2. Add RTL sources:
   ```
   rtl/slaves/i2c_led_slave.sv
   rtl/slaves/i2c_fnd_slave.sv
   rtl/slaves/i2c_switch_slave.sv
   rtl/integration/board_slaves_top.sv
   ```

3. Add constraint file:
   ```
   constraints/basys3_slaves.xdc
   ```

4. Set `board_slaves_top` as top module
5. Generate bitstream and program

**Connections:**
```
Board #1 (Master)        Board #2 (Slaves)
JA1 (SCL) ──────────────→ JA1 (SCL)
JA2 (SDA) ←────────────→ JA2 (SDA)
GND       ──────────────→ GND

Pull-up resistors (4.7kΩ):
  SCL → 3.3V
  SDA → 3.3V
```

---

## 📊 I2C Protocol

### LED Slave (0x55) - Write Only
```
[START][0xAA][DATA][STOP]
```
Example: Turn all LEDs ON
```c
i2c_write(0x55, 0xFF);
```

### FND Slave (0x56) - Write Only
```
[START][0xAC][DIGIT][STOP]
```
Example: Display '5'
```c
i2c_write(0x56, 0x05);
```

### Switch Slave (0x57) - Read Only
```
[START][0xAE][STOP]       // Address
[START][0xAF][DATA][NACK][STOP]  // Read
```
Example: Read switch value
```c
uint8_t sw = i2c_read(0x57);
```

---

## 💻 Firmware Usage

### Basic API

```c
// Initialize I2C driver
i2c_init(0x44A00000);  // Use your AXI IP base address

// Write to LED
i2c_write_led(0xFF);

// Write to FND
i2c_write_fnd(0x05);  // Display '5'

// Read from Switch
uint8_t sw_value;
i2c_read_switch(&sw_value);
```

### Running Demos

The `main.c` includes several demo functions:
- `test_all_slaves()` - Quick connectivity test
- `demo_all_features()` - Combined demo
- `demo_interactive()` - Switch controls LED/FND
- Individual demos for LED, FND, and Switch

---

## 🐛 Troubleshooting

### Simulation Issues

**Problem:** Compilation errors
```bash
# Ensure you're using Icarus Verilog with SystemVerilog support
iverilog -g2012 -o testbench file.sv
```

**Problem:** No ACK from slaves
- Check slave addresses in testbench
- Verify timing parameters

### Hardware Issues

**Problem:** No communication between boards
- Check GND connection
- Verify pull-up resistors (4.7kΩ)
- Check PMOD pinout (JA1=SCL, JA2=SDA)
- Measure SCL/SDA with oscilloscope

**Problem:** ACK errors in firmware
- Verify slave board is powered and programmed
- Check I2C base address in firmware
- Test with individual slaves first

**Problem:** LED/FND not responding
- Verify correct slave is addressed
- Check constraint file pin assignments
- Test in simulation first

---

## 📖 Next Steps

1. ✅ **Run simulations** to verify functionality
2. ✅ **Single-board demo** for initial testing
3. ✅ **Create Vivado AXI IP** from i2c_master.sv
4. ✅ **Board-to-board setup** for realistic demo
5. 🔄 **UVM verification** (advanced, optional)

---

## 📚 Documentation

- `README.md` - Project overview and design philosophy
- `PROTOCOL.md` - Detailed I2C protocol specification
- `FIRMWARE_GUIDE.md` - Firmware development guide
- `VIVADO_IP.md` - IP packaging tutorial

---

## 🎓 Educational Value

This project demonstrates:
- ✅ I2C multi-device bus architecture
- ✅ Master-slave communication
- ✅ 7-bit addressing
- ✅ Single-byte protocol simplicity
- ✅ Hardware-software co-design
- ✅ FPGA design flow (RTL → Synthesis → Implementation)
- ✅ Embedded firmware development

Perfect for:
- Digital design courses
- Embedded systems labs
- FPGA workshops
- Communication protocol learning

---

## 🤝 Support

For questions or issues:
1. Check simulation first
2. Review timing diagrams in PROTOCOL.md
3. Test with single-board demo before board-to-board
4. Verify all connections and pull-ups

---

**Happy Building! 🚀**
