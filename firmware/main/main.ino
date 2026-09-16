/********************************************************************
 ***    Laboratorio Autocontenido Hidropónico de Industria 4.0    ***
 ********************************************************************

 ************************   IMPORTANTE   ****************************
 *  El  puerto  serie  está  reservado  exclusivamente  para   la   *
 *  transmisión  de  datos  en  formato  JSON.  Modificar  la  ló-  *
 *  gica  del  sistema  únicamente  si  se  tiene  pleno  conoci-   *
 *  miento  de  lo  que  se  está  realizando,  ya  que  el  có-    *
 *  digo  controla  hardware  real  y  un  error  puede  ocasionar  *
 *  daños  físicos  irreversibles.  Para  pruebas,  utilizar  los   *
 *  sketches  unitarios  por  módulo  disponibles  en  el  reposi-  *
 *  torio.  Ante  cualquier  duda,  consultar  la  documentación    *
 *  antes  de  realizar  algún  cambio.                             *
 ****** https://github.com/romsreu/hydrolab/tree/main/docs **********
 ********************************************************************

 ********************************************************************
 ***********************   MAPA DE PINES   **************************
 ** https://github.com/romsreu/hydrolab/blob/main/docs/LAHI4.0.pdf **
 ***************** https://hydrolabutn.netlify.app/ *****************
 ********************************************************************

 ********************************************************************
 *********************   PINOUT ATMEGA2560   ************************
 ****** https://lastminuteengineers.com/arduino-mega-pinout/ ********
 *******************************************************************/

/********************************************************************
 ************************   PARÁMETROS   ****************************
 *******************************************************************/

/******************   HUMEDAD Y TEMPERATURA   **********************/

float LHum = 80.0;  // [%] Límite de humedad relativa

/***************************   pH   ********************************/

float pH_value = 0;  // [pH] Valor medido

/***************   CONDUCTIVIDAD ELÉCTRICA (EC)   ******************/

float EC_value = 0;  // [mS/cm] Valor medido

/***********************   VENTILACIÓN   ****************************/

float vent_time = 0;  // [ms] Duración de ventilación

/********************************************************************
 **************   VARIABLES DE TIEMPO Y MUESTREO   ******************
 *******************************************************************/

const float MIN_TO_MILLISECONDS = 60000;

/**********************   TIEMPO GENERAL   **************************/

unsigned long currentMillis = 0;

/*********************   IMPRESIÓN SERIAL   *************************/

unsigned long previousMillis_print = 0;
unsigned long interval_print = 1 * MIN_TO_MILLISECONDS;

/***************************   pH   ********************************/

unsigned long previousMillis_pH = 0;
unsigned long interval_pH = 10 * MIN_TO_MILLISECONDS;
int pH_samples = 5;

/***************************   EC   ********************************/

unsigned long previousMillis_EC = 0;
unsigned long interval_EC = 0 * MIN_TO_MILLISECONDS;
int EC_samples = 0;

/*******************   TEMPERATURA AMBIENTE   ***********************/

unsigned long previousMillis_temp = 0;
unsigned long interval_temp = 1 * MIN_TO_MILLISECONDS;
int temp_samples = 0;

/*********************   TEMPERATURA AGUA   *************************/

unsigned long previousMillis_Wtemp = 0;
unsigned long interval_Wtemp = 1 * MIN_TO_MILLISECONDS;

/********************   LUZ AMBIENTE (LDR)   ************************/

unsigned long previousMillis_LDR = 0;
const long interval_LDR = 900000;

/**************************   LEDs   ********************************/

unsigned long previousMillis_LED = 0;
unsigned long previousMillis_fotoperiodo = 0;
bool fase_dia_activa = true;

/**********************   BOMBA PRINCIPAL   *************************/

unsigned long previousMillis_bomba = 0;

/************************   DISPLAY LCD   ***************************/

unsigned long previousMillis_display = 0;
const unsigned long interval_display = 8000;
unsigned long previousMillis_refresh = 0;
const unsigned long interval_refresh = 5000;  // refresco de valores en pantalla
bool screenChanged = true;                    // fuerza redibujo al cambiar de pantalla
int screenIndex = 0;
const int totalScreens = 5;

/********************************************************************
 **********************   ¡NO MODIFICAR!   **************************
 *  A  partir  de  esta  sección  se  definen  las  librerías,  de- *
 *  claraciones,  variables  de  estado  y  parámetros  internos    *
 *  del  sistema.  No  editar  salvo  que  se  desee  modificar  la *
 *  lógica  de  funcionamiento  interna.                            *
 ********************************************************************/

/********************************************************************
 ************************   LIBRERÍAS   *****************************
 *******************************************************************/

#include <DHT.h>
#include <OneWire.h>
#include <DallasTemperature.h>
#include <ArduinoJson.h>
#include <Wire.h>
#include <LiquidCrystal_I2C.h>
#include "programas.h"

LiquidCrystal_I2C lcd(0x3F, 20, 4);

#include "display.h"
#include "sensores.h"
#include "actuadores.h"
#include "json_serial.h"
#include "config.h"

/********************************************************************
 ******************  CONFIGURACIÓN SENSORES   ***********************
 *******************************************************************/

