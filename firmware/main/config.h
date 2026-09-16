#ifndef CONFIG_H
#define CONFIG_H

// Salidas digitales
#define v1   23
#define v2   25
#define v3   27
#define v0   29
#define b1   31
#define b2   33
#define b3   35
#define b4   37
#define LED1 39
#define LED2 41
#define b0   43

// Entradas digitales
#define c1 45
#define c2 47
#define c3 49
#define c4 51

// Sensores
#define DHTPIN_ext 2
#define DHTPIN_int 3
#define Wtemp_pin  4
#define LDRpin     A0
#define pHPin      A1
#define ECPin      A2

// ArduinoJson
#define JSON_BUFFER_SIZE_VAL 2048

#define INTERVAL_LDR 900000L
#endif