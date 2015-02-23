#include "../test_config.h"

/* The full package of TeaCP application layer component
 *
 * It includes the necessary TinyOS components including timers, radio
 * module, UART module, etc. The collection protocol used here is CTP,
 * i.e., CollectionC. To test another collection protocol, you can include
 * the component of the new protocol.
 */

configuration PacketAppConfigC {}

implementation
{
  // The TeaCP application layer component
  components PacketAppModuleC as App;

  // Standard modules
  components MainC, LedsC;
  components new TimerMilliC();
  components LocalTimeMilliC;

  App.Boot         -> MainC;
  App.Leds         -> LedsC;
  App.PacketTimer  -> TimerMilliC;
  App.LocalClock   -> LocalTimeMilliC;

  // The radio modules
  components ActiveMessageC, CC2420ControlC;

  App.RadioControl    -> ActiveMessageC;
  App.CC2420Config    -> CC2420ControlC;
  App.CentralReceiver -> ActiveMessageC.Receive[AM_CENTRAL_START];

  // The I/O pin module of MSP430
  // Connect the interface to the pin wired to Arduino
  components HplMsp430GeneralIOC as MspGeneralIO;

  App.ArduinoBusySignal -> MspGeneralIO.Port26;
  
  // The UART communication modules
  components SerialActiveMessageC;
  components new SerialAMSenderC(AM_UART);
  
  App.UARTPacket    -> SerialActiveMessageC;
  App.UARTAMSend    -> SerialAMSenderC;
  App.UARTAMControl -> SerialActiveMessageC;

  // The collection protocol modules
  components CollectionC as Collector;
  components new CollectionSenderC(AM_COLLECTION);

  App.RoutingControl   -> Collector;
  App.RootControl      -> Collector;
  App.RoutingSend      -> CollectionSenderC;
  App.RoutingReceive   -> Collector.Receive[AM_COLLECTION];
  App.RoutingIntercept -> Collector.Intercept[AM_COLLECTION];

  // The random number generating modules
  components RandomC;
  components new exponentialRandomC(1000);

  App.RandomStart     -> RandomC;
  App.RandomStartSeed -> RandomC;
  App.ExpRandom       -> exponentialRandomC;
  App.SetExpMean      -> exponentialRandomC;
}
