/**
 * @file main.c
 * @brief I2C Master Demo Application
 *
 * Demonstrates I2C communication with 3 slaves:
 *   - LED Slave (0x55): Write data to control 8 LEDs
 *   - FND Slave (0x56): Write hex digit to 7-segment display
 *   - Switch Slave (0x57): Read 8 switch values
 *
 * Control via Switches:
 *   - SW[0] = 1: Run LED demo
 *   - SW[1] = 1: Run FND demo
 *   - SW[2] = 1: Run Switch demo
 *   - SW[3] = 1: Run Interactive demo
 */

#include "i2c_master.h"
#include "xil_printf.h"
#include "xgpio.h"
#include "sleep.h"

//==============================================================================
// GPIO Configuration
//==============================================================================
#define GPIO_DEVICE_ID  XPAR_GPIO_0_DEVICE_ID
#define GPIO_CHANNEL_1  1  // Input channel (switches)
#define GPIO_CHANNEL_2  2  // Output channel (LEDs)

XGpio GpioInstance;

//==============================================================================
// Demo Functions
//==============================================================================

/**
 * @brief Test LED Slave - Write pattern to LEDs
 */
void demo_led_slave(void)
{
    int status;
    u8 patterns[] = {0x00, 0xFF, 0xAA, 0x55, 0x0F, 0xF0};
    int i;

    xil_printf("\r\n=== LED Slave Demo (0x55) ===\r\n");

    for (i = 0; i < sizeof(patterns); i++) {
        xil_printf("Writing 0x%02X to LED slave... ", patterns[i]);
        status = i2c_write_byte(I2C_SLAVE_LED_ADDR, patterns[i]);
        i2c_print_status(status);

        if (status == 0) {
            xil_printf("  -> LEDs should display: 0x%02X\r\n", patterns[i]);
        }

        sleep(1);  // Delay 1 second
    }
}

/**
 * @brief Test FND Slave - Display hex digits on 7-segment
 */
void demo_fnd_slave(void)
{
    int status;
    u8 hex_digits[] = {0x0, 0x1, 0x2, 0x3, 0x4, 0x5, 0x6, 0x7,
                       0x8, 0x9, 0xA, 0xB, 0xC, 0xD, 0xE, 0xF};
    int i;

    xil_printf("\r\n=== FND Slave Demo (0x56) ===\r\n");

    for (i = 0; i < sizeof(hex_digits); i++) {
        xil_printf("Writing 0x%01X to FND slave... ", hex_digits[i]);
        status = i2c_write_byte(I2C_SLAVE_FND_ADDR, hex_digits[i]);
        i2c_print_status(status);

        if (status == 0) {
            xil_printf("  -> 7-segment should display: %X\r\n", hex_digits[i]);
        }

        sleep(1);  // Delay 1 second
    }
}

/**
 * @brief Test Switch Slave - Read switch values
 */
void demo_switch_slave(void)
{
    int status;
    u8 switch_data;
    int i;

    xil_printf("\r\n=== Switch Slave Demo (0x57) ===\r\n");
    xil_printf("Reading switch values (10 times)...\r\n");
    xil_printf("Toggle switches to see different values!\r\n\r\n");

    for (i = 0; i < 10; i++) {
        xil_printf("Read %d: ", i + 1);
        status = i2c_read_byte(I2C_SLAVE_SWITCH_ADDR, &switch_data);

        if (status == 0) {
            xil_printf("Switch value = 0x%02X (binary: ", switch_data);
            // Print binary representation
            for (int bit = 7; bit >= 0; bit--) {
                xil_printf("%d", (switch_data >> bit) & 1);
            }
            xil_printf(")\r\n");
        } else {
            i2c_print_status(status);
        }

        sleep(1);  // Delay 1 second
    }
}

/**
 * @brief Interactive demo - combines all slaves
 */
void demo_interactive(void)
{
    int status;
    u8 switch_data;

    xil_printf("\r\n=== Interactive Demo ===\r\n");
    xil_printf("Running for 30 seconds...\r\n");
    xil_printf("- Switch values are displayed on LEDs\r\n");
    xil_printf("- Lower 4 bits shown on 7-segment display\r\n\r\n");

    for (int i = 0; i < 30; i++) {
        // Read switch value
        status = i2c_read_byte(I2C_SLAVE_SWITCH_ADDR, &switch_data);

        if (status == 0) {
            // Write switch value to LEDs
            i2c_write_byte(I2C_SLAVE_LED_ADDR, switch_data);

            // Write lower 4 bits to 7-segment display
            i2c_write_byte(I2C_SLAVE_FND_ADDR, switch_data & 0x0F);

            xil_printf("[%2d] SW=0x%02X -> LED=0x%02X, FND=%X\r\n",
                       i + 1, switch_data, switch_data, switch_data & 0x0F);
        } else {
            xil_printf("I2C error at iteration %d\r\n", i + 1);
        }

        sleep(1);
    }
}

