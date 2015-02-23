#include <Timer.h>

#include "../message_formats.h"
#include "../test_config.h"


/* The implementaion of TeaCP application layer component
 * 
 * The simulation version of TeaCP application layer component is simplified version
 * of the experiment version. Instead of receiving the broadcast message from the 
 * activator and starting the application, the simulation-version component starts
 * generating packets as soon as the radio module is initialized. Instead of outputing
 * log message through UART, the component writes all log messages into a single file
 * through the function dbg(<channel name>, <string>).
 */

module PacketAppModuleC
{
  // The standard interfaces including boot, timers, Leds.
  uses interface Boot;
  uses interface Timer<TMilli>     as PacketTimer;
  uses interface LocalTime<TMilli> as LocalClock;
  uses interface Leds;

  // The interfaces to access radio modules
  uses interface SplitControl as RadioControl;

  // The interfaces with the collection protocol
  uses interface StdControl as RoutingControl;
  uses interface RootControl;
  uses interface Send       as RoutingSend;
  uses interface Receive    as RoutingReceive;
  uses interface Intercept  as RoutingIntercept;

  // The interfaces to random number generator
  uses interface Random                  as ExpRandom;
  uses interface Set<uint32_t>           as SetExpMean;
  uses interface Random                  as RandomStart;
  uses interface ParameterInit<uint16_t> as RandomStartSeed;

  // BCP uses this interface to send back debug information 
  provides interface BcpDebugIF;
}


