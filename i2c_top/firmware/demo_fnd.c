/**
 * @file demo_fnd.c
 * @brief 7-Segment Display Demo
 *
 * Demonstrates FND control via I2C
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
 * @brief FND counter demo (0-F)
 */
void demo_fnd_counter(void) {
    printf("FND Counter Demo (0-F)\n");

    for (int i = 0; i < 16; i++) {
        i2c_write_fnd(i);
        delay_ms(500);
        printf("  Display: %X\n", i);
    }

    printf("FND Counter Demo Complete\n");
}

/**
 * @brief FND hex countdown
 */
void demo_fnd_countdown(void) {
    printf("FND Countdown Demo (F-0)\n");

    for (int i = 15; i >= 0; i--) {
        i2c_write_fnd(i);
        delay_ms(400);
        printf("  Display: %X\n", i);
    }

    printf("FND Countdown Demo Complete\n");
}

/**
 * @brief FND rapid count
 */
void demo_fnd_rapid(void) {
    printf("FND Rapid Count Demo\n");

    for (int round = 0; round < 3; round++) {
        for (int i = 0; i < 16; i++) {
            i2c_write_fnd(i);
            delay_ms(100);
        }
    }

    printf("FND Rapid Count Demo Complete\n");
}

/**
 * @brief FND specific digits demo
 */
void demo_fnd_digits(void) {
    printf("FND Digit Showcase\n");

    // Show each hex digit with description
    const char* digit_names[] = {
        "0", "1", "2", "3", "4", "5", "6", "7",
        "8", "9", "A", "b", "C", "d", "E", "F"
    };

    for (int i = 0; i < 16; i++) {
        i2c_write_fnd(i);
        printf("  Showing: %s\n", digit_names[i]);
        delay_ms(800);
    }

    printf("FND Digit Showcase Complete\n");
}

/**
 * @brief Main FND demo
 */
void demo_fnd_main(void) {
    printf("\n=== I2C 7-Segment Display Demo ===\n");
    printf("Slave Address: 0x56\n\n");

    demo_fnd_counter();
    delay_ms(1000);

    demo_fnd_countdown();
    delay_ms(1000);

    demo_fnd_rapid();
    delay_ms(1000);

    demo_fnd_digits();

    // Clear display
    i2c_write_fnd(0);

    printf("\n=== Demo Complete ===\n");
}