/**
 * @brief Test invalid slave address (should get NACK)
 */
void demo_invalid_address(void)
{
    int status;

    xil_printf("\r\n=== Invalid Address Test ===\r\n");
    xil_printf("Attempting to write to non-existent slave (0x99)...\r\n");

    status = i2c_write_byte(0x99, 0xAA);
    xil_printf("Expected NACK error: ");
    i2c_print_status(status);
}

//==============================================================================
// Main Function
//==============================================================================

int main(void)
{
    int status;
    u32 switch_value;
    u32 prev_switch = 0;

    xil_printf("\r\n");
    xil_printf("========================================\r\n");
    xil_printf("  I2C Master-Slave Demo for Basys3\r\n");
    xil_printf("========================================\r\n");
    xil_printf("System Configuration:\r\n");
    xil_printf("  - Master: MicroBlaze + I2C Master IP\r\n");
    xil_printf("  - Slaves: LED (0x55), FND (0x56), SW (0x57)\r\n");
    xil_printf("  - Protocol: I2C, 100 kHz SCL\r\n");
    xil_printf("========================================\r\n\r\n");

    // Initialize GPIO
    status = XGpio_Initialize(&GpioInstance, GPIO_DEVICE_ID);
    if (status != XST_SUCCESS) {
        xil_printf("ERROR: GPIO initialization failed!\r\n");
        return -1;
    }

    // Set GPIO direction (Channel 1 = Input, Channel 2 = Output)
    XGpio_SetDataDirection(&GpioInstance, GPIO_CHANNEL_1, 0xFF);  // All input
    XGpio_SetDataDirection(&GpioInstance, GPIO_CHANNEL_2, 0x00);  // All output

    xil_printf("GPIO initialized successfully!\r\n");

    // Initialize I2C
    i2c_init();

    xil_printf("\r\n");
    xil_printf("========================================\r\n");
    xil_printf("  Waiting for switch input...\r\n");
    xil_printf("========================================\r\n");
    xil_printf("Control:\r\n");
    xil_printf("  SW[0] = 1 : LED Demo\r\n");
    xil_printf("  SW[1] = 1 : FND Demo\r\n");
    xil_printf("  SW[2] = 1 : Switch Read Demo\r\n");
    xil_printf("  SW[3] = 1 : Interactive Demo\r\n");
    xil_printf("  SW[4] = 1 : Invalid Address Test\r\n");
    xil_printf("========================================\r\n\r\n");

    // Main loop - wait for switch press
    while (1) {
        // Read switch values
        switch_value = XGpio_DiscreteRead(&GpioInstance, GPIO_CHANNEL_1);

        // Display switch value on LEDs
        XGpio_DiscreteWrite(&GpioInstance, GPIO_CHANNEL_2, switch_value);

        // Detect rising edge (switch turned on)
        if (switch_value != prev_switch) {
            if ((switch_value & 0x01) && !(prev_switch & 0x01)) {
                // SW[0] pressed - LED Demo
                demo_led_slave();
                xil_printf("\r\nWaiting for next command...\r\n\r\n");
            }

            if ((switch_value & 0x02) && !(prev_switch & 0x02)) {
                // SW[1] pressed - FND Demo
                demo_fnd_slave();
                xil_printf("\r\nWaiting for next command...\r\n\r\n");
            }

            if ((switch_value & 0x04) && !(prev_switch & 0x04)) {
                // SW[2] pressed - Switch Demo
                demo_switch_slave();
                xil_printf("\r\nWaiting for next command...\r\n\r\n");
            }

            if ((switch_value & 0x08) && !(prev_switch & 0x08)) {
                // SW[3] pressed - Interactive Demo
                demo_interactive();
                xil_printf("\r\nWaiting for next command...\r\n\r\n");
            }

            if ((switch_value & 0x10) && !(prev_switch & 0x10)) {
                // SW[4] pressed - Invalid Address Test
                demo_invalid_address();
                xil_printf("\r\nWaiting for next command...\r\n\r\n");
            }

            prev_switch = switch_value;
        }

        usleep(50000);  // 50ms delay
    }

    return 0;
}
