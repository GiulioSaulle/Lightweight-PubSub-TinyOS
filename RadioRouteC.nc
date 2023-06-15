#include "Timer.h"

#include "RadioRoute.h"

#include <stdlib.h>
#include <time.h>

module RadioRouteC @safe() {
  uses {

    /****** INTERFACES *****/
    interface Boot;

    //interfaces for communication
    interface Packet;
    interface SplitControl as AMControl;
    interface Receive;
    interface AMSend;

    //interface for timers
    interface Timer < TMilli > as Timer0;
    interface Timer < TMilli > as Timer1;
    //other interfaces, if needed
  }
}
implementation {

  message_t packet;

  // Variables to store the message to send
  message_t queued_packet;
  uint16_t queue_addr;
  
  // Radio Busy Flag
  bool locked;

  // Maximum number of connected clients
  #define MAX_CLIENTS 8

  // Maximum number of topics
  #define MAX_TOPICS 3

  // Timeout for the CONNECT message
  #define CONNECT_TIMEOUT 5000

  // Minimum and maximum delay for the random delay
  #define MIN_DELAY 100
  #define MAX_DELAY 500


  typedef struct {
    uint16_t nodeID; // ID of the client node
    bool isConnected; // Connection status of the client
    bool isSubscribed[MAX_TOPICS]; // Subscription status for each topic
  }
  ClientInfo;

  typedef struct {
    ClientInfo clients[MAX_CLIENTS]; // Array of connected clients
  }
  PANCoordinator;

  bool actual_send(uint16_t address, message_t * packet);
  bool generate_send(uint16_t address, message_t * packet, uint8_t type);

  void initializePANCoordinator(PANCoordinator * coordinator);
  bool isConnected(const PANCoordinator * coordinator, uint16_t nodeID);
  bool isSubscribed(const PANCoordinator * coordinator, uint16_t nodeID, uint8_t topic);
  void subscribe(PANCoordinator * coordinator, uint16_t nodeID, uint8_t topic);

  uint16_t generateRandomDelay(uint16_t minDelay, uint16_t maxDelay);

  bool generate_send(uint16_t address, message_t * packet, uint8_t type) {
    /*
     * 
     * Function to be used when performing the send after the receive message event.
     * It store the packet and address into a global variable and start the timer execution to schedule the send.
     * @Input:
     *		address: packet destination address
     *		packet: full packet to be sent (Not only Payload)
     *		type: payload message type
     *
     */
    if (call Timer0.isRunning()) {
      return FALSE;
    } else {

      call Timer0.startOneShot(generateRandomDelay(MIN_DELAY, MAX_DELAY));
      queued_packet = * packet;
      queue_addr = address;
    }
    return TRUE;
  }

  event void Timer0.fired() {
    /*
     * Timer triggered to perform the send.
     * MANDATORY: DO NOT MODIFY THIS FUNCTION
     */
    actual_send(queue_addr, & queued_packet);
  }

  bool actual_send(uint16_t address, message_t * packet) {
    /*
     * Implement here the logic to perform the actual send of the packet using the tinyOS interfaces
     */

    radio_route_msg_t * payload = (radio_route_msg_t*)call Packet.getPayload(packet, sizeof(radio_route_msg_t));

    if (locked){
      dbgerror("radio_send", "Radio is locked\n");
      return FALSE;
    }

    switch(payload->messageType){

      case 0:
        //CONNECT
        if (call AMSend.send(address, packet, sizeof(radio_route_msg_t)) == SUCCESS) {
          locked = TRUE;
          dbg("radio_send", "Node %hu Sent a CONNECT message to PANC\n", TOS_NODE_ID);
          return TRUE;
        } else {
          dbgerror("radio_send", "Node %hu Failed to send a CONNECT message to PANC\n", TOS_NODE_ID);
          return FALSE;
        }
        break;

      default:
      dbgerror("radio_send", "Trying to send an invalid message type\n");
      return FALSE;
      break;   
    }

  }

  event void Boot.booted() {
    dbg("boot", "Application booted.\n");
    // Start the radio
    call AMControl.start();
  }

  event void AMControl.startDone(error_t err) {
    /* Fill it ... */
    if (err == SUCCESS) {
      dbg("radio", "Radio started.\n");
      // Start the timer after the radio has started up successfully
      call Timer1.startOneShot(CONNECT_TIMEOUT);
    } else {
      // Radio startup failed
      dbg("radio", "Radio failed to start. Trying Againg...\n");
      // Try to start the radio again
      call AMControl.start();
    }

  }

  event void AMControl.stopDone(error_t err) {
    dbg("radio", "Radio stopped.\n");
  }

  event void Timer1.fired() {
    /*
     * Logic to trigger the Nodes to send CONNECT packets
     */

    dbg("timer", "Timer1 fired.\n");
    if (TOS_NODE_ID != 1) {
      radio_route_msg_t * payload = (radio_route_msg_t * ) call Packet.getPayload( &packet, sizeof(radio_route_msg_t));
      if (payload == NULL) {
        // Failed to obtain payload pointer
        dbgerror("radio_pack", "Failed to obtain payload\n");
      } else {
        payload -> messageType = 0;
        payload -> nodeID = TOS_NODE_ID;

        // Generate and schedule the message transmission
        if (!generate_send(1, &packet, payload -> messageType)) {
          // Failed to schedule the message transmission, handle the error
          dbgerror("radio_send", "Failed to schedule message transmission\n");
        } else {
          dbg("radio_send", "Node %hu Scheduled a CONNECT message to PANC\n", TOS_NODE_ID);
        }
      }
    }

  }

  event message_t * Receive.receive(message_t * bufPtr, void * payload, uint8_t len) {
    /*
     * Parse the receive packet.
     * Implement all the functionalities
     * Perform the packet send using the generate_send function if needed
     */

    dbg("radio_rec", "Received packet at time %s\n", sim_time_string());
     
    }

  event void AMSend.sendDone(message_t * bufPtr, error_t error) {
    /* This event is triggered when a message is sent 
     *  Check if the packet is sent 
     */

      if (error == SUCCESS) {

      // Unlocked the radio
      locked = FALSE;

      dbg("radio_send", "Packet sent...");
      dbg_clear("radio_send", " at time %s \n", sim_time_string());

    }
    else{
      dbgerror("radio_send", "Send done error!\n");
    }
  }

  void initializePANCoordinator(PANCoordinator * coordinator) {
    // Iterate over the clients array and initialize each client
    int i, j;
    for (i = 0; i < MAX_CLIENTS; i++) {
      coordinator -> clients[i].nodeID = 0; // Initialize node ID to 0
      coordinator -> clients[i].isConnected = FALSE; // Set isConnected to false
      for (j = 0; j < MAX_TOPICS; j++) {
        coordinator -> clients[i].isSubscribed[j] = FALSE; // Set all subscriptions to false
      }
    }
  }

  bool isConnected(const PANCoordinator * coordinator, uint16_t nodeID) {
    // Iterate over the clients array to find the node
    int i;
    for (i = 0; i < MAX_CLIENTS; i++) {
      if (coordinator -> clients[i].nodeID == nodeID && coordinator -> clients[i].isConnected) {
        // Node found and is connected
        return TRUE;
      }
    }
    // Node not found or not connected
    return FALSE;
  }

  bool isSubscribed(const PANCoordinator * coordinator, uint16_t nodeID, uint8_t topic) {
    // Iterate over the clients array to find the node
    int i;
    for (i = 0; i < MAX_CLIENTS; i++) {
      if (coordinator -> clients[i].nodeID == nodeID && coordinator -> clients[i].isConnected) {
        // Check if the node is subscribed to the topic
        return coordinator -> clients[i].isSubscribed[topic];
      }
    }
    // Node not found or not connected
    return FALSE;
  }

  void subscribe(PANCoordinator * coordinator, uint16_t nodeID, uint8_t topic) {
    // Iterate over the clients array to find the node
    int i;
    for (i = 0; i < MAX_CLIENTS; i++) {
      if (coordinator -> clients[i].nodeID == nodeID && coordinator -> clients[i].isConnected) {
        // Subscribe the node to the topic
        coordinator -> clients[i].isSubscribed[topic] = TRUE;
        break;
      }
    }
  }

// Function to generate random delays in milliseconds within a specified range
uint16_t generateRandomDelay(uint16_t minDelay, uint16_t maxDelay) {
  uint16_t randomDelay = 0;
  // Ensure random number generation is seeded only once
  static bool isSeeded = FALSE;
  if (!isSeeded) {
    srand((uint16_t) TOS_NODE_ID); // Use node ID as the seed for randomization
    isSeeded = TRUE;
  }

  // Generate a random delay within the specified range
  randomDelay = minDelay + (rand() % (maxDelay - minDelay + 1));
  return randomDelay;
}
}