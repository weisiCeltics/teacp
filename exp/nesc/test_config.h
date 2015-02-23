#ifndef TEST_CONFIG_H
#define TEST_CONFIG_H

// Options: PERIODIC_TIMER | EXPONENTIAL_TIMER
#define PERIODIC_TIMER

// The local queueing policy applies to BCP
// while CTP is not affected.
// Options: LIFO | FIFO
#define LIFO

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
  RNG_SEED         = 202,
  INITIAL_INTERVAL = 1024
};

enum{
  NODE_ID         = ALL_NODES,
  COMMAND         = START,
  PACKET_INTERVAL = 512,
  RADIO_POWER     = 3,
  RADIO_CHANNEL   = 26
};

#endif
