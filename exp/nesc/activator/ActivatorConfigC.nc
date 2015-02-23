#include <UserButton.h>

#include "../test_config.h"

/* The full package of the activator
 *
 * It configured the required modules for the activator including
 * the standard modules, radio modules and the user button module.
 */

configuration ActivatorConfigC {}

implementation
{
  // The activator module 
  components ActivatorModuleC as App;

  // Standard modules
  components MainC;
  components LedsC;
  components new TimerMilliC();

  App.Boot  -> MainC;
  App.Leds  -> LedsC;
  App.Timer -> TimerMilliC;
  
  // The radio modules
  components ActiveMessageC;
  components new AMSenderC(AM_CENTRAL_START);
  components CC2420ControlC;

  App.AMControl    -> ActiveMessageC;
  App.Packet       -> AMSenderC;
  App.AMSend       -> AMSenderC;
  App.CC2420Config -> CC2420ControlC;
  
  // The user button module
  components UserButtonC;

  App.ButtonNotify -> UserButtonC;

}
