/**
 * @file demo_switch.c
 * @brief Switch Reading Demo
 *
 * Demonstrates reading switches via I2C and copying to LED
 */

#include "i2c_driver.h"
#include <stdio.h>

// Platform-specific delay (adjust based on your platform)
void delay_ms(uint32_t ms) {
    // TODO: Implement platform-specific delay
    volatile uint32_t count = ms * 25000;
    while (count--);
}

/**
 * @brief Read switch and display value
 */
void demo_switch_read(void) {
    printf("Switch Read Demo\n");
    printf("Reading switch 10 times...\n");

    for (int i = 0; i < 10; i++) {
        uint8_t sw_value;
        int result = i2c_read_switch(&sw_value);

        if (result == I2C_SUCCESS) {
            printf("  Switch[%02d]: 0x%02X (binary: ", i, sw_value);

            // Print binary representation
            for (int bit = 7; bit >= 0; bit--) {
                printf("%d", (sw_value >> bit) & 1);
            }
            printf(")\n");
        } else {
            printf("  Error reading switch: %d\n", result);
        }

        delay_ms(1000);
    }

    printf("Switch Read Demo Complete\n");
}

/**
 * @brief Copy switch value to LED
 */
void demo_switch_to_led(void) {
    printf("Switch → LED Copy Demo\n");
    printf("Running for 30 seconds... (change switches to see LED update)\n");

    for (int i = 0; i < 300; i++) {  // 30 seconds at 100ms intervals
        uint8_t sw_value;

        if (i2c_read_switch(&sw_value) == I2C_SUCCESS) {
            i2c_write_led(sw_value);

            // Print every second
            if (i % 10 == 0) {
                printf("  SW: 0x%02X → LED: 0x%02X\n", sw_value, sw_value);
            }
        }

        delay_ms(100);
    }

    printf("Switch → LED Demo Complete\n");
}

/**
 * @brief Switch to FND display
 */
void demo_switch_to_fnd(void) {
    printf("Switch → FND Display Demo\n");
    printf("Lower 4 bits of switch will show on FND\n");
    printf("Running for 20 seconds...\n");

    for (int i = 0; i < 200; i++) {  // 20 seconds at 100ms intervals
        uint8_t sw_value;

        if (i2c_read_switch(&sw_value) == I2C_SUCCESS) {
            uint8_t digit = sw_value & 0x0F;  // Lower 4 bits
            i2c_write_fnd(digit);

            // Print every second
            if (i % 10 == 0) {
                printf("  SW[3:0]: 0x%01X → FND: %01X\n", digit, digit);
            }
        }

        delay_ms(100);
    }

    printf("Switch → FND Demo Complete\n");
}

/**
 * @brief Switch pattern detection
 */
void demo_switch_patterns(void) {
    printf("Switch Pattern Detection Demo\n");
    printf("Set switches to special patterns:\n");
    printf("  0xFF: All ON\n");
    printf("  0x00: All OFF\n");
    printf("  0xAA: Alternating 1\n");
    printf("  0x55: Alternating 2\n");
    printf("Running for 20 seconds...\n");

    for (int i = 0; i < 200; i++) {
        uint8_t sw_value;

        if (i2c_read_switch(&sw_value) == I2C_SUCCESS) {
            // Detect patterns
            if (sw_value == 0xFF) {
                printf("  ⚡ Pattern detected: ALL ON (0xFF)\n");
            } else if (sw_value == 0x00) {
                printf("  ⚡ Pattern detected: ALL OFF (0x00)\n");
            } else if (sw_value == 0xAA) {
                printf("  ⚡ Pattern detected: ALTERNATING 1 (0xAA)\n");
            } else if (sw_value == 0x55) {
                printf("  ⚡ Pattern detected: ALTERNATING 2 (0x55)\n");
            }
        }

        delay_ms(100);
    }

    printf("Switch Pattern Demo Complete\n");
}

/**
 * @brief Main switch demo
 */
void demo_switch_main(void) {
    printf("\n=== I2C Switch Reading Demo ===\n");
    printf("Slave Address: 0x57\n\n");

    demo_switch_read();
    delay_ms(1000);

    demo_switch_to_led();
    delay_ms(1000);

    demo_switch_to_fnd();
    delay_ms(1000);

    demo_switch_patterns();

    // Clear outputs
    i2c_write_led(0x00);
    i2c_write_fnd(0x00);

    printf("\n=== Demo Complete ===\n");
}
