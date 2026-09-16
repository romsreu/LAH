// TEST_DHT22.ino
// Verifica que ambos sensores DHT22 lean correctamente.

#include <DHT.h>

#define DHTPIN_ext 2
#define DHTPIN_int 3
#define DHTTYPE DHT22

DHT dht_int(DHTPIN_int, DHTTYPE);
DHT dht_ext(DHTPIN_ext, DHTTYPE);

void setup() {
  Serial.begin(9600);
  dht_int.begin();
  dht_ext.begin();
  Serial.println("TEST DHT22 iniciado");
  delay(2000); // DHT22 necesita 2s para estabilizarse
}

void loop() {
  float temp_int = dht_int.readTemperature();
  float hum_int  = dht_int.readHumidity();
  float temp_ext = dht_ext.readTemperature();
  float hum_ext  = dht_ext.readHumidity();

  // Verificar interior
  Serial.print("INT - Temp: ");
  if (isnan(temp_int)) {
    Serial.print("ERROR");          // sensor desconectado o con falla
  } else {
    Serial.print(temp_int);
    Serial.print(" C  OK");
  }

  Serial.print(" | Hum: ");
  if (isnan(hum_int)) {
    Serial.println("ERROR");
  } else {
    Serial.print(hum_int);
    Serial.println(" %  OK");
  }

  // Verificar exterior
  Serial.print("EXT - Temp: ");
  if (isnan(temp_ext)) {
    Serial.print("ERROR");
  } else {
    Serial.print(temp_ext);
    Serial.print(" C  OK");
  }

  Serial.print(" | Hum: ");
  if (isnan(hum_ext)) {
    Serial.println("ERROR");
  }
  else {
    Serial.print(hum_ext);
    Serial.println(" %  OK");
  }

  Serial.println("----------");
  delay(2500); // mínimo 2s entre lecturas del DHT22
}

// RESULTADO ESPERADO:
// INT - Temp: 23.50 C  OK | Hum: 55.20 %  OK
// EXT - Temp: 21.00 C  OK | Hum: 60.10 %  OK
// ----------