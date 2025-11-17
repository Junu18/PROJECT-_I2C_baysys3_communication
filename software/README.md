# I2C Master MicroBlaze Application

## Overview

C application for MicroBlaze to control I2C Master IP and communicate with 3 I2C slaves.

## File Structure

```
software/
├── i2c_master.h    - I2C driver header with register definitions
├── i2c_master.c    - I2C driver implementation
├── main.c          - Demo application
└── README.md       - This file
```

## I2C Slaves

| Slave | Address | Function | Write | Read |
|-------|---------|----------|-------|------|
| LED   | 0x55    | Control 8 LEDs | LED pattern (8-bit) | N/A |
| FND   | 0x56    | 7-segment display | Hex digit (4-bit) | N/A |
| Switch| 0x57    | Read switches | N/A | Switch state (8-bit) |

## Register Map (I2C Master IP)

### Control Register (Offset 0x00) - Write
```
[15:8]  tx_data     - Data to transmit
[7:1]   slave_addr  - 7-bit slave address
[0]     rw_bit      - 0=Write, 1=Read
```
**Note:** Writing to this register triggers an I2C transaction

### Status Register (Offset 0x04) - Read Only
```
[2]     ack_error   - 1 if NACK received
[1]     done        - 1 when transaction complete
[0]     busy        - 1 during transaction
```

### RX Data Register (Offset 0x08) - Read Only
```
[7:0]   rx_data     - Data received from slave
```

## Setup in Vitis

### 1. Create Application Project
1. File → New → Application Project
2. Select your hardware platform (exported from Vivado)
3. Create new application: `i2c_demo`
4. Select "Empty Application" template

### 2. Add Source Files
1. Right-click `src` folder → Import
2. Add `i2c_master.h`, `i2c_master.c`, `main.c`

### 3. Update Base Address
In `i2c_master.h`, update the base address:
```c
#define I2C_MASTER_BASEADDR     0x40000000  // Check Address Editor!
```

**To find actual address:**
1. Open Vivado Block Design
2. Go to Address Editor
3. Find `i2c_master_0` base address
4. Update `I2C_MASTER_BASEADDR`

### 4. Build and Run
1. Build project (Ctrl+B)
2. Program FPGA with bitstream
3. Run → Run As → Launch on Hardware

## Demo Sequence

The application runs 5 demos automatically:

### 1. LED Slave Demo
Writes 6 different patterns to LED slave:
- 0x00 (all off)
- 0xFF (all on)
- 0xAA (alternating)
- 0x55 (alternating)
- 0x0F (lower half)
- 0xF0 (upper half)

### 2. FND Slave Demo
Displays hex digits 0-F on 7-segment display sequentially.

### 3. Switch Slave Demo
Reads switch values 10 times and displays in hex and binary.
Toggle switches during this demo to see different values.

### 4. Interactive Demo
Runs for 30 seconds:
- Reads switches continuously
- Mirrors switch state to LEDs
- Shows lower 4 bits on 7-segment display

### 5. Invalid Address Test
Attempts to write to non-existent slave (0x99) to verify NACK handling.

## API Usage Examples

### Write to LED Slave
```c
#include "i2c_master.h"

int status;
status = i2c_write_byte(I2C_SLAVE_LED_ADDR, 0xAA);
if (status == 0) {
    xil_printf("Success!\n");
}
```

### Read from Switch Slave
```c
#include "i2c_master.h"

int status;
u8 switch_data;

status = i2c_read_byte(I2C_SLAVE_SWITCH_ADDR, &switch_data);
if (status == 0) {
    xil_printf("Switch value: 0x%02X\n", switch_data);
}
```

### Error Handling
```c
int status = i2c_write_byte(0x55, 0xFF);

switch (status) {
    case 0:
        // Success
        break;
    case -1:
        // Timeout - slave not responding
        break;
    case -2:
        // NACK - slave rejected transaction
        break;
}
```

## Hardware Setup

### Master Board (Board #1)
- Program with MicroBlaze bitstream
- Connect UART for xil_printf output
- PMOD JB: SDA (A16), SCL (A14)

### Slave Board (Board #2)
- Program with slave bitstream
- PMOD JA: SDA (J1), SCL (L2)

### Connection
1. Connect PMOD cable between boards (JB ↔ JA)
2. **External pull-up resistors (4.7kΩ) required on SDA and SCL**
3. Common ground via PMOD cable

## Troubleshooting

### Timeout Errors
- Check PMOD cable connection
- Verify pull-up resistors (4.7kΩ)
- Confirm slave board is programmed

### NACK Errors
- Verify slave address (0x55, 0x56, 0x57)
- Check slave bitstream is running
- Ensure slaves are not held in reset

### Wrong Base Address
- Open Vivado Address Editor
- Verify I2C Master base address
- Update `I2C_MASTER_BASEADDR` in `i2c_master.h`

### No UART Output
- Check USB-UART connection
- Verify baud rate (115200)
- Ensure MicroBlaze has UART configured

## Customization

### Add Custom I2C Transaction
```c
// Example: Blink LEDs with custom pattern
void blink_leds(void) {
    for (int i = 0; i < 10; i++) {
        i2c_write_byte(I2C_SLAVE_LED_ADDR, 0xFF);
        sleep(1);
        i2c_write_byte(I2C_SLAVE_LED_ADDR, 0x00);
        sleep(1);
    }
}
```

### Modify Timeout
In `i2c_master.h`:
```c
#define I2C_TIMEOUT_CYCLES      100000  // Increase if needed
```

## Performance Notes

- I2C Clock: 100 kHz
- Transaction time: ~1-2 ms (single byte)
- Software timeout: ~1 ms at 100 MHz MicroBlaze

## License

Educational use - Basys3 I2C Project
