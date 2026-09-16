/********************************************************************
 ***    Laboratorio Autocontenido Hidropónico de Industria 4.0    ***
 ********************************************************************

 ********************************************************************
 **********************   PROGRAMAS DE CULTIVO   ********************
 *  Define  los  perfiles  de  control  para  distintos  cultivos.  *
 *  Cada  programa  agrupa  los  parámetros  de  iluminación,  bom- *
 *  ba,  temperatura,  pH  y  EC.  Para  activar  un  programa,     *
 *  asignar  el  preset  deseado  a  programa_activo  en  main.ino  *
 *  o  modificarlo  desde  la  Raspberry  Pi  vía  JSON.            *
 ********************************************************************/

#ifndef PROGRAMAS_H
#define PROGRAMAS_H

#include <Arduino.h>

/********************************************************************
 **********************   ESTRUCTURA BASE   *************************
 *******************************************************************/

struct Programa {
  const char* nombre;

  // Fotoperíodo
  unsigned long fase_dia;         // [ms] Duración total de la fase con luz
  unsigned long fase_noche;       // [ms] Duración total de la fase sin luz

  // Ciclo de parpadeo dentro de la fase día
  unsigned long led_ciclo_on;     // [ms] Tiempo encendido dentro del día
  unsigned long led_ciclo_off;    // [ms] Tiempo apagado dentro del día

  // Bomba principal
  unsigned long bomba_on;         // [ms] Tiempo encendido
  unsigned long bomba_off;        // [ms] Tiempo apagado

  // Temperatura
  float limit_temp;               // [°C] Límite para activar ventiladores

  // pH
  float pH_low;                   // [pH] Mínimo aceptable
  float pH_high;                  // [pH] Máximo aceptable

  // Conductividad eléctrica
  float EC_low;                   // [mS/cm] Mínimo aceptable
  float EC_high;                  // [mS/cm] Máximo aceptable
};

/********************************************************************
 ***********************   PRESET: MENTA   **************************
 *  Fase día:    12 horas con luz (ciclo 30 min ON / 30 min OFF)   *
 *  Fase noche:  12 horas apagado fijo                             *
 *  Bomba:       1h ON / 1h OFF                                    *
 *  Temperatura: 22°C                                              *
 *  pH:          6.0 – 7.0                                         *
 *  EC:          1.2 – 2.4 mS/cm                                   *
 ********************************************************************/

const Programa MENTA = {
  .nombre        = "MENTA",
  .fase_dia      = 12UL * 3600000UL,   // 12 horas
  .fase_noche    = 12UL * 3600000UL,   // 12 horas
  .led_ciclo_on  = 30UL * 60000UL,     // 30 minutos
  .led_ciclo_off = 30UL * 60000UL,     // 30 minutos
  .bomba_on      =  1UL * 3600000UL,   // 1 hora
  .bomba_off     =  1UL * 3600000UL,   // 1 hora
  .limit_temp    = 22.0,
  .pH_low        = 6.0,
  .pH_high       = 7.0,
  .EC_low        = 1.2,
  .EC_high       = 2.4
};

/********************************************************************
 ********************   PROGRAMA PERSONALIZADO   ********************
 *  Modificar  los  valores  a  gusto  antes  de  compilar,  o     *
 *  sobreescribir  desde  la  Raspberry  Pi  vía  JSON  en  runtime.*
 ********************************************************************/

extern Programa PERSONALIZADO;

#endif
