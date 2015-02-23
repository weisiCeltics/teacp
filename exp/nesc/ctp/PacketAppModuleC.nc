#include <Timer.h>

#include "../message_formats.h"
#include "../test_config.h"


/* The implementaion of TeaCP application layer component
 * 
 * The packet application receives the broadcast message from the
 * activator, which contains the test configurations including
 * packet generation interval, radio power and radio channel. Then
 * the application starts to periodically generate data messages and
 * transfer them to the underlying collection protocol. The application
 * is also responsible for generating log messages about network 
 * events, i.e., when packets are generated or received.
 *
 * The LEDs are used to indicate different events:
 * led0 -- generate a data message
 * led1 -- receive a packet from the collection protocol
 * led2 -- succeed in transmitting a log message on UART
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
  uses interface CC2420Config;

  // The interface for accessing the busy signal of Arduino
  uses interface HplMsp430GeneralIO as ArduinoBusySignal;
  
  // The interface for receiving the broadcast message from the activator
  uses interface Receive as CentralReceiver;

  // The interfaces with the collection protocol
  uses interface StdControl as RoutingControl;
  uses interface RootControl;
  uses interface Send       as RoutingSend;
  uses interface Receive    as RoutingReceive;
  uses interface Intercept  as RoutingIntercept;

  // The interfaces with the UART communication module
  uses interface SplitControl as UARTAMControl;
  uses interface Packet       as UARTPacket;
  uses interface AMSend       as UARTAMSend;

  // The interfaces to random number generator
  uses interface Random                  as ExpRandom;
  uses interface Set<uint32_t>           as SetExpMean;
  uses interface Random                  as RandomStart;
  uses interface ParameterInit<uint16_t> as RandomStartSeed;
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

  // The TinyOS message buffer for passing log messages to the UART transmitter
  message_t uart_pkt;

  // The queue storing the log messages waiting to be transmitted 
  // on UART
  log_message_t uart_queue[UART_QUEUE_LEN];
  uint8_t queue_head = 0;      // Pointer to the head of uart_queue
  uint8_t queue_tail = 0;      // Pointer to the tail of uart_queue
  bool    uart_busy  = FALSE;  // Indicator of whether the UART is busy transmitting log messages
  bool    uart_full  = FALSE;  // Indicator of whether uart_queue is full


  // Forward declaration of tasks and functions
  task void uartSendTask();
  void generateDataMsg();
  void generateLogMsg(data_message_t * data_msg, 
                      nx_uint8_t event_type, 
                      nx_uint32_t event_time);



  /* System initialization
   */
  event void Boot.booted()
  {
    call RadioControl.start();  // Initialize the radio component
    call UARTAMControl.start(); // Initialize the UART component

    // Configure the pin connected to the Arduino board
    call ArduinoBusySignal.selectIOFunc();
    call ArduinoBusySignal.makeInput();

    call SetExpMean.set(packet_interval);
    call RandomStartSeed.init(TOS_NODE_ID + RNG_SEED);
  }

  event void RadioControl.startDone(error_t err) 
  {
    if (err != SUCCESS)
      call RadioControl.start();
  }

  event void RadioControl.stopDone(error_t err) {}

  event void UARTAMControl.startDone(error_t err)
  {
    if (err != SUCCESS)
      call UARTAMControl.start();
  }

  event void UARTAMControl.stopDone(error_t err) {}


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


  /* The sensor node receives the broadcast message from the activator, which
   * contains the test configurations, including the packe generation interval,
   * radio power and radio channel.
   */
  event message_t * CentralReceiver.receive(message_t * msg, void * payload, uint8_t len)
  {
    if (len == sizeof(sync_message_t))
    {
      sync_message_t * sync_msg = (sync_message_t *) payload;

      if (sync_msg -> node_id == TOS_NODE_ID || sync_msg -> node_id == ALL_NODES)
      {              
        switch (sync_msg -> cmd)
        {
          case START:
            if (application_started == FALSE)
            {
              clock_compensation = call LocalClock.get();
              packet_interval = sync_msg -> packet_interval;
              radio_power     = sync_msg -> radio_power;
              radio_channel   = sync_msg -> radio_channel;

              call CC2420Config.setChannel(radio_channel);
              call CC2420Config.setTxPower(radio_power);
              call CC2420Config.sync();

              initRouting();
              application_started = TRUE;
          
              //generateLogMsg(sync_msg 10, clock_compensation);
            }
            break;

          case PAUSE: 
            break;

          case RESET:
            WDTCTL = 0;
            while(1);
        }
      }
    }

    return msg;
  }
  
  event void CC2420Config.syncDone( error_t error ) {}



  /* The procedure of generating data messages and transferring them to the
   * underlying collection protocol.
   */
  void generateDataMsg()
  {
    data_message_t * data_msg = (data_message_t *) call RoutingSend.getPayload(&packet, sizeof(data_message_t));

    uint32_t time = call LocalClock.get();
    time -= clock_compensation;

    data_msg -> src_node_id  = TOS_NODE_ID;
    data_msg -> last_node_id = TOS_NODE_ID;
    data_msg -> packet_id    = packet_counter++;
    data_msg -> hop_count    = 0;
    
    generateLogMsg(data_msg, 0, time);

    call CC2420Config.setTxPower(radio_power);

    call Leds.led0Toggle();

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

    uint32_t time = call LocalClock.get();
    time -= clock_compensation;

    data_msg -> hop_count += 1;
    
    generateLogMsg(data_msg, 2, time);

    call CC2420Config.setTxPower(radio_power);

    call Leds.led1Toggle();

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

    uint32_t time = call LocalClock.get();
    time -= clock_compensation;

    data_msg -> hop_count += 1;
    generateLogMsg(data_msg, 1, time);
    data_msg -> last_node_id = TOS_NODE_ID;

    call CC2420Config.setTxPower(radio_power);

    call Leds.led1Toggle();

    return TRUE;
  }


  /* The procedure of generating log messages. Each log message records the type and time
   * of the network event and contains the information of the corresponding data message.
   */
  void generateLogMsg (data_message_t * data_msg, nx_uint8_t event_type, nx_uint32_t event_time)
  {
    atomic 
    {
      if (!uart_full)
      {
        uart_queue[queue_tail].type         = event_type;
        uart_queue[queue_tail].cur_node_id  = TOS_NODE_ID;
        uart_queue[queue_tail].src_node_id  = data_msg -> src_node_id;
        uart_queue[queue_tail].last_node_id = data_msg -> last_node_id;
        uart_queue[queue_tail].packet_id    = data_msg -> packet_id;
        uart_queue[queue_tail].time         = event_time;
        uart_queue[queue_tail].hop_count    = data_msg -> hop_count;
     
        queue_tail ++;
        queue_tail = queue_tail % UART_QUEUE_LEN;

        if (queue_tail == queue_head)
        {
          uart_full = TRUE;
        }

        if (!uart_busy)
        {
          post uartSendTask(); // Posting uartSendTask() into the task queue of OS
          uart_busy = TRUE;
        }
      }
    }
  }


  /* The task of transimitting a log message from the uart_queue on UART
   */
  task void uartSendTask()
  {
    log_message_t * log_msg = (log_message_t *) (call UARTPacket.getPayload(&uart_pkt, sizeof(log_message_t)));

    Arduino_busy = call ArduinoBusySignal.get();

    if (queue_tail == queue_head && !uart_full)
    {
      uart_busy = FALSE;
      return;
    }

    if ((uart_busy && log_msg == NULL) || Arduino_busy)
      return;
    
    log_msg -> type         = uart_queue[queue_head].type;
    log_msg -> cur_node_id  = uart_queue[queue_head].cur_node_id;
    log_msg -> src_node_id  = uart_queue[queue_head].src_node_id;
    log_msg -> last_node_id = uart_queue[queue_head].last_node_id;
    log_msg -> packet_id    = uart_queue[queue_head].packet_id;
    log_msg -> time         = uart_queue[queue_head].time;
    log_msg -> hop_count    = uart_queue[queue_head].hop_count;
    
    if (call UARTAMSend.send(AM_BROADCAST_ADDR, &uart_pkt, sizeof(log_message_t)) == SUCCESS)
    {
      call Leds.led2Toggle();
      uart_busy = TRUE;
    }
    else
      post uartSendTask();
  }

  
  /* When the transmission of a log message on UART finishes
   */
  event void UARTAMSend.sendDone(message_t * msg, error_t err)
  {
    atomic
    {
      queue_head ++;

      if (queue_head >= UART_QUEUE_LEN) 
        queue_head = 0;

      if (uart_full) 
        uart_full = FALSE;

      uart_busy = FALSE;
    }

    post uartSendTask();
  }

} // end of implementation
