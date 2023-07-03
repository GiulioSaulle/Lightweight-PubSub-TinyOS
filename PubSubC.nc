#include "Timer.h"

#include "PubSub.h"

#include "SensorRead.nc"

#include "Communication.nc"

#include <stdlib.h>

#include <time.h>

#include <sys/socket.h>

#include <netinet/in.h>

#include <arpa/inet.h>

#include <unistd.h>


module PubSubC @safe() {
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
    interface Timer < TMilli > as Timer2;
    interface Timer < TMilli > as Timer3;
    interface Timer < TMilli > as Timer4;
    //other interfaces, if needed
  }
}
implementation {
  //socket initialization
  struct sockaddr_in nodered_server;
 

  message_t packet;

  // Variables to store the message to send
  message_t messageQueue[MAX_QUEUE_SIZE]; // Message queue
  uint16_t addressQueue[MAX_QUEUE_SIZE]; // Address queue
  uint16_t queueSize = 0;

  uint16_t sock;

  typedef struct {
    uint8_t pubTopic;
    uint8_t payloadData;
    uint8_t nodeId;
    char simTime[20];
  } buffer_entry_t;

  buffer_entry_t transmitBuffer[MAX_QUEUE_SIZE];
  uint8_t bufferIndex = 0;

  // Radio Busy Flag
  bool locked;

  // Table to store nodes information
  CommunicationNetwork networkTable;

  bool actual_send(uint16_t address, message_t * packet);
  bool generate_send(uint16_t address, message_t * packet, uint8_t type);

  uint16_t generateRandomDelay(uint16_t minDelay, uint16_t maxDelay);

  bool generate_send(uint16_t address, message_t * packet, uint8_t type) {
    /*
     * 
     * Function to be used when performing the send after the receive message event.
     * It store the packet and address into a global queue and start the timer execution to schedule the send.
     *
     */
    if (queueSize >= MAX_QUEUE_SIZE) {
      dbgerror("radio_send", "Message queue is full\n");
      return FALSE;
    }

    // Add the message to the queue
    messageQueue[queueSize] = * packet;
    addressQueue[queueSize] = address;
    queueSize++;

    if (call Timer0.isRunning()) {

      // Timer is already running, the message will be sent later
      dbg("timer", "Timer0 is already running, the message will be sent later\n");

    } else {

      // Timer is not running, start it
      call Timer0.startOneShot(generateRandomDelay(MIN_DELAY, MAX_DELAY));
    }
    return TRUE;
  }

  event void Timer0.fired() {
    /*
     * Timer triggered to perform the send.
     */
    if (queueSize > 0) {
      actual_send(addressQueue[0], & messageQueue[0]);
    }
  }

  bool actual_send(uint16_t address, message_t * packet) {
    /*
     * Logic to perform the actual send of the packet using the tinyOS interfaces
     */

    pubsub_message_t * payload = (pubsub_message_t * ) call Packet.getPayload(packet, sizeof(pubsub_message_t));

    if (locked) {
      dbgerror("radio_send", "Radio is locked\n");
      return FALSE;
    }

    switch (payload -> messageType) {

    case CONNECT:
      if (call AMSend.send(address, packet, sizeof(pubsub_message_t)) == SUCCESS) {
        locked = TRUE;
        dbg("radio_send", "Node %hu Sent a CONNECT message to PANC\n", TOS_NODE_ID);
        return TRUE;
      } else {
        dbgerror("radio_send", "Node %hu Failed to send a CONNECT message to PANC\n", TOS_NODE_ID);
        return FALSE;
      }
      break;

    case CONNECT_ACK:
      if (call AMSend.send(address, packet, sizeof(pubsub_message_t)) == SUCCESS) {
        locked = TRUE;
        dbg("radio_send", "Node %hu Sent a CONNECT_ACK message to Node %hu\n", TOS_NODE_ID, address);
        return TRUE;
      } else {
        dbgerror("radio_send", "Node %hu Failed to send a CONNECT_ACK message to Node %hu\n", TOS_NODE_ID, address);
        return FALSE;
      }
      break;

    case SUBSCRIBE:
      if (call AMSend.send(address, packet, sizeof(pubsub_message_t)) == SUCCESS) {
        locked = TRUE;
        dbg("radio_send", "Node %hu Sent a SUBSCRIBE message to Node %hu\n", TOS_NODE_ID, address);
        return TRUE;
      } else {
        dbgerror("radio_send", "Node %hu Failed to send a SUBSCRIBE message to Node %hu\n", TOS_NODE_ID, address);
        return FALSE;
      }
      break;

    case SUBSCRIBE_ACK:
      if (call AMSend.send(address, packet, sizeof(pubsub_message_t)) == SUCCESS) {
        locked = TRUE;
        dbg("radio_send", "Node %hu Sent a SUBSCRIBE_ACK message to Node %hu\n", TOS_NODE_ID, address);
        return TRUE;
      } else {
        dbgerror("radio_send", "Node %hu Failed to send a SUBSCRIBE_ACK message to Node %hu\n", TOS_NODE_ID, address);
        return FALSE;
      }
      break;

    case PUBLISH:
      if (call AMSend.send(address, packet, sizeof(pubsub_message_t)) == SUCCESS) {
        locked = TRUE;
        dbg("radio_send", "Node %hu Sent a PUBLISH message to PANC\n", TOS_NODE_ID);
        return TRUE;
      } else {
        dbgerror("radio_send", "Node %hu Failed to send a PUBLISH message to PANC\n", TOS_NODE_ID);
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
    // Radio startup done
    if (err == SUCCESS) {
      dbg("radio", "Radio started.\n");
      // Start the timer after the radio has started up successfully
      // start the timer if not PANC
      if (TOS_NODE_ID != 1) {
        call Timer1.startPeriodic(RETRANSMISSION_TIMEOUT);
      } else {
        // Initialize the CommunicationNetwork
        initializeCommunicationNetwork( & networkTable);
        call Timer4.startPeriodic(TRANSMIT_INTERVAL);
      }
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
      pubsub_message_t * payload = (pubsub_message_t * ) call Packet.getPayload( & packet, sizeof(pubsub_message_t));
      if (payload == NULL) {
        // Failed to obtain payload pointer
        dbgerror("radio_pack", "Failed to obtain payload\n");
      } else {
        payload -> messageType = CONNECT;
        payload -> nodeID = TOS_NODE_ID;

        // Generate and schedule the message transmission
        if (!generate_send(1, & packet, payload -> messageType)) {
          // Failed to schedule the message transmission, handle the error
          dbgerror("radio_send", "Failed to schedule message transmission\n");
        } else {
          dbg("radio_send", "Node %hu Scheduled a CONNECT message to PANC\n", TOS_NODE_ID);
        }
      }
    }

  }

  event void Timer2.fired(){
    /*
     * Logic to trigger the Nodes to send SUBSCRIBE packets
     */

    dbg("timer", "Timer2 fired.\n");
    if (TOS_NODE_ID != 1) {
      pubsub_message_t * payload = (pubsub_message_t * ) call Packet.getPayload( & packet, sizeof(pubsub_message_t));
      if (payload == NULL) {
        // Failed to obtain payload pointer
        dbgerror("radio_pack", "Failed to obtain payload\n");
      } else {
        payload -> messageType = SUBSCRIBE;
        payload -> nodeID = TOS_NODE_ID;
        payload -> subTopic.temperature = clientInterest[TOS_NODE_ID - 2][0];
        payload -> subTopic.humidity = clientInterest[TOS_NODE_ID - 2][1];
        payload -> subTopic.luminosity = clientInterest[TOS_NODE_ID - 2][2];

        // Generate and schedule the message transmission
        if (!generate_send(1, & packet, payload -> messageType)) {
          // Failed to schedule the message transmission, handle the error
          dbgerror("radio_send", "Failed to schedule message transmission\n");
        } else {
          dbg("radio_send", "Node %hu Scheduled a SUBSCRIBE message to PANC\n", TOS_NODE_ID);
        }
      }
    }
  }

  event void Timer3.fired(){
    /*
     * Logic to trigger the Nodes to send PUBLISH packets
     */

    dbg("timer", "Timer3 fired.\n");
    if (TOS_NODE_ID != 1) {
      pubsub_message_t * payload = (pubsub_message_t * ) call Packet.getPayload( & packet, sizeof(pubsub_message_t));
      if (payload == NULL) {
        // Failed to obtain payload pointer
        dbgerror("radio_pack", "Failed to obtain payload\n");
      } else {
        payload -> messageType = PUBLISH;
        payload -> nodeID = TOS_NODE_ID;
        payload -> pubTopic = publishTopic[TOS_NODE_ID - 2];
        
        switch (payload -> pubTopic) {
          case TEMPERATURE:
            payload -> payloadData = generateRandomTemperature();
            break;

          case HUMIDITY:
            payload -> payloadData = generateRandomHumidity();
            break;

          case LUMINOSITY:
            payload -> payloadData = generateRandomLuminosity();
            break;
        }

        // Generate and schedule the message transmission
        if (!generate_send(1, & packet, payload -> messageType)) {
          // Failed to schedule the message transmission, handle the error
          dbgerror("radio_send", "Failed to schedule message transmission\n");
        } else {
          dbg("radio_send", "Node %hu Scheduled a PUBLISH message to PANC with pubTopic %hu and payload %hu\n", TOS_NODE_ID, payload -> pubTopic, payload -> payloadData);
        }
      }
    }
  }

  event void Timer4.fired(){

    /*
     * Logic to send transmitBuffer to NodeRed via UDP
     */

      uint8_t i; // loop counter
      char str[100]; // string to send

      // loop through the buffer and send the data
      for ( i = 0; i < bufferIndex; i++) {

            //first it crates UDP socket to transmit data
            if ((sock = socket(AF_INET, SOCK_DGRAM, 0)) == -1) {
              
            dbg("node_red", "Socket error.\n");

          } else{

            // Convert the data to string            
            snprintf(str, 100, "%d %d %d %s", transmitBuffer[i].pubTopic, transmitBuffer[i].payloadData, transmitBuffer[i].nodeId, transmitBuffer[i].simTime);
              
            nodered_server.sin_family = AF_INET;
            nodered_server.sin_port = htons(3030);
            nodered_server.sin_addr.s_addr = inet_addr("127.0.0.1");
              
            //send message to nodered
            if (sendto(sock, str, strlen(str), 0, (struct sockaddr *)&nodered_server, sizeof(struct sockaddr)) < 0) {
            dbg("node_red", "FAILED to send message to node RED!\n");
            break;
            } else {
            dbg("node_red", "Sent packet %hu to NodeRed: %s\n", i, str);
            }
            // Close the socket
            close(sock);
           }
        
      }
      // reset the buffer index
      bufferIndex = 0;

  }

  event message_t * Receive.receive(message_t * bufPtr, void * payload, uint8_t len) {
    /*
     * Parse the receive packet.
     * Implement all the functionalities
     * Perform the packet send using the generate_send function if needed
     */

    if (len != sizeof(pubsub_message_t)) {
      return bufPtr;
    } else {
      pubsub_message_t * receivedMsg = (pubsub_message_t * ) payload;

      switch (receivedMsg -> messageType) {

      case CONNECT:
        dbg("radio_rec", "Received a CONNECT message from node %hu at time %s\n", receivedMsg -> nodeID, sim_time_string());
        if (TOS_NODE_ID == 1) {
          // If the node is the PAN Coordinator, send a CONNECT_ACK message
          pubsub_message_t * payload = (pubsub_message_t * ) call Packet.getPayload( & packet, sizeof(pubsub_message_t));
          if (payload == NULL) {
            // Failed to obtain payload pointer
            dbgerror("radio_pack", "Failed to obtain payload\n");
          } else {
            uint16_t address = receivedMsg -> nodeID;

            // check if node is connected
            if (isConnected( & networkTable, address)) {
              dbg("radio_rec", "Node %hu is already connected to PANC\n", address);
            } else {
              // add node to the list of connected nodes
              if (addConnection( & networkTable, address)) {
                dbg("radio_rec", "Node %hu added to the list of connected nodes\n", address);
              }
            }

            payload -> messageType = CONNECT_ACK;
            payload -> nodeID = TOS_NODE_ID;

            // Generate and schedule the message transmission
            if (!generate_send(address, & packet, payload -> messageType)) {
              // Failed to schedule the message transmission, handle the error
              dbgerror("radio_send", "Failed to schedule message transmission\n");
            } else {
              dbg("radio_send", "Node %hu Scheduled a CONNECT_ACK message to node %hu\n", TOS_NODE_ID, receivedMsg -> nodeID);
            }
          }
        }
        break;

      case CONNECT_ACK:
        dbg("radio_rec", "Received a CONNECT_ACK message from node %hu at time %s\n", receivedMsg -> nodeID, sim_time_string());
        if (TOS_NODE_ID != 1 && call Timer1.isRunning()) {

          if (call Timer1.isRunning()) {
            call Timer1.stop();
            dbg("timer", "Timer1 stopped.\n");
          }

          call Timer2.startPeriodic(RETRANSMISSION_TIMEOUT);
          dbg("timer", "Timer2 started.\n");
        }
        break;

      case SUBSCRIBE:
        dbg("radio_rec", "Received a SUBSCRIBE message from node %hu at time %s\n", receivedMsg -> nodeID, sim_time_string());
        if (TOS_NODE_ID == 1) {
          // If the node is the PAN Coordinator, send a SUBSCRIBE_ACK message
          pubsub_message_t * payload = (pubsub_message_t * ) call Packet.getPayload( & packet, sizeof(pubsub_message_t));
          if (payload == NULL) {
            // Failed to obtain payload pointer
            dbgerror("radio_pack", "Failed to obtain payload\n");
          } else {
            uint16_t address = receivedMsg -> nodeID;
            bool temperature = receivedMsg -> subTopic.temperature;
            bool humidity = receivedMsg -> subTopic.humidity;
            bool luminosity = receivedMsg -> subTopic.luminosity;

            payload -> messageType = SUBSCRIBE_ACK;
            payload -> nodeID = TOS_NODE_ID;

            // check if node is connected
            if (isConnected( & networkTable, address)) {

            if(temperature && !isSubscribed( & networkTable, address, TEMPERATURE)) {
              subscribe( & networkTable, address, TEMPERATURE);
              dbg("radio_rec", "Node %hu added to the list of subscribed nodes for TEMPERATURE\n", address);
              
            }
            
            if(humidity && !isSubscribed( & networkTable, address, HUMIDITY)) {
              subscribe( & networkTable, address, HUMIDITY);
              dbg("radio_rec", "Node %hu added to the list of subscribed nodes for HUMIDITY\n", address);
              
            }

            if(luminosity && !isSubscribed( & networkTable, address, LUMINOSITY)) {
              subscribe( & networkTable, address, LUMINOSITY);
              dbg("radio_rec", "Node %hu added to the list of subscribed nodes for LUMINOSITY\n", address);
            
            }
            
            
            // Generate and schedule the message transmission
            if (!generate_send(address, & packet, payload -> messageType)) {
              // Failed to schedule the message transmission, handle the error
              dbgerror("radio_send", "Failed to schedule message transmission\n");
            } else {
              dbg("radio_send", "Node %hu Scheduled a SUBSCRIBE_ACK message to node %hu\n", TOS_NODE_ID, receivedMsg -> nodeID);
            }

            }

          }
        }
        break;

      case SUBSCRIBE_ACK:
        dbg("radio_rec", "Received a SUBSCRIBE_ACK message from node %hu at time %s\n", receivedMsg -> nodeID, sim_time_string());
        if (TOS_NODE_ID != 1) {
          
          if (call Timer2.isRunning()) {
            call Timer2.stop();
            dbg("timer", "Timer2 stopped.\n");
          }

          call Timer3.startPeriodic(PUBLISH_INTERVAL);

        }
        break;

      case PUBLISH:
      if(TOS_NODE_ID == 1){          
        // If the node is the PAN Coordinator, forward PUBLISH to all nodes
          pubsub_message_t * payload = (pubsub_message_t * ) call Packet.getPayload( & packet, sizeof(pubsub_message_t));
          if (payload == NULL) {
            // Failed to obtain payload pointer
            dbgerror("radio_pack", "Failed to obtain payload\n");
          } else{

            uint8_t address = receivedMsg -> nodeID;
            uint8_t pubTopic = receivedMsg -> pubTopic;
            uint8_t payloadData = receivedMsg -> payloadData;
            uint8_t i;

            dbg("radio_rec", "Panc received a PUBLISH message from node %hu at time %s\n", receivedMsg -> nodeID, sim_time_string());

            // add message to buffer to be transmitted to Node-RED when Timer4 expires
            if(bufferIndex < MAX_QUEUE_SIZE){
              transmitBuffer[bufferIndex].pubTopic = pubTopic;
              transmitBuffer[bufferIndex].payloadData = payloadData;
              transmitBuffer[bufferIndex].nodeId = address;
              sprintf(transmitBuffer[bufferIndex].simTime, "%s", sim_time_string());
              bufferIndex++;
            } else {
              dbgerror("node_red", "Buffer is full\n");
            }

            for( i = 0; i < MAX_CLIENTS + 2; i++){
              if(isConnected(&networkTable, i) && isSubscribed(&networkTable, i, pubTopic) && i != address){
                payload -> messageType = PUBLISH;
                payload -> nodeID = address;
                payload -> pubTopic = pubTopic;
                payload -> subTopic = receivedMsg -> subTopic;
                payload -> payloadData = receivedMsg -> payloadData;

                if (!generate_send(i, & packet, payload -> messageType)) {
                  // Failed to schedule the message transmission, handle the error
                  dbgerror("radio_send", "Failed to schedule message transmission\n");
                } else {
                  dbg("radio_send", "Node %hu Scheduled a PUBLISH message to node %hu\n", TOS_NODE_ID, i);
                }
              }
            }
          }
      } else{
        // Node received a PUBLISH message from the PAN Coordinator
        dbg("radio_rec", "Received a PUBLISH message from node %hu at time %s\n", receivedMsg -> nodeID, sim_time_string());
      }
        break;

      default:
        dbgerror("radio_rec", "Received an invalid message type\n");
        break;

      }

      return bufPtr;

    }
  }

  event void AMSend.sendDone(message_t * bufPtr, error_t error) {
    /* This event is triggered when a message is sent 
     *  Check if the packet is sent 
     */
    uint16_t i;

    if (error == SUCCESS) {

      // Unlocked the radio
      locked = FALSE;

      dbg("radio_send", "Packet sent...");
      dbg_clear("radio_send", " at time %s \n", sim_time_string());

    } else {
      dbgerror("radio_send", "Send done error!\n");
    }

    if (queueSize > 0) {

      // Shift the queue to remove the sent message
      for (i = 0; i < queueSize - 1; i++) {
        messageQueue[i] = messageQueue[i + 1];
        addressQueue[i] = addressQueue[i + 1];
      }

      queueSize--;

      // send the next message in the queue

      if (queueSize > 0) {
        call Timer0.startOneShot(generateRandomDelay(MIN_DELAY, MAX_DELAY));
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