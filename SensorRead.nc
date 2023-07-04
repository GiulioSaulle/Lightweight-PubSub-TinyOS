#include <stdlib.h>

// Function to generate a random temperature reading in Celsius
uint16_t generateRandomTemperature() {
  uint16_t minTemperature = 0; // Minimum temperature (0°C)
  uint16_t maxTemperature = 40; // Maximum temperature (40°C)

  // Generate a random temperature within the specified range
  uint16_t temperature = minTemperature + rand() % (maxTemperature - minTemperature + 1);

  return temperature;
}

// Function to generate a random humidity reading
uint16_t generateRandomHumidity() {
  uint16_t minHumidity = 0; // Minimum humidity (0%)
  uint16_t maxHumidity = 100; // Maximum humidity (100%)

  // Generate a random humidity within the specified range
  uint16_t humidity = minHumidity + rand() % (maxHumidity - minHumidity + 1);

  return humidity;
}

// Function to generate a random luminosity reading
uint16_t generateRandomLuminosity() {
  uint16_t minLuminosity = 0; // Minimum luminosity
  uint16_t maxLuminosity = 1023; // Maximum luminosity

  // Generate a random luminosity within the specified range
  uint16_t luminosity = minLuminosity + rand() % (maxLuminosity - minLuminosity + 1);

  return luminosity;
}