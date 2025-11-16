/**
 * @file main.c
 * @brief Main firmware application for I2C Multi-Slave Demo
 *
 * This application demonstrates communication with three I2C slaves:
 *  - LED Slave (0x55)
 *  - FND Slave (0x56)
 *  - Switch Slave (0x57)
 */

#include "i2c_driver.h"
#include <stdio.h>
#include <stdint.h>

// Platform-specific delay
void delay_ms(uint32_t ms) {
    // TODO: Replace with platform-specific delay
    // For Xilinx: MB_Sleep(ms)
    volatile uint32_t count = ms * 25000;
    while (count--);
}

// External demo functions
extern void demo_led_main(void);
extern void demo_fnd_main(void);
extern void demo_switch_main(void);

/**
 * @brief Combined demo: All features
 */
void demo_all_features(void) {
    printf("\n========================================\n");
    printf("Combined I2C Multi-Slave Demo\n");
    printf("========================================\n\n");

    uint8_t counter = 0;

    for (int round = 0; round < 5; round++) {
        printf("\n--- Round %d/5 ---\n", round + 1);

        // 1. Blink LED
        printf("  LED: Blinking...\n");
        i2c_write_led(0xFF);
        delay_ms(300);
        i2c_write_led(0x00);
        delay_ms(300);

        // 2. Update FND counter
        printf("  FND: Displaying %X\n", counter);
        i2c_write_fnd(counter);
        counter = (counter + 1) & 0x0F;

        // 3. Read and display switch
        uint8_t sw_value;
        if (i2c_read_switch(&sw_value) == I2C_SUCCESS) {
            printf("  Switch: 0x%02X\n", sw_value);
            i2c_write_led(sw_value);
        }

        delay_ms(1000);
    }

    // Clear all outputs
    i2c_write_led(0x00);
    i2c_write_fnd(0x00);

    printf("\n=== Combined Demo Complete ===\n");
}

/**
 * @brief Interactive demo: Switch controls LED and FND
 */
void demo_interactive(void) {
    printf("\n========================================\n");
    printf("Interactive Demo\n");
    printf("========================================\n");
    printf("Switch[7:0] → LED[7:0]\n");
    printf("Switch[3:0] → FND digit\n");
    printf("Running for 30 seconds...\n");
    printf("(Change switches to see real-time update)\n\n");

    for (int i = 0; i < 300; i++) {
        uint8_t sw_value;

        if (i2c_read_switch(&sw_value) == I2C_SUCCESS) {
            // Copy to LED
            i2c_write_led(sw_value);

            // Lower 4 bits to FND
            i2c_write_fnd(sw_value & 0x0F);

            // Print every 2 seconds
            if (i % 20 == 0) {
                printf("  SW: 0x%02X → LED: 0x%02X, FND: %01X\n",
                       sw_value, sw_value, sw_value & 0x0F);
            }
        }

        delay_ms(100);
    }

    printf("\n=== Interactive Demo Complete ===\n");
}

/**
 * @brief Quick test: Verify all slaves respond
 */
int test_all_slaves(void) {
    printf("\n========================================\n");
    printf("Quick Slave Test\n");
    printf("========================================\n\n");

    int passed = 0;
    int failed = 0;

    // Test LED Slave
    printf("Testing LED Slave (0x55)... ");
    if (i2c_write_led(0xAA) == I2C_SUCCESS) {
        printf("✓ PASS\n");
        passed++;
    } else {
        printf("✗ FAIL\n");
        failed++;
    }
    delay_ms(100);

    // Test FND Slave
    printf("Testing FND Slave (0x56)... ");
    if (i2c_write_fnd(0x05) == I2C_SUCCESS) {
        printf("✓ PASS\n");
        passed++;
    } else {
        printf("✗ FAIL\n");
        failed++;
    }
    delay_ms(100);

    // Test Switch Slave
    printf("Testing Switch Slave (0x57)... ");
    uint8_t sw_value;
    if (i2c_read_switch(&sw_value) == I2C_SUCCESS) {
        printf("✓ PASS (read: 0x%02X)\n", sw_value);
        passed++;
    } else {
        printf("✗ FAIL\n");
        failed++;
    }

    printf("\n========================================\n");
    printf("Test Results: %d passed, %d failed\n", passed, failed);
    printf("========================================\n\n");

    return (failed == 0) ? 0 : -1;
}

/**
 * @brief Main application
 */
int main(void) {
    printf("\n");
    printf("========================================\n");
    printf("  I2C Multi-Slave System Demo\n");
    printf("  Basys3 FPGA - Educational Project\n");
    printf("========================================\n");
    printf("Master: I2C Master IP\n");
    printf("Slaves:\n");
    printf("  - LED Slave (0x55)\n");
    printf("  - FND Slave (0x56)\n");
    printf("  - Switch Slave (0x57)\n");
    printf("========================================\n");

    // TODO: Replace with actual base address from Vivado
    // Example: 0x44A00000
    uint32_t i2c_base_addr = 0x44A00000;  // CHANGE THIS!

    printf("\nInitializing I2C Master at 0x%08X...\n", i2c_base_addr);
    i2c_init(i2c_base_addr);
    printf("I2C Master initialized.\n");

    // Quick test
    if (test_all_slaves() != 0) {
        printf("\n⚠ WARNING: Some slaves did not respond!\n");
        printf("Check connections and slave board power.\n");
    }

    delay_ms(2000);

    // Run demos
    while (1) {
        demo_all_features();
        delay_ms(2000);

        demo_interactive();
        delay_ms(2000);

        demo_led_main();
        delay_ms(2000);

        demo_fnd_main();
        delay_ms(2000);

        demo_switch_main();
        delay_ms(5000);

        printf("\n\n=== Restarting demo cycle ===\n\n");
    }

    return 0;
}
