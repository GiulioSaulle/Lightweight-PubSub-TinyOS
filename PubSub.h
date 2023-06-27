#ifndef PUB_SUB_H
#define PUB_SUB_H

// Maximum number of connected clients
#define MAX_CLIENTS 8

// Maximum number of topics
#define MAX_TOPICS 3

// Timeout for CONNECT and SUBSCRIBE message
#define RETRANSMISSION_TIMEOUT 5000

// Minimum and maximum delay for the random delay
#define MIN_DELAY 100
#define MAX_DELAY 800

// Maximum size of the message queue
#define MAX_QUEUE_SIZE 100


// Topic types
typedef enum {
  TEMPERATURE,
  HUMIDITY,
  LUMINOSITY
} Topic;

// Each column represents a topic (Temperature, Humidity, Luminosity) and each row represents a client
bool clientInterest[MAX_CLIENTS][3] = {{ 0, 1, 0}, { 1, 1, 0}, { 1, 1, 1}, { 0, 0, 1}, { 1, 0, 0}, { 0, 1, 1}, { 1, 0, 1}, { 1, 0, 0}};

// Topic on which each client is publishing
uint8_t publishTopic [MAX_CLIENTS] = {TEMPERATURE, HUMIDITY, LUMINOSITY, LUMINOSITY, TEMPERATURE, HUMIDITY, LUMINOSITY, TEMPERATURE};

// Message types
enum {
  CONNECT,
  CONNECT_ACK,
  SUBSCRIBE,
  SUBSCRIBE_ACK,
  PUBLISH
};

typedef nx_struct pubsub_message {
  nx_uint8_t messageType; // Message type identifier
  nx_uint16_t nodeID; // ID of the sending node
  nx_struct {
    nx_uint8_t temperature : 1; // Bit field representing Temperature selection
    nx_uint8_t humidity : 1; // Bit field representing Humidity selection
    nx_uint8_t luminosity : 1; // Bit field representing Luminosity selection
  } subTopic; // Topic on which the client is subscribing
  nx_uint8_t pubTopic; // Topic on which the client is publishing
  nx_uint16_t payloadData; // Payload data (e.g., sensor reading)
}
pubsub_message_t;

enum {
  AM_RADIO_COUNT_MSG = 10,
};

#endif