/*************************   DHT22   *******************************/

#define DHTTYPE DHT22
DHT dht_int(DHTPIN_int, DHTTYPE);
DHT dht_ext(DHTPIN_ext, DHTTYPE);
float temp_value_int = 0, temp_value_ext = 0;
float hum_value_int = 0, hum_value_ext = 0;
float Wtemp0_value = 0, Wtemp1_value = 0;

/**************************   LDR   ********************************/

int LDRvalue = 0;
int nivelIluminacion = 0;

/************************   DS18B20   ******************************/

OneWire oneWire(Wtemp_pin);
DallasTemperature DS18B20(&oneWire);

/***************************   pH   ********************************/

float offset = 0.00;  // Ajustar en calibración

/***************************   EC   ********************************/

float VREF = 5.0;
float coef = 1.0;       // Constante de calibración (k-value) del sensor EC/TDS
float tempCoef = 0.02;  // Coef. de compensación térmica (2 %/°C, ref. KS0429)
float refTemp = 25.0;

/********************************************************************
 ********************  VARIABLES DE ESTADO   ************************
 *******************************************************************/

/*************************   BOMBAS   ******************************/

bool b0_state = 0, b1_state = 0, b2_state = 0, b3_state = 0, b4_state = 0;

/**************************   LEDs   *******************************/

bool LED_state = 0;

/**********************   VENTILADORES   ***************************/

bool v0_state = 0, v1_state = 0, v2_state = 0, v3_state = 0;
// v0 Refrigeración LED, v1 Columna Izq, v2 Columna Central, v3 Columna Der

/**********************   CAUDALÍMETROS   ***************************/

const float VOLUMEN_POR_PULSO = 2.25;
float b1_cant = 0, b2_cant = 0, b3_cant = 0, b4_cant = 0;
float vol1 = 10.7, vol2 = 10.7, vol3 = 10.7, vol4 = 10.7;
int pulsos1 = 0, pulsos2 = 0, pulsos3 = 0, pulsos4 = 0;

/********************************************************************
 ***********************  PARÁMETROS PID   **************************
 *******************************************************************/

double Kp = 14.1176;
double Ki = Kp / 120;
double Kd = Kp * 30 - 200;
double input = 0, output = 0;
unsigned long lastTime;
double ITerm = 0, lastInput = 0;
double error_actual = 0, integral = 0;
bool fail_PID = 0;

/********************************************************************
 *****************   PROGRAMA ACTIVO   ******************************
 *******************************************************************/

Programa programa_activo = MENTA;

float limit_temp = programa_activo.limit_temp;
float pH_low = programa_activo.pH_low;
float pH_high = programa_activo.pH_high;
float EC_low = programa_activo.EC_low;
float EC_high = programa_activo.EC_high;
unsigned long interval_bomba_on = programa_activo.bomba_on;
unsigned long interval_bomba_off = programa_activo.bomba_off;

/********************************************************************
 ****************************  SETUP   ******************************
 *******************************************************************/

void setup() {
  Serial.begin(9600);

  lcd.init();
  lcd.backlight();
  lcd.setCursor(0, 0);
  lcd.print("Armario Hidroponico");
  lcd.setCursor(0, 1);
  lcd.print("Iniciando...");

  vent_config();
  bombas_config();
  LED_config();
  caudalimetro_config();
  temp_config();

  // Lectura inicial de temperatura de solución para no mostrar 0 al arrancar
  DS18B20.requestTemperatures();
  Wtemp0_value = DS18B20.getTempCByIndex(0);
  Wtemp1_value = DS18B20.getTempCByIndex(1);

  pinMode(A1, INPUT);
  pinMode(A2, INPUT);
  lastTime = millis();
  lastInput = dht_int.readTemperature();
}

/********************************************************************
 *****************************  LOOP   ******************************
 *******************************************************************/

void loop() {
  currentMillis = millis();
  pH_value = pH_read();
  EC_value = EC_read();

  if (currentMillis - previousMillis_refresh >= interval_refresh || screenChanged) {
    previousMillis_refresh = currentMillis;
    screenChanged = false;
    switch (screenIndex) {
      case 0: showScreen1(); break;
      case 1: showScreen2(); break;
      case 2: showScreen3(); break;
      case 3: showScreen4(); break;
      case 4: showScreen5(); break;
    }
  }

  if (currentMillis - previousMillis_display >= interval_display) {
    previousMillis_display = currentMillis;
    screenIndex++;
    if (screenIndex >= totalScreens) screenIndex = 0;
    lcd.clear();
    screenChanged = true;
  }

  LED(programa_activo.fase_dia,
      programa_activo.fase_noche,
      programa_activo.led_ciclo_on,
      programa_activo.led_ciclo_off);

  temp_control(limit_temp, interval_temp);
  Wtemp_read(interval_Wtemp);
  bomba(interval_bomba_on, interval_bomba_off);

  // pHcontrol(interval_pH);
  // ECcontrol(interval_EC);

  if (currentMillis - previousMillis_print >= interval_print) {
    previousMillis_print = currentMillis;
  }

  if (Serial.available()) {
    char command = Serial.read();
    if (command == 'P') enviar_json();
  }
}
