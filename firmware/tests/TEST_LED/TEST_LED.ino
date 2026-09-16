// TEST_LED.ino
// Verifica que los LEDs enciendan y apaguen correctamente según los tiempos configurados.
// Observar con multímetro o mirando físicamente los LEDs.

#define LED1 39
#define LED2 41
#define v0   29

unsigned long previousMillis_LED = 0;
bool LED_state = 0;

// Tiempos cortos para verificar rápido
unsigned long interval_LED_on  = 5000;  
unsigned long interval_LED_off = 5000;  

void setup() {
  Serial.begin(9600);
  pinMode(LED1, OUTPUT);
  pinMode(LED2, OUTPUT);
  pinMode(v0, OUTPUT);
  digitalWrite(LED1, HIGH); // apagado
  digitalWrite(LED2, HIGH); // apagado
  digitalWrite(v0, LOW);
  Serial.println("TEST LED iniciado");
}

void loop() {
  unsigned long currentMillis = millis();

  if (LED_state == LOW && currentMillis - previousMillis_LED >= interval_LED_off) {
    digitalWrite(LED1, LOW);   // encender
    digitalWrite(LED2, LOW);
    digitalWrite(v0, HIGH);    // ventilador LED encendido
    LED_state = HIGH;
    previousMillis_LED = currentMillis;
    Serial.print("[");
    Serial.print(millis());
    Serial.println("] LEDs ENCENDIDOS - ventilador ON");

  } else if (LED_state == HIGH && currentMillis - previousMillis_LED >= interval_LED_on) {
    digitalWrite(LED1, HIGH);  // apagar
    digitalWrite(LED2, HIGH);
    digitalWrite(v0, LOW);     // ventilador LED apagado
    LED_state = LOW;
    previousMillis_LED = currentMillis;
    Serial.print("[");
    Serial.print(millis());
    Serial.println("] LEDs APAGADOS - ventilador OFF");
  }
}

// RESULTADO ESPERADO:
// [1000] LEDs ENCENDIDOS - ventilador ON
// [3000] LEDs APAGADOS  - ventilador OFF
// [4000] LEDs ENCENDIDOS - ventilador ON
// ...y así sucesivamente