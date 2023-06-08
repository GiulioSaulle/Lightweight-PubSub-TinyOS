

#ifndef RADIO_ROUTE_H
#define RADIO_ROUTE_H

typedef nx_struct radio_route_msg {
  nx_uint8_t messageType;       // Message type identifier
  nx_uint16_t nodeID;           // ID of the sending node
  nx_uint8_t topic;             // Topic identifier
  nx_uint16_t payload;          // Payload data (e.g., sensor reading)
} radio_route_msg_t;

enum {
  AM_RADIO_COUNT_MSG = 10,
};

#endif
