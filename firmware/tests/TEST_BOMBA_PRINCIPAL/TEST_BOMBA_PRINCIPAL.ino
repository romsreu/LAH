// TEST_BOMBA_PRINCIPAL.ino
// Verifica que la bomba principal encienda y apague según los tiempos configurados.

#define b0 43

unsigned long previousMillis_bomba = 0;
bool b0_state = 0;

// Tiempos cortos para verificar rápido
unsigned long interval_bomba_on  = 3000; // 3 segundos encendida
unsigned long interval_bomba_off = 2000; // 2 segundos apagada

void setup() {
  Serial.begin(9600);
  pinMode(b0, OUTPUT);
  digitalWrite(b0, HIGH); // apagada al inicio (HIGH = apagado para relé sólido)
  Serial.println("TEST BOMBA PRINCIPAL iniciado");
}

void loop() {
  unsigned long currentMillis = millis();

  if (b0_state == LOW && currentMillis - previousMillis_bomba >= interval_bomba_off) {
    digitalWrite(b0, LOW); // encender
    b0_state = HIGH;
    previousMillis_bomba = currentMillis;
    Serial.print("[");
    Serial.print(millis());
    Serial.println("] Bomba ENCENDIDA");

  } else if (b0_state == HIGH && currentMillis - previousMillis_bomba >= interval_bomba_on) {
    digitalWrite(b0, HIGH); // apagar
    b0_state = LOW;
    previousMillis_bomba = currentMillis;
    Serial.print("[");
    Serial.print(millis());
    Serial.println("] Bomba APAGADA");
  }
}

// RESULTADO ESPERADO:
// [2000] Bomba ENCENDIDA
// [5000] Bomba APAGADA
// [7000] Bomba ENCENDIDA
// ...y así sucesivamente