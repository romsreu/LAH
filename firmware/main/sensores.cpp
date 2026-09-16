/********************************************************************
 ***    Laboratorio Autocontenido Hidropónico de Industria 4.0    ***
 ********************************************************************

 ********************************************************************
 ************************   SENSORES   ******************************
 *  Implementación  de  las  funciones  de  lectura  y  control  de  *
 *  sensores.  Incluye  control  de  temperatura  con  lógica  ON/  *
 *  OFF  e  histéresis,  lectura  de  temperatura  de  solución,    *
 *  pH  y  conductividad  eléctrica  con  compensación  térmica.    *
 ********************************************************************/

#include "sensores.h"
#include "actuadores.h"
#include "config.h"
extern bool fail_PID;
extern bool b1_state, b2_state, b3_state, b4_state;
extern float vol1, vol2, vol3, vol4;
extern int pulsos1, pulsos2, pulsos3, pulsos4;

void temp_config() {
  pinMode(DHTPIN_int, INPUT);
  pinMode(DHTPIN_ext, INPUT);
  dht_int.begin();
  dht_ext.begin();
  pinMode(Wtemp_pin, INPUT);
  DS18B20.begin();
}

void temp_control(float setPoint, unsigned long temp_time) {
  unsigned long currentMillis_temp = millis();

  // La librería DHT cachea internamente (mín. 2 s entre lecturas reales),
  // por lo que se puede llamar cada loop para mantener el display al día.
  temp_value_int = dht_int.readTemperature();
  hum_value_int  = dht_int.readHumidity();
  temp_value_ext = dht_ext.readTemperature();
  hum_value_ext  = dht_ext.readHumidity();

  if (currentMillis_temp - previousMillis_temp >= temp_time) {
    previousMillis_temp = currentMillis_temp;

    // ---- Lógica ON/OFF con histéresis ----
    if (temp_value_ext < setPoint) {
      if (temp_value_int > setPoint) {
        temp_samples++;
      } else if (temp_value_int < setPoint - 1) {
        temp_samples--;
      } else {
        temp_samples = 0;
      }

      if (abs(temp_samples) >= 3) {
        if (temp_samples > 0) {
          vent(1);
        } else {
          vent(0);
        }
        temp_samples = 0;
      }
    } else {
      fail_PID = 1;
    }
  }
}

void Wtemp_read(unsigned long Wtemp_time) {
  unsigned long currentMillis_Wtemp = millis();

  if (currentMillis_Wtemp - previousMillis_Wtemp >= Wtemp_time) {
    previousMillis_Wtemp = currentMillis_Wtemp;

    DS18B20.requestTemperatures();
    Wtemp0_value = DS18B20.getTempCByIndex(0); // Estante inferior
    Wtemp1_value = DS18B20.getTempCByIndex(1); // Estante superior
  }
}

float pH_read() {
  int raw = analogRead(pHPin);
  float voltage = raw * (5.0 / 1023.0);
  pH_value = 3.5 * voltage + offset;
  return pH_value;
}

float EC_read() {
  int raw = analogRead(ECPin);
  float voltage = raw * VREF / 1024.0;

  // Temperatura de la solución del tanque principal (donde está el electrodo).
  // Ese tanque no tiene DS18B20 propio, así que se usa el promedio de los dos
  // sensores de estante como aproximación (misma solución recirculada).
  // Para mayor precisión: agregar un DS18B20 en el tanque principal —se conecta
  // en paralelo al bus OneWire (pin 4)— y reemplazar esto por DS18B20.getTempCByIndex(2).
  float solTemp = (Wtemp0_value + Wtemp1_value) / 2.0;

  // Compensación de temperatura: normaliza el voltaje a 25 °C antes del polinomio
  // (referencia Keyestudio/DFRobot KS0429, tempCoef ≈ 0.02 → 2 %/°C).
  float compCoef    = 1.0 + tempCoef * (solTemp - refTemp);
  float compVoltage = voltage / compCoef;

  // Polinomio del sensor KS0429 (TDS Meter V1.0): devuelve EC en µS/cm.
  // 'coef' es la constante de calibración (k-value); 1.0 hasta calibrar con patrón.
  float EC_uS = (133.42 * compVoltage * compVoltage * compVoltage
               - 255.86 * compVoltage * compVoltage
               + 857.39 * compVoltage) * coef;

  EC_value = EC_uS / 1000.0;   // µS/cm → mS/cm
  return EC_value;
}

void pHcontrol(unsigned long pH_time) {
  unsigned long currentMillis_pH = millis();
  if (currentMillis_pH - previousMillis_pH >= pH_time) {
    previousMillis_pH = currentMillis_pH;
    pH_value = pH_read();

    if (pH_value > pH_high) {
      pH_samples++;
    } else if (pH_value < pH_low) {
      pH_samples--;
    } else {
      pH_samples = 0;
    }

    if (abs(pH_samples) >= 3) {
      if (pH_samples > 0) {
        //el recipiente donde están las bombitas sumergibles no tiene liquido aún.
        //bombita_on debería detectar si hay líquido en el, implicaría un sensor adicional, pero
        //ayudaría a prevenir que se dañen las bombitas.
        //bombita_on(b1, c1, pulsos1, vol1, b1_state, 100.0);
      } else {
        //bombita_on(b2, c2, pulsos2, vol2, b2_state, 100.0);
      }
      pH_samples = 0;
    }
  }
}

void ECcontrol(unsigned long EC_time) {
  unsigned long currentMillis_EC = millis();
  if (currentMillis_EC - previousMillis_EC >= EC_time) {
    previousMillis_EC = currentMillis_EC;
    EC_value = EC_read();

    if (EC_value > EC_high) {
      EC_samples++;
    } else if (EC_value < EC_low) {
      EC_samples--;
    } else {
      EC_samples = 0;
    }

    if (abs(EC_samples) >= 3) {
      if (EC_samples > 0) {
        //el recipiente donde están las bombitas sumergibles no tiene liquido aún.
        //bombita_on debería detectar si hay líquido en el, implicaría un sensor adicional, pero
        //ayudaría a prevenir que se dañen las bombitas.
        //bombita_on(b3, c3, pulsos3, vol3, b3_state, 10.0);
      } else {
        //bombita_on(b4, c4, pulsos4, vol4, b4_state, 10.0);
      }
      EC_samples = 0;
    }
  }
}