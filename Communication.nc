#include "PubSub.h"


typedef struct {
  uint16_t nodeID; // ID of the client node
  bool isConnected; // Connection status of the client
  bool isSubscribed[MAX_TOPICS]; // Subscription status for each topic
}
NodeInfo;

typedef struct {
  NodeInfo clients[MAX_CLIENTS]; // Array of connected clients
}
CommunicationNetwork;

void initializeCommunicationNetwork(CommunicationNetwork * network) {
  // Iterate over the clients array and initialize each client
  uint8_t i, j;
  for (i = 0; i < MAX_CLIENTS; i++) {
    network -> clients[i].nodeID = i + 2; // Set the nodeID
    network -> clients[i].isConnected = FALSE; // Set isConnected to false
    for (j = 0; j < MAX_TOPICS; j++) {
      network -> clients[i].isSubscribed[j] = FALSE; // Set all subscriptions to false
    }
  }
}

bool isConnected(CommunicationNetwork * network, uint16_t nodeID) {
  // Iterate over the clients array to find the node
  uint8_t i;
  for (i = 0; i < MAX_CLIENTS; i++) {
    if (network -> clients[i].nodeID == nodeID) {
      // Check if the node is connected
      return network -> clients[i].isConnected;
    }
  }
  return FALSE;
}

bool addConnection(CommunicationNetwork * network, uint16_t nodeID) {
  // Iterate over the clients array to find the node and set isConnected to true
  uint8_t i;
  for (i = 0; i < MAX_CLIENTS; i++) {
    if (network -> clients[i].nodeID == nodeID) {
      // Check if the node is connected
      network -> clients[i].isConnected = TRUE;
      return TRUE;
    }
  }
  return FALSE;
}

bool isSubscribed(CommunicationNetwork * network, uint16_t nodeID, uint8_t topic) {
  // Iterate over the clients array to find the node
  uint8_t i;
  for (i = 0; i < MAX_CLIENTS; i++) {
    if (network -> clients[i].nodeID == nodeID && network -> clients[i].isConnected) {
      // Check if the node is subscribed to the topic
      return network -> clients[i].isSubscribed[topic];
    }
  }
  // Node not found or not connected
  return FALSE;
}

void subscribe(CommunicationNetwork * network, uint16_t nodeID, uint8_t topic) {
  // Iterate over the clients array to find the node
  uint8_t i;
  for (i = 0; i < MAX_CLIENTS; i++) {
    if (network -> clients[i].nodeID == nodeID && network -> clients[i].isConnected) {
      // Subscribe the node to the topic
      network -> clients[i].isSubscribed[topic] = TRUE;
      break;
    }
  }
}