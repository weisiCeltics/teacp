#ifndef TEST_CONFIG_H
#define TEST_CONFIG_H

#define PERIODIC_TIMER

// The local queueing policy applies to BCP
// while CTP is not affected.
#define N/A

enum
{
  START = 0,
  PAUSE = 1,
  RESET = 2,
  ALL_NODES = 100
};

enum
{
  AM_UART          = 0xAF,
  AM_CENTRAL_START = 0x06,
  AM_COLLECTION    = 0xEE,
  UART_QUEUE_LEN   = 12,    // The queue size of storing log messages
  RNG_SEED         = 11211,
  INITIAL_INTERVAL = 1024
};

enum{
  NODE_ID         = ALL_NODES,
  COMMAND         = START,
  PACKET_INTERVAL = 10,
  RADIO_POWER     = 3,
  RADIO_CHANNEL   = 26
};

#endif
