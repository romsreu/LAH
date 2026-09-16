/********************************************************************
 ***    Laboratorio Autocontenido Hidropónico de Industria 4.0    ***
 ********************************************************************

 ********************************************************************
 ************************   SENSORES   ******************************
 *  Declaraciones  y  prototipos  correspondientes  a  la  lectura  *
 *  y  control  de  los  sensores  del  sistema:  temperatura  am-  *
 *  biente,  temperatura  de  solución,  pH  y  conductividad  eléc- *
 *  trica.  Las  variables  externas  referenciadas  aquí  están    *
 *  definidas  en  main.ino.                                        *
 ********************************************************************/

#ifndef SENSORES_H
#define SENSORES_H

#include <Arduino.h>
#include <DHT.h>
#include <OneWire.h>
#include <DallasTemperature.h>

extern DHT dht_int, dht_ext;
extern OneWire oneWire;
extern DallasTemperature DS18B20;

extern float temp_value_int, temp_value_ext;
extern float hum_value_int, hum_value_ext;
extern float Wtemp0_value, Wtemp1_value;
extern float pH_value, pH_low, pH_high;
extern float EC_value, EC_low, EC_high;
extern float offset, VREF, coef, tempCoef, refTemp;
extern int temp_samples, pH_samples, EC_samples;
extern unsigned long previousMillis_temp, previousMillis_Wtemp;
extern unsigned long previousMillis_pH, previousMillis_EC;

void temp_config();
void temp_control(float, unsigned long);
void Wtemp_read(unsigned long);
float pH_read();
float EC_read();
void pHcontrol(unsigned long);
void ECcontrol(unsigned long);

#endif