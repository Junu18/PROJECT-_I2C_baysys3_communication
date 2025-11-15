/**
 * @file demo_led.c
 * @brief LED Control Demo
 *
 * Demonstrates LED control via I2C
 */

#include "i2c_driver.h"
#include <stdio.h>

// Platform-specific delay (adjust based on your platform)
void delay_ms(uint32_t ms) {
    // TODO: Implement platform-specific delay
    // For MicroBlaze, use MB_Sleep() or similar
    volatile uint32_t count = ms * 25000;
    while (count--);
}

/**
 * @brief LED blink pattern demo
 */
void demo_led_blink(void) {
    printf("LED Blink Demo\n");

    for (int i = 0; i < 10; i++) {
        // All LEDs ON
        i2c_write_led(0xFF);
        delay_ms(500);

        // All LEDs OFF
        i2c_write_led(0x00);
        delay_ms(500);
    }

    printf("LED Blink Demo Complete\n");
}

/**
 * @brief LED running light pattern
 */
void demo_led_running(void) {
    printf("LED Running Light Demo\n");

    for (int round = 0; round < 5; round++) {
        for (int i = 0; i < 8; i++) {
            i2c_write_led(1 << i);
            delay_ms(100);
        }
    }

    i2c_write_led(0x00);
    printf("LED Running Light Demo Complete\n");
}

/**
 * @brief LED binary counter
 */
void demo_led_counter(void) {
    printf("LED Counter Demo (0-255)\n");

    for (int i = 0; i <= 255; i++) {
        i2c_write_led(i);
        delay_ms(50);
    }

    i2c_write_led(0x00);
    printf("LED Counter Demo Complete\n");
}

/**
 * @brief LED pattern showcase
 */
void demo_led_patterns(void) {
    printf("LED Pattern Demo\n");

    uint8_t patterns[] = {
        0xAA,  // 10101010
        0x55,  // 01010101
        0xF0,  // 11110000
        0x0F,  // 00001111
        0xCC,  // 11001100
        0x33,  // 00110011
        0xFF,  // 11111111
        0x00   // 00000000
    };

    for (int i = 0; i < 8; i++) {
        i2c_write_led(patterns[i]);
        delay_ms(500);
    }

    printf("LED Pattern Demo Complete\n");
}

/**
 * @brief Main LED demo
 */
void demo_led_main(void) {
    printf("\n=== I2C LED Control Demo ===\n");
    printf("Slave Address: 0x55\n\n");

    demo_led_blink();
    delay_ms(1000);

    demo_led_running();
    delay_ms(1000);

    demo_led_counter();
    delay_ms(1000);

    demo_led_patterns();

    printf("\n=== Demo Complete ===\n");
}
