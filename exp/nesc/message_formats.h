#ifndef MESSAGE_FORMATS_H
#define MESSAGE_FORMATS_H


/* The data message, carried as packet payload in the collection protocol
 */
typedef nx_struct data_message_t 
{
  nx_uint8_t  src_node_id;  // The source node generating this packet
  nx_uint8_t  last_node_id; // The node transmitting the packet most recently
  nx_uint32_t packet_id;    // Node-unique packet sequence number
  nx_uint8_t  hop_count;    // Number of hops this packet has experienced
} 
data_message_t;

/* The log message
 */
typedef nx_struct log_message_t 
{
  nx_uint8_t  type;         // 0 -- packet generation
                            // 1 -- packet reception by sensor nodes
                            // 2 -- packet reception by the root node
  nx_uint8_t  cur_node_id;  // The node generating this log message
  nx_uint8_t  src_node_id;  // Same as data_message_t
  nx_uint8_t  last_node_id; // Same as data_message_t
  nx_uint32_t packet_id;    // Same as data_message_t
  nx_uint32_t time;         // Time of the event
  nx_uint8_t  hop_count;    // Same as data_message_t
} 
log_message_t;

/* The sync message, containing the test configurations, is used by
 * the activator to send in a broadcast message to the network.
 */
typedef nx_struct sync_message 
{
  nx_uint8_t  node_id;         // The node that should apply the configuration
  nx_uint8_t  cmd;             // commands: START, PAUSE, RESET
  nx_uint32_t packet_interval; // Packet generation interval in ms
  nx_uint8_t  radio_power;     // Radio power
  nx_uint8_t  radio_channel;   // IEEE 802.15.4 channel: 11 - 26
} 
sync_message_t;

#endif
