// TEST_pH_EC.ino
// Verifica la lectura de pH y EC con los potenciómetros.
// Girar el potenciómetro y verificar que el valor cambie en rango esperado.

#define pHPin A1
#define ECPin A2

float offset = 0.00;
float VREF = 5.0;
float coef = 1.0;

void setup() {
  Serial.begin(9600);
  pinMode(pHPin, INPUT);
  pinMode(ECPin, INPUT);
  Serial.println("TEST pH y EC iniciado");
}

void loop() {
  // pH
  int rawPH = analogRead(pHPin);
  float voltPH = rawPH * (5.0 / 1023.0);
  float pH_value = 3.5 * voltPH + offset;

  Serial.print("pH - Raw: ");
  Serial.print(rawPH);
  Serial.print(" | Voltaje: ");
  Serial.print(voltPH, 3);
  Serial.print(" V | pH: ");
  if (pH_value < 0 || pH_value > 14) {
    Serial.println("FUERA DE RANGO");
  } else {
    Serial.print(pH_value, 2);
    Serial.println("  OK");
  }

  // EC
  int rawEC = analogRead(ECPin);
  float voltEC = rawEC * VREF / 1024.0;
  float EC_value = voltEC * coef;

  Serial.print("EC - Raw: ");
  Serial.print(rawEC);
  Serial.print(" | Voltaje: ");
  Serial.print(voltEC, 3);
  Serial.print(" V | EC: ");
  Serial.print(EC_value, 3);
  Serial.println(" mS/cm  OK");

  Serial.println("----------");
  delay(1000);
}

// RESULTADO ESPERADO al girar potenciometros:
// pH - Raw: 512 | Voltaje: 2.500 V | pH: 8.75  OK
// EC - Raw: 300 | Voltaje: 1.465 V | EC: 1.465 mS/cm  OK
// ----------