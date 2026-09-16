#include "programas.h"

Programa PERSONALIZADO = {
  .nombre        = "PERSONALIZADO",
  .fase_dia      = 12UL * 3600000UL,
  .fase_noche    = 12UL * 3600000UL,
  .led_ciclo_on  = 30UL * 60000UL,
  .led_ciclo_off = 30UL * 60000UL,
  .bomba_on      =  1UL * 3600000UL,
  .bomba_off     =  1UL * 3600000UL,
  .limit_temp    = 22.0,
  .pH_low        = 6.0,
  .pH_high       = 7.0,
  .EC_low        = 1.0,
  .EC_high       = 2.0
};