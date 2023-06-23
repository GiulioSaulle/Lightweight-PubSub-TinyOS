

#ifndef PUB_SUB_H
#define PUB_SUB_H

// Maximum number of connected clients
#define MAX_CLIENTS 8

// Maximum number of topics
#define MAX_TOPICS 3

// Timeout for the CONNECT message
#define CONNECT_TIMEOUT 5000

// Minimum and maximum delay for the random delay
#define MIN_DELAY 100
#define MAX_DELAY 800

// Message types
enum {
  CONNECT = 0,
  CONNECT_ACK = 1,
  SUBSCRIBE = 2,
  SUBSCRIBE_ACK = 3,
  PUBLISH = 4
};

typedef nx_struct pubsub_message {
  nx_uint8_t messageType;       // Message type identifier
  nx_uint16_t nodeID;           // ID of the sending node
  nx_uint8_t topic;             // Topic identifier
  nx_uint16_t payload;          // Payload data (e.g., sensor reading)
} pubsub_message_t;

enum {
  AM_RADIO_COUNT_MSG = 10,
};

#endif
