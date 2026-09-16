// TEST_VENTILADORES.ino
// Verifica que los ventiladores enciendan y apaguen correctamente.

#define v1 23
#define v2 25
#define v3 27

void setup() {
  Serial.begin(9600);
  pinMode(v1, OUTPUT);
  pinMode(v2, OUTPUT);
  pinMode(v3, OUTPUT);
  digitalWrite(v1, LOW);
  digitalWrite(v2, LOW);
  digitalWrite(v3, LOW);
  Serial.println("TEST VENTILADORES iniciado");
}

void loop() {
  // Encender
  digitalWrite(v1, HIGH);
  digitalWrite(v2, HIGH);
  digitalWrite(v3, HIGH);
  Serial.println("Ventiladores ENCENDIDOS");
  delay(5000);

  // Apagar
  digitalWrite(v1, LOW);
  digitalWrite(v2, LOW);
  digitalWrite(v3, LOW);
  Serial.println("Ventiladores APAGADOS");
  delay(5000);
}

// RESULTADO ESPERADO:
// Ventiladores ENCENDIDOS  (escuchar que arrancan)
// Ventiladores APAGADOS    (escuchar que se detienen)
// ...y así sucesivamente