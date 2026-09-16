// CAL_pH.ino
// Sketch de calibración por HARDWARE (potenciómetro) del módulo PH-4502C.
//
// Procedimiento:
//   1. Sumergir la sonda en la muestra de referencia (pH conocido, medido con
//      pHímetro patrón).
//   2. Abrir el Monitor Serie (9600 baudios) y dejar que la sonda se estabilice
//      unos segundos (temperatura/hidratación del bulbo).
//   3. Girar DESPACIO el potenciómetro del módulo PH-4502C, mirando el valor
//      "pH" que imprime este sketch, hasta que coincida con el valor de la
//      muestra de referencia.
//   4. NO tocar nada del software: la fórmula usada acá es fija (3.5*V + 0),
//      la calibración real la hace el trimmer del módulo corriendo la curva.
//
// No usa offset/pendiente ajustados por software a propósito: mientras se
// gira el potenciómetro, cualquier corrección por software enmascararía el
// efecto real del ajuste de hardware.

#define pHPin A1
const int N_MUESTRAS = 15;  // promedio para suavizar ruido del ADC mientras se gira el pot

void setup() {
  Serial.begin(9600);
  pinMode(pHPin, INPUT);
  Serial.println(F("=== Calibración de pH (potenciómetro PH-4502C) ==="));
  Serial.println(F("Sonda en la muestra de referencia, girar el trimmer hasta que 'pH' coincida."));
  Serial.println();
}

void loop() {
  long sumaRaw = 0;
  for (int i = 0; i < N_MUESTRAS; i++) {
    sumaRaw += analogRead(pHPin);
    delay(10);
  }
  float raw = sumaRaw / (float)N_MUESTRAS;

  float voltage = raw * (5.0 / 1023.0);
  float pH_value = 3.5 * voltage;  

  Serial.print(F("Raw: "));
  Serial.print(raw, 1);
  Serial.print(F(" | Voltaje: "));
  Serial.print(voltage, 3);
  Serial.print(F(" V | pH: "));
  Serial.println(pH_value, 2);

  delay(300);
}
