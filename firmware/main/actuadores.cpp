/********************************************************************
 ***    Laboratorio Autocontenido Hidropónico de Industria 4.0    ***
 ********************************************************************

 ********************************************************************
 ***********************   ACTUADORES   *****************************
 *  Implementación  de  las  funciones  de  control  de  actuadores  *
 *  del  sistema.  Incluye  configuración  y  manejo  de  ventila-  *
 *  dores,  bombas  peristálticas,  bomba  principal,  LEDs  de    *
 *  iluminación  y  caudalímetros.                                  *
 ********************************************************************/

#include "actuadores.h"
#include "config.h"
extern const float VOLUMEN_POR_PULSO;

void vent_config() {
  pinMode(v0, OUTPUT);
  pinMode(v1, OUTPUT);
  pinMode(v2, OUTPUT);
  pinMode(v3, OUTPUT);

  digitalWrite(v0, LOW);
  digitalWrite(v1, LOW);
  digitalWrite(v2, LOW);
  digitalWrite(v3, LOW);

  v0_state = 0;
  v1_state = 0;
  v2_state = 0;
  v3_state = 0;
}

void bombas_config() {
  pinMode(b1, OUTPUT);
  pinMode(b2, OUTPUT);
  pinMode(b3, OUTPUT);
  pinMode(b4, OUTPUT);
  pinMode(b0, OUTPUT);

  digitalWrite(b1, LOW);
  digitalWrite(b2, LOW);
  digitalWrite(b3, LOW);
  digitalWrite(b4, LOW);
  digitalWrite(b0, HIGH); // HIGH es apagado para el relé sólido

  b1_state = 0;
  b2_state = 0;
  b3_state = 0;
  b4_state = 0;
  b0_state = 0;
}

void LED_config() {
  pinMode(LED1, OUTPUT);
  pinMode(LED2, OUTPUT);

  // Inicia encendido (LOW = encendido para relé sólido)
  digitalWrite(LED1, LOW);
  digitalWrite(LED2, LOW);
  digitalWrite(v0, HIGH);  // Ventilador de refrigeración LED encendido

  LED_state  = 1;
  fase_dia_activa = true;
}

void caudalimetro_config() {
  pinMode(c1, INPUT);
  pinMode(c2, INPUT);
  pinMode(c3, INPUT);
  pinMode(c4, INPUT);
}

void bombita_on(uint8_t pinBomba, uint8_t pinCaudal, int& pulsos, float& vol, bool& estado, float ml) {
  while (vol < ml) {
    attachInterrupt(digitalPinToInterrupt(pinCaudal), pulsos++, RISING);
    vol = ((pulsos * VOLUMEN_POR_PULSO) / 10.0) - 10.7;
    digitalWrite(pinBomba, HIGH);
    estado = HIGH;
  }

  digitalWrite(pinBomba, LOW);
  estado = LOW;
  detachInterrupt(digitalPinToInterrupt(pinCaudal));
  pulsos = 0;
  vol = 10.7;
}

/********************************************************************
 *  LED — fotoperíodo con ciclo interno                            *
 *                                                                  *
 *  fase_dia:    duración total de la fase con luz                 *
 *  fase_noche:  duración total de la fase sin luz                 *
 *  ciclo_on:    tiempo encendido dentro de la fase día            *
 *  ciclo_off:   tiempo apagado dentro de la fase día              *
 *                                                                  *
 *  Comportamiento:                                                 *
 *  Al encender → fase día → parpadea ciclo_on/ciclo_off           *
 *  Al cumplir fase_dia → apagado fijo durante fase_noche          *
 *  Al cumplir fase_noche → vuelve a fase día                      *
 ********************************************************************/

void LED(unsigned long fase_dia, unsigned long fase_noche,
         unsigned long ciclo_on, unsigned long ciclo_off) {

  unsigned long currentMillis = millis();

  if (fase_dia_activa) {
    // --- Verificar si terminó la fase día ---
    if (currentMillis - previousMillis_fotoperiodo >= fase_dia) {
      previousMillis_fotoperiodo = currentMillis;
      previousMillis_LED         = currentMillis;
      fase_dia_activa            = false;

      // Apagar LEDs al entrar en noche
      digitalWrite(LED1, HIGH);
      digitalWrite(LED2, HIGH);
      digitalWrite(v0, LOW);
      LED_state = 0;
      LDRvalue  = analogRead(LDRpin);
      return;
    }

    // --- Ciclo interno ON/OFF dentro de la fase día ---
    if (LED_state == 0 && currentMillis - previousMillis_LED >= ciclo_off) {
      digitalWrite(LED1, LOW);
      digitalWrite(LED2, LOW);
      digitalWrite(v0, HIGH);
      LED_state        = 1;
      previousMillis_LED = currentMillis;
      LDRvalue         = analogRead(LDRpin);
      nivelIluminacion = LDRvalue / 950 * 100;

    } else if (LED_state == 1 && currentMillis - previousMillis_LED >= ciclo_on) {
      digitalWrite(LED1, HIGH);
      digitalWrite(LED2, HIGH);
      digitalWrite(v0, LOW);
      LED_state        = 0;
      previousMillis_LED = currentMillis;
      LDRvalue         = analogRead(LDRpin);
      nivelIluminacion = LDRvalue / 950 * 100;
    }

  } else {
    // --- Fase noche: esperar y volver al día ---
    if (currentMillis - previousMillis_fotoperiodo >= fase_noche) {
      previousMillis_fotoperiodo = currentMillis;
      previousMillis_LED         = currentMillis;
      fase_dia_activa            = true;

      // Encender LEDs al iniciar nuevo día
      digitalWrite(LED1, LOW);
      digitalWrite(LED2, LOW);
      digitalWrite(v0, HIGH);
      LED_state = 1;
      LDRvalue  = analogRead(LDRpin);
    }
  }
}

void bomba(unsigned long bomba_tOn, unsigned long bomba_tOff) {
  unsigned long currentMillis = millis();

  if (b0_state == HIGH && currentMillis - previousMillis_bomba >= bomba_tOn) {
    digitalWrite(b0, HIGH);
    b0_state = LOW;
    previousMillis_bomba = currentMillis;
  } else if (b0_state == LOW && currentMillis - previousMillis_bomba >= bomba_tOff) {
    digitalWrite(b0, LOW);
    b0_state = HIGH;
    previousMillis_bomba = currentMillis;
  }
}

void vent(bool vent_st) {
  if (vent_st == 1) {
    digitalWrite(v1, HIGH);
    digitalWrite(v2, HIGH);
    digitalWrite(v3, HIGH);
    v1_state = 1;
    v2_state = 1;
    v3_state = 1;
  } else if (vent_st == 0) {
    digitalWrite(v1, LOW);
    digitalWrite(v2, LOW);
    digitalWrite(v3, LOW);
    v1_state = 0;
    v2_state = 0;
    v3_state = 0;
  }
}
