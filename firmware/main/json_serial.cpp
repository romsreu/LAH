/********************************************************************
 ***    Laboratorio Autocontenido Hidropónico de Industria 4.0    ***
 ********************************************************************

 ********************************************************************
 *********************   COMUNICACIÓN JSON   ************************
 *  Implementación  de  la  función  de  envío  de  datos  por  puer-  *
 *  to  serie.  Se  ejecuta  únicamente  al  recibir  el  comando   *
 *  'P'  desde  la  Raspberry  Pi.  El  JSON  incluye  lecturas  de  *
 *  sensores,  estados  de  actuadores  e  intervalos  de  control.  *
 ********************************************************************/

#include "json_serial.h"
#include "config.h"

void enviar_json() {
  StaticJsonDocument<JSON_BUFFER_SIZE_VAL> doc;

  // Temperaturas y humedades
  doc["temperatura_interior"]              = temp_value_int;
  doc["humedad_interior"]                  = hum_value_int;
  doc["temperatura_exterior"]              = temp_value_ext;
  doc["humedad_exterior"]                  = hum_value_ext;
  doc["temperatura_solucion_estante_superior"] = Wtemp1_value;
  doc["temperatura_solucion_estante_inferior"] = Wtemp0_value;

  // pH y CE
  doc["ph"]                                = pH_value;
  doc["electroconductividad"]              = EC_value;
  doc["intensidad_luz"]                    = LDRvalue;

  // Límites de control
  doc["temperatura_setpoint"]              = limit_temp;
  doc["ph_setpoint_minimo"]                = pH_low;
  doc["ph_setpoint_maximo"]                = pH_high;
  doc["electroconductividad_setpoint_minimo"] = EC_low;
  doc["electroconductividad_setpoint_maximo"] = EC_high;

  // Intervalos
  doc["bomba_tanque_principal_tiempo_encendido"] = interval_bomba_on;
  doc["bomba_tanque_principal_tiempo_apagado"]   = interval_bomba_off;
  doc["led_tiempo_encendido"] = programa_activo.led_ciclo_on;
  doc["led_tiempo_apagado"]   = programa_activo.led_ciclo_off;
  doc["intervalo_control_ph"]              = interval_pH;
  doc["intervalo_control_ce"]              = interval_EC;
  doc["intervalo_control_temperatura_aire"]    = interval_temp;
  doc["intervalo_control_temperatura_solucion"] = interval_Wtemp;
  doc["intervalo_control_luz"]             = INTERVAL_LDR;

  // Estados
  doc["led_estante_superior_estado"]       = LED_state;
  doc["led_estante_inferior_estado"]       = LED_state;
  doc["bomba_tanque_principal_estado"]     = b0_state;
  doc["bomba_tanque_1_estado"]             = b1_state;
  doc["bomba_tanque_2_estado"]             = b2_state;
  doc["bomba_tanque_3_estado"]             = b3_state;
  doc["bomba_tanque_4_estado"]             = b4_state;
  doc["ventilador_principal_estado"]       = v0_state;
  doc["ventilador_1_estado"]               = v1_state;
  doc["ventilador_2_estado"]               = v2_state;
  doc["ventilador_3_estado"]               = v3_state;

  // Fallos
  doc["fallo_pid"]                         = fail_PID;

  String jsonString;
  serializeJson(doc, jsonString);
  Serial.println(jsonString);
}