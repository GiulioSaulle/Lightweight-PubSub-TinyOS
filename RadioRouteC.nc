
/*
*	IMPORTANT:
*	The code will be avaluated based on:
*		Code design  
*
*/
 
 
#include "Timer.h"
#include "RadioRoute.h"


module RadioRouteC @safe() {
  uses {
  
    /****** INTERFACES *****/
	interface Boot;

    //interfaces for communication
	  //interface for timers
    //other interfaces, if needed
  }
}
implementation {

  message_t packet;
  
  // Variables to store the message to send
  message_t queued_packet;
  uint16_t queue_addr;
  uint16_t time_delays[7]={61,173,267,371,479,583,689}; //Time delay in milli seconds
  
  
  bool route_req_sent=FALSE;
  bool route_rep_sent=FALSE;
  
  
  bool locked;
  
  bool actual_send (uint16_t address, message_t* packet);
  bool generate_send (uint16_t address, message_t* packet, uint8_t type);
  
  void initializePANCoordinator(PANCoordinator* coordinator);
  bool isConnected(const PANCoordinator* coordinator, uint16_t nodeID);
  bool isSubscribed(const PANCoordinator* coordinator, uint16_t nodeID, uint8_t topic);
  void subscribe(PANCoordinator* coordinator, uint16_t nodeID, uint8_t topic);


  // Maximum number of connected clients
  #define MAX_CLIENTS 8

  // Maximum number of topics
  #define MAX_TOPICS 3

  typedef struct {
    uint16_t nodeID;                              // ID of the client node
    bool isConnected;                             // Connection status of the client
    bool isSubscribed[MAX_TOPICS];                // Subscription status for each topic
  } ClientInfo;

  typedef struct {
    ClientInfo clients[MAX_CLIENTS];              // Array of connected clients
  } PANCoordinator;

  
  
  bool generate_send (uint16_t address, message_t* packet, uint8_t type){
  /*
  * 
  * Function to be used when performing the send after the receive message event.
  * It store the packet and address into a global variable and start the timer execution to schedule the send.
  * It allow the sending of only one message for each REQ and REP type
  * @Input:
  *		address: packet destination address
  *		packet: full packet to be sent (Not only Payload)
  *		type: payload message type
  *
  * MANDATORY: DO NOT MODIFY THIS FUNCTION
  */
  	if (call Timer0.isRunning()){
  		return FALSE;
  	}else{
  	if (type == 1 && !route_req_sent ){
  		route_req_sent = TRUE;
  		call Timer0.startOneShot( time_delays[TOS_NODE_ID-1] );
  		queued_packet = *packet;
  		queue_addr = address;
  	}else if (type == 2 && !route_rep_sent){
  	  	route_rep_sent = TRUE;
  		call Timer0.startOneShot( time_delays[TOS_NODE_ID-1] );
  		queued_packet = *packet;
  		queue_addr = address;
  	}else if (type == 0){
  		call Timer0.startOneShot( time_delays[TOS_NODE_ID-1] );
  		queued_packet = *packet;
  		queue_addr = address;	
  	}
  	}
  	return TRUE;
  }
  
  event void Timer0.fired() {
  	/*
  	* Timer triggered to perform the send.
  	* MANDATORY: DO NOT MODIFY THIS FUNCTION
  	*/
  	actual_send (queue_addr, &queued_packet);
  }
  
  bool actual_send (uint16_t address, message_t* packet){
	/*
	* Implement here the logic to perform the actual send of the packet using the tinyOS interfaces
	*/
	  
  }
  
  
  event void Boot.booted() {
    dbg("boot","Application booted.\n");
    // Start the radio
    AMControl.start();
  }

  event void AMControl.startDone(error_t err) {
	/* Fill it ... */
  }

  event void AMControl.stopDone(error_t err) {
    /* Fill it ... */
  }
  
  event void Timer1.fired() {
	/*
	* Implement here the logic to trigger the Node 1 to send the first REQ packet
	*/
  }

  event message_t* Receive.receive(message_t* bufPtr, 
				   void* payload, uint8_t len) {
	/*
	* Parse the receive packet.
	* Implement all the functionalities
	* Perform the packet send using the generate_send function if needed
	*/
	
    
  }

  event void AMSend.sendDone(message_t* bufPtr, error_t error) {
	/* This event is triggered when a message is sent 
	*  Check if the packet is sent 
	*/ 
  }
}

void initializePANCoordinator(PANCoordinator* coordinator) {
  // Iterate over the clients array and initialize each client
  for (int i = 0; i < MAX_CLIENTS; i++) {
    coordinator->clients[i].nodeID = 0;                   // Initialize node ID to 0
    coordinator->clients[i].isConnected = false;          // Set isConnected to false
    for (int j = 0; j < MAX_TOPICS; j++) {
      coordinator->clients[i].isSubscribed[j] = false;    // Set all subscriptions to false
    }
  }
}

bool isConnected(const PANCoordinator* coordinator, uint16_t nodeID) {
  // Iterate over the clients array to find the node
  for (int i = 0; i < MAX_CLIENTS; i++) {
    if (coordinator->clients[i].nodeID == nodeID && coordinator->clients[i].isConnected) {
      // Node found and is connected
      return true;
    }
  }
  // Node not found or not connected
  return false;
}

bool isSubscribed(const PANCoordinator* coordinator, uint16_t nodeID, uint8_t topic) {
  // Iterate over the clients array to find the node
  for (int i = 0; i < MAX_CLIENTS; i++) {
    if (coordinator->clients[i].nodeID == nodeID && coordinator->clients[i].isConnected) {
      // Check if the node is subscribed to the topic
      return coordinator->clients[i].isSubscribed[topic];
    }
  }
  // Node not found or not connected
  return false;
}

void subscribe(PANCoordinator* coordinator, uint16_t nodeID, uint8_t topic) {
  // Iterate over the clients array to find the node
  for (int i = 0; i < MAX_CLIENTS; i++) {
    if (coordinator->clients[i].nodeID == nodeID && coordinator->clients[i].isConnected) {
      // Subscribe the node to the topic
      coordinator->clients[i].isSubscribed[topic] = true;
      break;
    }
  }
}
