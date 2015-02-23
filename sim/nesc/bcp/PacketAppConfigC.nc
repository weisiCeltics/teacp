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

  // The collection protocol modules
  components BcpC as Collector;

  App.RoutingControl   -> Collector;
  App.RootControl      -> Collector;
  App.RoutingSend      -> Collector;
  App.RoutingReceive   -> Collector;
  App.RoutingIntercept -> Collector;
  App.BcpDebugIF       <- Collector;

  // The random number generating modules
  components RandomC;
  components new exponentialRandomC(1000);

  App.RandomStart     -> RandomC;
  App.RandomStartSeed -> RandomC;
  App.ExpRandom       -> exponentialRandomC;
  App.SetExpMean      -> exponentialRandomC;
}
