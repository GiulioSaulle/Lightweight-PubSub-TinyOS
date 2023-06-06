# Lightweight-PubSub-TinyOS

This repository contains the implementation of a lightweight publish-subscribe application protocol similar to MQTT, designed and implemented in TinyOS. The protocol was developed as the final project for the IoT course at Politecnico di Milano, as part of a Master's degree in Computer Science and Engineering.

## Features

The following features have been implemented in the protocol:

1. **Connection**: Upon activation, each node sends a `CONNECT` message to the PAN coordinator. The PAN coordinator replies with a `CONNACK` message. Messages from nodes that are not yet connected are ignored. Retransmissions are handled if the `CONN` or `CONNACK` messages are lost.

2. **Subscribe**: After establishing a connection, each node can subscribe to one of three topics: `TEMPERATURE`, `HUMIDITY`, or `LUMINOSITY`. To subscribe, a node sends a `SUBSCRIBE` message to the PAN coordinator, including its node ID and the desired topics. The subscription message is acknowledged by the PAN coordinator with a `SUBACK` message. Retransmissions are handled if the `SUB` or `SUBACK` messages are lost.

3. **Publish**: Each node can publish data on one of the three topics. Publication is done using a `PUBLISH` message, which includes the topic name and payload. The protocol assumes that the QoS (Quality of Service) level for all publications is 0. When a node publishes a message on a topic, it is received by the PAN coordinator and forwarded to all nodes that have subscribed to that particular topic.

4. **Simulation**: The implementation can be tested in the TOSSIM simulation environment. It is recommended to simulate at least 3 nodes subscribing to more than one topic. The payload of `PUBLISH` messages on all topics can be a random number.

5. **Integration with Node-RED and Thingspeak**: The PAN Coordinator (Broker node) should be connected to Node-RED. It periodically transmits data received on the topics to Thingspeak through MQTT. Thingspeak should display one chart for each topic on a public channel.

## Getting Started

To get started with the project, follow these steps:

1. Clone the repository:

2. Set up the required dependencies and development environment.

3. Configure the PAN coordinator and client nodes according to your network topology.

4. Build and deploy the TinyOS application to the respective nodes.

5. Run the TOSSIM simulation environment and observe the behavior of the protocol.

6. Integrate the PAN coordinator with Node-RED and configure the periodic transmission to Thingspeak.

## License

[MIT License](LICENSE)

## Acknowledgments

- This project was developed as the final project for the IoT course at Politecnico di Milano.
