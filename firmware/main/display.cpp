#include "display.h"
#include "config.h"
#include "programas.h"
extern Programa programa_activo;

void showScreen1() {
  String tempStr;

  auto printRight = [&](const char* label, float val, int row) {
    tempStr = String(val, 1) + " C";
    if (tempStr.length() > 19) tempStr = tempStr.substring(0, 19);
    lcd.setCursor(0, row);
    lcd.print(label);
    lcd.setCursor(19 - tempStr.length() + 1, row);
    lcd.print(tempStr);
  };

  printRight("Temp Interior:", temp_value_int, 0);
  printRight("Temp Exterior:", temp_value_ext, 1);
  printRight("Solucion Sup: ", Wtemp1_value,   2);
  printRight("Solucion Inf: ", Wtemp0_value,   3);
}

void showScreen2() {
  String valStr;

  lcd.setCursor(0, 0);
  lcd.print("     -- pH --       ");

  valStr = "Valor: " + String(pH_value, 2);
  lcd.setCursor(0, 1);
  lcd.print(valStr);

  valStr = "Min:   " + String(pH_low, 2);
  lcd.setCursor(0, 2);
  lcd.print(valStr);

  valStr = "Max:   " + String(pH_high, 2);
  lcd.setCursor(0, 3);
  lcd.print(valStr);
}

void showScreen3() {
  String valStr;

  lcd.setCursor(0, 0);
  lcd.print("     -- EC --       ");

  valStr = "Valor: " + String(EC_value, 2) + " mS/cm";
  lcd.setCursor(0, 1);
  lcd.print(valStr);

  valStr = "Min:   " + String(EC_low, 2);
  lcd.setCursor(0, 2);
  lcd.print(valStr);

  valStr = "Max:   " + String(EC_high, 2);
  lcd.setCursor(0, 3);
  lcd.print(valStr);
}

void showScreen4() {
  String valStr;

  lcd.setCursor(0, 0);
  lcd.print("  -- Intervalos --  ");

  valStr = "Bomba: " + String(interval_bomba_on / 60000) + "/" + String(interval_bomba_off / 60000) + " min";
  lcd.setCursor(0, 1);
  lcd.print(valStr);

  valStr = "LED:   " + String(programa_activo.led_ciclo_on / 60000) + "/" + String(programa_activo.led_ciclo_off / 60000) + " min";
  lcd.setCursor(0, 2);
  lcd.print(valStr);

  valStr = "Temp:  " + String(interval_temp / 60000) + " min";
  lcd.setCursor(0, 3);
  lcd.print(valStr);
}

static String fmtTime(unsigned long ms) {
  unsigned long secs = ms / 1000;
  unsigned long mins = secs / 60;
  unsigned long hrs  = mins / 60;
  char buf[6];
  if (mins >= 60)
    sprintf(buf, "%02luh%02lu", hrs, mins % 60);
  else
    sprintf(buf, "%02lu:%02lu", mins, secs % 60);
  return String(buf);
}

void showScreen5() {
  unsigned long now = millis();
  String row;

  // Fila 0: fase día/noche del LED UV, tiempo restante
  unsigned long fase_dur     = fase_dia_activa ? programa_activo.fase_dia : programa_activo.fase_noche;
  unsigned long fase_elapsed = now - previousMillis_fotoperiodo;
  unsigned long fase_rem     = (fase_elapsed < fase_dur) ? fase_dur - fase_elapsed : 0;
  row = fase_dia_activa ? "LED UV Dia  " : "LED UV Noc  ";
  row += fmtTime(fase_rem);
  lcd.setCursor(0, 0);
  lcd.print(row);

  // Fila 1: ciclo ON/OFF del LED UV (solo en fase día)
  lcd.setCursor(0, 1);
  if (fase_dia_activa) {
    unsigned long ciclo_dur     = LED_state ? programa_activo.led_ciclo_on : programa_activo.led_ciclo_off;
    unsigned long ciclo_elapsed = now - previousMillis_LED;
    unsigned long ciclo_rem     = (ciclo_elapsed < ciclo_dur) ? ciclo_dur - ciclo_elapsed : 0;
    row = LED_state ? "Ciclo ON    " : "Ciclo OFF   ";
    row += fmtTime(ciclo_rem);
  } else {
    row = "LED UV: Apagado     ";
  }
  lcd.print(row);

  // Fila 2: bomba principal, tiempo restante
  unsigned long bomba_dur     = b0_state ? interval_bomba_on : interval_bomba_off;
  unsigned long bomba_elapsed = now - previousMillis_bomba;
  unsigned long bomba_rem     = (bomba_elapsed < bomba_dur) ? bomba_dur - bomba_elapsed : 0;
  row = b0_state ? "Bomba ON    " : "Bomba OFF   ";
  row += fmtTime(bomba_rem);
  lcd.setCursor(0, 2);
  lcd.print(row);

  // Fila 3: ventiladores (reactivos a temperatura, sin timer)
  row = "Vents: ";
  row += v1_state ? "ON " : "OFF";
  lcd.setCursor(0, 3);
  lcd.print(row);
}