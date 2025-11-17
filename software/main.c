/**
 * @file main.c
 * @brief I2C Master Demo Application
 *
 * Demonstrates I2C communication with 3 slaves:
 *   - LED Slave (0x55): Write data to control 8 LEDs
 *   - FND Slave (0x56): Write hex digit to 7-segment display
 *   - Switch Slave (0x57): Read 8 switch values
 */

#include "i2c_master.h"
#include "xil_printf.h"
#include "sleep.h"

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
    xil_printf("\r\n");
    xil_printf("========================================\r\n");
    xil_printf("  I2C Master-Slave Demo for Basys3\r\n");
    xil_printf("========================================\r\n");
    xil_printf("System Configuration:\r\n");
    xil_printf("  - Master: MicroBlaze + I2C Master IP\r\n");
    xil_printf("  - Slaves: LED (0x55), FND (0x56), SW (0x57)\r\n");
    xil_printf("  - Protocol: I2C, 100 kHz SCL\r\n");
    xil_printf("========================================\r\n\r\n");

    // Initialize I2C
    i2c_init();

    // Run demos
    demo_led_slave();
    demo_fnd_slave();
    demo_switch_slave();
    demo_interactive();
    demo_invalid_address();

    xil_printf("\r\n========================================\r\n");
    xil_printf("  Demo Complete!\r\n");
    xil_printf("========================================\r\n");

    return 0;
}
