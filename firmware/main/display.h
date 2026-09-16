#ifndef DISPLAY_H
#define DISPLAY_H

#include <Arduino.h>
#include "sensores.h"
#include <LiquidCrystal_I2C.h>

extern LiquidCrystal_I2C lcd;

extern float temp_value_int, temp_value_ext;
extern float Wtemp0_value, Wtemp1_value;
extern float pH_value, pH_low, pH_high;
extern float EC_value, EC_low, EC_high;
extern unsigned long interval_bomba_on, interval_bomba_off;
extern unsigned long interval_temp;
extern unsigned long previousMillis_LED, previousMillis_fotoperiodo, previousMillis_bomba;
extern bool fase_dia_activa, LED_state, b0_state, v1_state;

void showScreen1();
void showScreen2();
void showScreen3();
void showScreen4();
void showScreen5();

#endif