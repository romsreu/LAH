/********************************************************************
 ***    Laboratorio Autocontenido Hidropónico de Industria 4.0    ***
 ********************************************************************

 ********************************************************************
 *********************   COMUNICACIÓN JSON   ************************
 *  Declaraciones  correspondientes  a  la  serialización  y  trans-  *
 *  misión  de  datos  por  puerto  serie  en  formato  JSON  hacia  *
 *  la  Raspberry  Pi.  No  imprimir  nada  más  por  el  puerto    *
 *  serie  mientras  esta  función  esté  activa.                   *
 ********************************************************************/

#ifndef JSON_SERIAL_H
#define JSON_SERIAL_H

#include <Arduino.h>
#include <ArduinoJson.h>
#include "programas.h"

extern Programa programa_activo;
extern float temp_value_int, temp_value_ext;
extern float hum_value_int, hum_value_ext;
extern float Wtemp0_value, Wtemp1_value;
extern float pH_value, pH_low, pH_high;
extern float EC_value, EC_low, EC_high;
extern float limit_temp;
extern int LDRvalue;
extern bool LED_state, b0_state, b1_state, b2_state, b3_state, b4_state;
extern bool v0_state, v1_state, v2_state, v3_state;
extern bool fail_PID;
extern unsigned long interval_bomba_on, interval_bomba_off;
extern unsigned long interval_LED_on, interval_LED_off;
extern unsigned long interval_pH, interval_EC;
extern unsigned long interval_temp, interval_Wtemp;

void enviar_json();

#endif