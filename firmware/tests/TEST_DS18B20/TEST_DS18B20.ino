// TEST_DS18B20.ino
// Verifica que ambos sensores DS18B20 lean correctamente.
// Valores esperados: temperatura entre 10-40°C

#include <OneWire.h>
#include <DallasTemperature.h>

#define Wtemp_pin 4

OneWire oneWire(Wtemp_pin);
DallasTemperature DS18B20(&oneWire);

void setup() {
  Serial.begin(9600);
  DS18B20.begin();
  Serial.print("Sensores DS18B20 encontrados: ");
  Serial.println(DS18B20.getDeviceCount()); // debe imprimir 2
  delay(1000);
}

void loop() {
  DS18B20.requestTemperatures();
  float temp0 = DS18B20.getTempCByIndex(0);
  float temp1 = DS18B20.getTempCByIndex(1);

  Serial.print("Estante inferior (index 0): ");
  if (temp0 == DEVICE_DISCONNECTED_C) {
    Serial.println("ERROR - sensor desconectado");
  } else if (temp0 < 10 || temp0 > 40) {
    Serial.println("FUERA DE RANGO");
  } else {
    Serial.print(temp0);
    Serial.println(" C  OK");
  }

  Serial.print("Estante superior (index 1): ");
  if (temp1 == DEVICE_DISCONNECTED_C) {
    Serial.println("ERROR - sensor desconectado");
  } else if (temp1 < 10 || temp1 > 40) {
    Serial.println("FUERA DE RANGO");
  } else {
    Serial.print(temp1);
    Serial.println(" C  OK");
  }

  Serial.println("----------");
  delay(2000);
}

// RESULTADO ESPERADO:
// Sensores DS18B20 encontrados: 2
// Estante inferior (index 0): 22.50 C  OK
// Estante superior (index 1): 21.75 C  OK
// ----------