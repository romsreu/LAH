/********************************************************************
 ***    Laboratorio Autocontenido Hidropónico de Industria 4.0    ***
 ********************************************************************

 ********************************************************************
 ***********************   ACTUADORES   *****************************
 *  Declaraciones  y  prototipos  correspondientes  al  control  de  *
 *  los  actuadores  del  sistema:  ventiladores,  bombas,  LEDs  y  *
 *  caudalímetros.  Las  variables  externas  referenciadas  aquí    *
 *  están  definidas  en  main.ino.                                  *
 ********************************************************************/

#ifndef ACTUADORES_H
#define ACTUADORES_H

#include <Arduino.h>

extern bool b0_state, b1_state, b2_state, b3_state, b4_state;
extern bool LED_state;
extern bool v0_state, v1_state, v2_state, v3_state;
extern float vol1, vol2, vol3, vol4;
extern int pulsos1, pulsos2, pulsos3, pulsos4;
extern int LDRvalue, nivelIluminacion;
extern unsigned long previousMillis_LED, previousMillis_bomba;
extern unsigned long previousMillis_fotoperiodo;
extern bool fase_dia_activa;

void vent_config();
void bombas_config();
void LED_config();
void caudalimetro_config();
void bombita_on(uint8_t, uint8_t, int&, float&, bool&, float);
void LED(unsigned long, unsigned long, unsigned long, unsigned long);
void bomba(unsigned long, unsigned long);
void vent(bool);

#endif
