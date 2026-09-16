// TEST_JSON.ino
// Verifica que el JSON se arme y envíe correctamente.
// No necesita hardware extra, usar valores fijos.

#include <ArduinoJson.h>

const size_t JSON_BUFFER_SIZE = JSON_OBJECT_SIZE(50);

void setup() {
  Serial.begin(9600);
  Serial.println("TEST JSON iniciado");
  delay(1000);
}

void loop() {
  StaticJsonDocument<JSON_BUFFER_SIZE> doc;

  // Valores fijos para verificar que el JSON se arma bien
  doc["temperatura_interior"]              = 23.5;
  doc["humedad_interior"]                  = 55.2;
  doc["temperatura_exterior"]              = 21.0;
  doc["humedad_exterior"]                  = 60.1;
  doc["temperatura_solucion_estante_superior"] = 22.3;
  doc["temperatura_solucion_estante_inferior"] = 21.8;
  doc["ph"]                                = 7.2;
  doc["electroconductividad"]              = 1.4;
  doc["intensidad_luz"]                    = 750;
  doc["temperatura_setpoint"]              = 22.0;
  doc["ph_setpoint_minimo"]                = 6.0;
  doc["ph_setpoint_maximo"]                = 8.0;
  doc["electroconductividad_setpoint_minimo"] = 0.0;
  doc["electroconductividad_setpoint_maximo"] = 0.0;
  doc["bomba_tanque_principal_tiempo_encendido"] = 60000;
  doc["bomba_tanque_principal_tiempo_apagado"]   = 120000;
  doc["led_tiempo_encendido"]              = 120000;
  doc["led_tiempo_apagado"]               = 60000;
  doc["led_estante_superior_estado"]       = true;
  doc["led_estante_iniferior_estado"]      = true;
  doc["bomba_tanque_principal_estado"]     = false;
  doc["bomba_tanque_1_estado"]             = false;
  doc["bomba_tanque_2_estado"]             = false;
  doc["bomba_tanque_3_estado"]             = false;
  doc["bomba_tanque_4_estado"]             = false;
  doc["ventilador_principal_estado"]       = false;
  doc["ventilador_1_estado"]               = false;
  doc["ventilador_2_estado"]               = false;
  doc["ventilador_3_estado"]               = false;
  doc["fallo_pid"]                         = false;

  // Verificar que no se excedió el buffer
  if (doc.overflowed()) {
    Serial.println("ERROR: JSON_BUFFER_SIZE insuficiente");
  } else {
    serializeJson(doc, Serial);
    Serial.println();
    Serial.println("JSON OK");
  }

  delay(3000);
}

// RESULTADO ESPERADO:
// {"temperatura_interior":23.5,"humedad_interior":55.2, ...}
// JSON OK