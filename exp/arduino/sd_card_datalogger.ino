/*
  SD card datalogger
  
  This example is a SD card datalogger used in TeaCP.
  
  Liangxiao Xin
  Phd, Systems Engineering,
  Boston University
*/
#include <SPI.h>
#include <SD.h>

File DataFile;
String inputString = "";         // a string to hold incoming data
int data_num = 0; // the index of data in one message
boolean stringComplete = false;  // whether the string is complete
int count = 0;  // count the number of message received
int iter = 0;   // the index of byte in one message
int mark1 = 0;  // use for fixing the bug in serial transmission
unsigned int save = 0;  // save the data in SD card when several inputStrings are written into SD card


void setup() {
  // initialize serial:
  Serial.begin(115200);
  Serial.available();
  while (!Serial) {
    ; // wait for serial port to connect. Needed for Leonardo only
  }  
  pinMode(10, OUTPUT);  
  pinMode(7, OUTPUT);  //signal for feedback to TelosB

  Serial.print("Initializing SD card...");
  // On the Ethernet Shield, CS is pin 4. It's set as an output by default.
  // Note that even if it's not used as the CS pin, the hardware SS pin 
  // (10 on most Arduino boards, 53 on the Mega) must be left as an output 
  // or the SD library functions will not work.
     
  if (!SD.begin(4)) {
    Serial.println("initialization failed!");
    return;
  }
  Serial.println("initialization done.");
  
  // open the file. note that only one file can be open at a time,
  // so you have to close this one before opening another.
  DataFile = SD.open("data.txt", O_CREAT | O_WRITE);
  
  // if the file opened okay, write to it:
  if (DataFile) {
    Serial.print("Writing to data.txt...");
    Serial.println("done.");
  } else {
    // if the file didn't open, print an error:
    Serial.println("error opening test.txt");
  }
 
  // reserve 600 bytes for the inputString:
  inputString.reserve(600);
}

void loop() { 
  // write the data into SD card when the string is complete:
  if (stringComplete) {  
    if (DataFile) {
      //Serial.print("Writing to test.txt...");
      DataFile.print(inputString);
      save++;
      // save the data in SD card when 200 strings are wriiten:
      if(save==200){ 
        DataFile.flush();
        save=0;
      }
    // tell TelosB to continue sending message
    digitalWrite(7, LOW);
    } 
    // clear the string:
    inputString = "";
    stringComplete = false;
  }
}

/*
 SerialEvent occurs whenever a new data comes in the
 hardware serial RX. This routine is run between each
 time loop() runs, so using delay inside loop can delay
 response.  Multiple bytes of data may be available.
*/
void serialEvent() {
  while (Serial.available()) {
    // get the new byte:    
    unsigned int inChar = (unsigned int)Serial.read(); 
    // add it to the inputString:
    if(inChar == 0x7E && iter==0){ // the first byte in a message
      iter++;
    }else if(inChar == 0x45 && iter == 1){ // the second byte in a message
      iter++;
    }else if(inChar == 0x7E && iter>26){ // the last byte in a meesage
      iter=0;
      count++;
      inputString += " \n";
      data_num=0;
      if(count > 15) // the string is complete
      {
        stringComplete = true;
        count = 0;
        digitalWrite(7, HIGH); // tell TelosB not to send message
        break;
      }
    // fix a bug in serial communication
    }else if(inChar == 0x7D){
      mark1=1;
    }else if((inChar==0x5D)&&(mark1==1)){
      mark1=0;
      if(iter < 25){
        inputString += "7d";
      }
      iter++;
    }else if((inChar==0x5E)&&(mark1==1)){
      mark1=0;
      if(iter < 25){
        inputString += "7e";
      }
      iter++;
    }else{  // the rest of bytes in a message
      mark1=0;
      if(iter < 25){
        data_num++;
        if(data_num > 8){
          if(inChar <= 15){
            inputString += "0";
          }
          inputString += String(inChar,HEX);
        }
      }
      iter++;
    }  
  }
}