implementation // Beginning of implementation
{
  // The TinyOS message buffer for passing data messages to the collection protocol
  message_t packet;

  // Indicator of whether the collection protocol is busy handling
  // the transferred packet.
  bool routing_busy = FALSE;

  // Indicator of whether the Arduino board is busy receiving the
  // UART messages.
  bool Arduino_busy = FALSE;

  // Indicator of whether the application has started generating 
  // data messages.
  bool application_started = FALSE;

  // Indicating whether the packet timer has started running
  // Used for randomizing the first packet generation interval
  bool timer_started = FALSE;

  // The counter of how many packets have been generated.
  // Used for assigning packet_id to data messages.
  uint32_t packet_counter = 0;

  // Used for recording the initial value of LocalClock
  uint32_t clock_compensation = 0;

  // Record the configured parameters 
  uint32_t packet_interval;  // packet generation interval in ms
  uint8_t  radio_power;      // radio power
  uint8_t  radio_channel;    // IEEE 802.15.4 channel: 11 - 26


  // Forward declaration of tasks and functions
  void initRouting();
  void generateDataMsg();
  void generateLogMsg(data_message_t * data_msg, 
                      nx_uint8_t event_type, 
                      nx_uint32_t event_time);



  /* System initialization
   */
  event void Boot.booted()
  {
    call RadioControl.start();  // Initialize the radio component

    packet_interval = PACKET_INTERVAL; // Using the parameter in
                                       // test_config.h
    call SetExpMean.set(packet_interval);
    call RandomStartSeed.init(TOS_NODE_ID + RNG_SEED);
  }

  event void RadioControl.startDone(error_t err) 
  {
    if (err != SUCCESS)
      call RadioControl.start();
    else
      initRouting(); // After the radio module is initialized, start
                     // generating packets and running the collection
                     // protocol.
  }

  event void RadioControl.stopDone(error_t err) {}


  /* Start the collection protocol. All the sensor nodes except the 
   * root node also start the packet timer, which triggers packet
   * generation after the configured packet_interval.
   */
  void initRouting()
  {
    call RoutingControl.start(); // Initialize the collection protocol
    
    if (TOS_NODE_ID == 0)
      call RootControl.setRoot();
    else
    {
      call PacketTimer.startOneShot(packet_interval + 
              (call RandomStart.rand16() * INITIAL_INTERVAL / 65536)); 
    }
  }

  event void PacketTimer.fired()
  {
    #ifdef EXPONENTIAL_TIMER

    packet_interval = call ExpRandom.rand32();
    call PacketTimer.startOneShot(packet_interval);

    #else

    if (timer_started == FALSE)
    {
      call PacketTimer.startPeriodic(packet_interval);
      timer_started = TRUE;
    }

    #endif

    generateDataMsg();
  }


  /* The procedure of generating data messages and transferring them to the
   * underlying collection protocol.
   */
  void generateDataMsg()
  {
    data_message_t * data_msg = (data_message_t *) call RoutingSend.getPayload(&packet, sizeof(data_message_t));

    uint32_t event_time = call LocalClock.get();
    event_time -= clock_compensation;

    data_msg -> src_node_id  = TOS_NODE_ID;
    data_msg -> last_node_id = TOS_NODE_ID;
    data_msg -> packet_id    = packet_counter++;
    data_msg -> hop_count    = 0;
    
    generateLogMsg(data_msg, 0, event_time);

    if (!routing_busy)
    {
      // Transferring the data message to the collection protocol
      if (call RoutingSend.send(&packet, sizeof(data_message_t)) == SUCCESS)
      {
        routing_busy = TRUE;
      }
    }
  }

  event void RoutingSend.sendDone(message_t * m, error_t err)
  {
    if (err != SUCCESS)
    {
    }

    routing_busy = FALSE;
  }


  /* The handler of received packets (the node is the root node) 
   *
   * The handler is called when the underlying collection protocol notifies the 
   * node that a packet has been received/delivered. Note that this event can 
   * happen only when this node is the root node.
   */
  event message_t * RoutingReceive.receive(message_t * msg, void * payload, uint8_t len) 
  {
    data_message_t * data_msg = (data_message_t *) payload; 

    uint32_t event_time = call LocalClock.get();
    event_time -= clock_compensation;

    data_msg -> hop_count += 1;
    
    generateLogMsg(data_msg, 2, event_time);

    return msg;
  }


  /* The handler of received packets (the node is an intermediate node) 
   *
   * The handler is called when the underlying collection protocol notifies the 
   * node that a packet has been received and needs to be forwarded to the next
   * hop. Note that this event can happen only when this nodes is an intermediate
   * node.
   */
  event bool RoutingIntercept.forward(message_t * msg, void * payload, uint8_t len)
  {
    data_message_t * data_msg = (data_message_t *) payload;

    uint32_t event_time = call LocalClock.get();
    event_time -= clock_compensation;

    data_msg -> hop_count += 1;
    generateLogMsg(data_msg, 1, event_time);
    data_msg -> last_node_id = TOS_NODE_ID;

    call Leds.led1Toggle();

    return TRUE;
  }


  /* The procedure of generating log messages. Each log message records the type and time
   * of the network event and contains the information of the corresponding data message.
   */
  void generateLogMsg (data_message_t * data_msg, nx_uint8_t event_type, nx_uint32_t event_time)
  {
    // To mimic the format of log_message_t
    dbg("TeacpApp", "%d,%d,%d,%d,%ld,%ld,%d\n", 
        event_type, TOS_NODE_ID, data_msg -> src_node_id, data_msg -> last_node_id, 
        data_msg -> packet_id, event_time, data_msg -> hop_count);
  }


  /* The following are the commands of the BcpDebugIF interface. This interface
   * is used by BCP to send back debug information such as backpressure information
   * of nodes and parameters in the routing table. Currently, we do not use
   * these information for post-expriment analysis.
   */

  /* Notifies upper layer of a change to the local
   *  backpressure level.
   */
	command void BcpDebugIF.reportBackpressure(uint32_t dataQueueSize_p, uint32_t virtualQueueSize_p, 
                                             uint16_t localTXCount_p, uint8_t origin_p, 
                                             uint8_t originSeqNo_p, uint8_t reportSource_p) {}

  /* Notifies the application layer of an error
   */
	command void BcpDebugIF.reportError( uint8_t type_p ) {}

  /* Notifies upper layer of an update to the estimated link transmission time
   */
	command void BcpDebugIF.reportLinkRate(uint8_t neighbor_p, uint16_t previousLinkPacketTxTime_p, 
                                         uint16_t updateLinkPacketTxTime_p, uint16_t newLinkPacketTxTime,
                                         uint16_t latestLinkPacktLossEst) {}

  /* Used to debug
   */
	command void BcpDebugIF.reportValues(uint32_t field1_p, uint32_t field2_p, uint32_t field3_p, 
                                       uint16_t field4_p, uint16_t field5_p, uint16_t field6_p, 
                                       uint8_t field7_p, uint8_t field8_p) {}
} // end of implementation
