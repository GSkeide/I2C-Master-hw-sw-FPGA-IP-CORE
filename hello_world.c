#include <stdio.h>
#include <unistd.h>
#include "alt_types.h"

#define RTC_ADR 0x68 // slave address for ds3231 rtc
#define byte unsigned char

#define I2C_MODE_STANDARD 0 // 100khz
#define I2C_MODE_FAST 1     // 400 khz

// henter funksjoner (fra i2cdriver.c)
void i2c_set_mode(int mode);
void i2c_set_slave_adr(byte slave_adr);
void set_rtc_time(byte, byte, byte, byte, byte, byte, byte);
void get_rtc_time(byte *, byte *, byte *, byte *, byte *, byte *, byte *);
float get_rtc_temp(void);

int main() {
	// starter med å sette scl modus og hvilken slave vi sender til
    i2c_set_mode(I2C_MODE_STANDARD);
    i2c_set_slave_adr(RTC_ADR);

    byte sec, min, hr, wd, d, mon, yr; // definer variabler
    float temperatur;

    set_rtc_time(0, 0, 0, 0, 0, 0, 0); // sett tid alt til 0

    while (1) {
        get_rtc_time(&sec, &min, &hr, &wd, &d, &mon, &yr); // henter ut tid
        printf("\n\n\n-------------------------------------------\n");
        printf("Time: %02d:%02d:%02d\n", hr, min, sec);
        printf("Date: 20%02d-%02d-%02d (Weekday: %d)\n", yr, mon, d, wd);
        temperatur = get_rtc_temp(); // henter ut temperatur
        printf("Temperaturen er %5.2f Celsius\n", temperatur);
        printf("-------------------------------------------\n");
        usleep(200000);
    }

    return 0;
}
