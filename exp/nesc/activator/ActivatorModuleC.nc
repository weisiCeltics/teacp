#include <UserButton.h>

#include "../test_config.h"
#include "../message_formats.h"

/* The implemenation of the activator
 * 
 * After the user button is pressed, the activator sends out a message
 * containing the configured parameters in test_config.h. The activator
 * can also be used to reset the sensors in the network to terminate
 * an experiment.
 */

module ActivatorModuleC
{
  // Standard interfaces
  uses interface Boot;
  uses interface Leds;
  uses interface Timer<TMilli> as Timer;

  // The interfaces for accessing radio module
  uses interface SplitControl as AMControl;
  uses interface AMSend;
  uses interface Packet;
  uses interface CC2420Config;
  
  // The interface for receiving notification from the user button
  uses interface Notify<button_state_t> as ButtonNotify;
}

implementation  // Beginning of implementation
{
  // The TinyOS message buffer for passing data messages to radio module
  message_t packet;

  // The indicator of whether the radio is busying transmitting a message
  bool send_busy = FALSE;

  // A counter of how many times that the timer has expired 
  uint8_t timer_count = 0;
  
  // A counter of how many times that the user button has been pressed
  uint8_t button_press_count = 0;
  

  /* System initialization
   */
  event void Boot.booted() 
  {
    call AMControl.start();     // Start the radio module
    call ButtonNotify.enable(); // Enable the button notification
  }

  event void AMControl.startDone(error_t err) 
  {
    if (err == SUCCESS) 
    {
      call CC2420Config.setChannel(CC2420_DEF_CHANNEL);
		  call CC2420Config.sync(); 
    }
    else 
    {
      call AMControl.start();
    }
  }

  event void AMControl.stopDone(error_t err) {}

  event void CC2420Config.syncDone( error_t error ) {}
  

  /* When the user presses the button, the one-second timer is started.
   * After three seconds, the activator loads the parameters in test_config.h
   * into the sync message and sends it out via broadcast. When the button 
   * has been pressed more than five times, the activator sends out a message
   * to tell the network to reset. This can be used to terminate an experiment.
   */
  event void ButtonNotify.notify( button_state_t state ) 
  {
    sync_message_t * sync_msg;
	
	  if(state == BUTTON_PRESSED)
    {
		  call Leds.led0Toggle();
    	
    	button_press_count ++;

      if (button_press_count == 1)
      {
        call Timer.startPeriodic(1000); // Start the timer which fires every one second
      }
    	
    	if (button_press_count == 5)
      {
        // Switch to the configured radio channel to broadcast the reset command
      	call CC2420Config.setChannel(RADIO_CHANNEL);
		    call CC2420Config.sync();    	
    	}
    	
      // Tell the network to reset when the button has been pressed for more than five times
    	if (button_press_count > 5)
      {
    	
    	  sync_msg = (sync_message_t*)call Packet.getPayload(&packet, sizeof(sync_message_t));

    	  if (sync_msg == NULL) 
        {
      	  return;
    	  }
        
     	  sync_msg -> node_id         = ALL_NODES;
  	  	sync_msg -> cmd             = RESET;
    	  sync_msg -> packet_interval = PACKET_INTERVAL;
    	  sync_msg -> radio_power     = RADIO_POWER;
    	  sync_msg -> radio_channel   = RADIO_CHANNEL;
    
    	  if (call AMSend.send(AM_BROADCAST_ADDR, &packet, sizeof(sync_message_t)) == SUCCESS) 
        {
      	  call Leds.led0Off();
      	  send_busy = TRUE;
    	  }
    	}
	  }
  }

  
  event void Timer.fired() 
  {
    sync_message_t * sync_msg;

    timer_count ++;
    
    if (send_busy) 
    {
      return;
    }
    
    switch (timer_count)
    {
      case 1:
			  call Leds.led0On();
			  return;

      case 2:
			  call Leds.led1On();
			  return;

      case 3:
			  call Leds.led2On();
        break;

      default:
			  break;
    }
    
    sync_msg = (sync_message_t*)call Packet.getPayload(&packet, sizeof(sync_message_t));

    if (sync_msg == NULL) 
    {
      return;
    }
    
    // Load the parameters from test_config.h into sync_msg
    sync_msg -> node_id         = NODE_ID;
    sync_msg -> cmd             = COMMAND;
    sync_msg -> packet_interval = PACKET_INTERVAL;
    sync_msg -> radio_power     = RADIO_POWER;
    sync_msg -> radio_channel   = RADIO_CHANNEL;
    
    if (call AMSend.send(AM_BROADCAST_ADDR, &packet, sizeof(sync_message_t)) == SUCCESS) 
    {
      call Leds.led0Off();
      send_busy = TRUE;
    }
  }


  event void AMSend.sendDone(message_t* bufPtr, error_t error) 
  {
    call Timer.stop();

    if (&packet == bufPtr) 
    {
      call Leds.led1Off();
      send_busy = FALSE;
    }
  }

} // End of implementation
