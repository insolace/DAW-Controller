/*
 * Arduinome_4x4_RGB - Arduino Based Monome-like device with a 4 X 4 matrix of fully fadeable RGB LEDs
 * By Mike Cook (mike_k_cook at yahoo dot co dot uk) 22/10/08 based on the following:-
 *
 * Alex Leone - acleone ~AT~ u.washington.edu for the basis of the TL5940 Libiary
 * "ArduinomeFirmware" - Arduino Based Monome Clone by Owen Vallis & Jordan Hochenbaum 06/16/2008
 *
 * --------------------------------------------------------------------------
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * --------------------------------------------------------------------------
 *
 * Please DO NOT email monome with technical questions and/or help regarding this code or clone.  
 * They are in NO WAY responsible or affiliated with this project other than they were our inspiration 
 * and we used many of their methods and pulled from their code.
 * 
 * Additionally, while we are availble and willing to help as much as possible, we too CANNOT be held
 * responsible for anything you do with this code.  Please feel free to report any bugs, suggestions 
 * or improvements to us as they are all welcome.  Again, we cannot be held responsible for any damages 
 * or harm caused by the use or misuse of this code or our instructions.  Thank you for understanding.
 * --------------------------------------------------------------------------
 *
 * Links:
 * http://bricktable.wordpress.com - Our website - Click "Arduino Monome Project" on the Navigation Menu on the right.
 * www.monome.org - the "original" monome and our inspiration
 * www.flickr.com/photos/unsped/2283428540/in/photostream/
 
 * http://play-collective.net/blog/archives/category/arduinomonomergb
 *
 *
 * www.thebox.myzen.co.uk - for detailes of the 4 by 4 RGB - schematic and construction Mike Cook (Grumpy Mike)
 */


#include <avr/pgmspace.h>
#include <TLC5940Multiplex.h>

static int t;
static int L=0;
int incomingByte = 0;	// for incoming serial data
int redOn=0xfff, greenOn=0x20, blueOn=0x00, redOff=0x000, greenOff=0, blueOff = 0;  // colours for on and off states from the monome
int  IntensityVal, DisplayVal, ShutdownModeVal, address, state = 0 ;
boolean ShutdownModeChange = false, WaitingForAddress = true;
byte byte0, byte1, x, y, z;
byte keyState[4][4];


/* This sketch and hardware uses only the first 12 LED drivers in a TLC5940 however the software will support all 16
 * The first value in each row is the value for the last LED on the last TLC5940.
 * Each value is 12 bits (0-4095).  24 bytes is 192 bits, which is 16 led's * 12 bits each.  Each of the numbers in the array below is 1 byte (0-255).
 *    For example,
 *
 *  | 1st byte | 2nd byte | 3rd byte | 4th byte | 5th byte | 6th byte | ...
 *  | LED 16 value   | LED 15 value  | LED 14 value   | LED 13 value  | ...
 */

// Change this array initilisation to get a diffrent switch on pattern
 
 static uint8_t ledBuffer[] = {
	// row 1 (botom)
   //     lower LEDs not used        bb    bg    gg    rr    rb    bb    gg    gr    rr    bb    bg    gg     rr    rb    bb      gg    gr    rr
    0x0, 0x0, 0x0, 0x0, 0x0, 0x00, 0x04, 0x00, 0x80, 0x40, 0x00, 0x40, 0x08, 0x04, 0x00, 0x04, 0x00, 0x80,  0x40, 0x00, 0x40,   0x08, 0x04, 0x00,  // "white" row
	// row 2
    0x0, 0x0, 0x0, 0x0, 0x0, 0x00, 0x00, 0x00, 0x00, 0x40, 0x00, 0x00, 0x00, 0x04, 0x00, 0x00, 0x00, 0x00,  0x40, 0x00, 0x00,   0x00, 0x04, 0x00, // red row
        // row 3
    0x0, 0x0, 0x0, 0x0, 0x0, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x00, 0x20, 0x00, 0x00, 0x00, 0x02, 0x00,  0x00, 0x00, 0x00,   0x20, 0x00, 0x00, // green row
        // row 4 (top)
    0x0, 0x0, 0x0, 0x0, 0x0, 0x00, 0x02, 0x00, 0x00, 0x00, 0x00, 0x20, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00,  0x00, 0x00, 0x20,   0x00, 0x00, 0x00  // blue row
};

uint8_t dotClockBuffer[] = {
   0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x00, 0x00, 0x00
  // 0x00, 0x00, 0x00,  0x00, 0x00, 0x00,  0x00, 0x00, 0x00,  0x00, 0x00, 0x00
 };

void setup () {
  int i;

  // MacOS users - set this to 57600
  // Windows users - you'll need to hack monomeSerial
  // to make it run at 9600
  // Serial.begin(9600);
  Serial.begin(57600);    // Debug speed
  Tlcm.init();
  Tlcm.resetTimers();
  Tlcm.startMultiplexing(ledBuffer);
 //  Tlcm.setDCs(dotClockBuffer);  // I can't get this to work but it's here if it did
    // clear out key state
    for(int i=0; i<4; i++){
      for(int j=0; j<4; j++){
        keyState[i][j] = (byte) 0;
      }
    }
  // make sure to turn off the lights if you want here.

}  


void loop () {

  checkSerial();
  // do the commands in serial

  if (ShutdownModeChange) {
    ShutdownModeChange = false; 
  }

  // check for button presses
   buttonCheck();  // monome output
//  buttonPressed();  // change LEDs for testing
}

void onLED( int x, int y)
{
   x^=3; // change order of x in row
   Tlcm.set(ledBuffer, x*3   , y, redOn);
   Tlcm.set(ledBuffer, x*3 +1, y, greenOn);
   Tlcm.set(ledBuffer, x*3 +2, y, blueOn);
}
void offLED( int x, int y)
{  x^=3; // change order of x in row
   Tlcm.set(ledBuffer, x*3   , y, redOff);
   Tlcm.set(ledBuffer, x*3 +1, y, greenOff);
   Tlcm.set(ledBuffer, x*3 +2, y, blueOff);
}

// for debug
void showBuffer()
{ int i,j;
   for(j=0; j<4; j++){
     for(i=0; i<24; i++){
       Serial.print(ledBuffer[i+j*24], HEX);
       Serial.print(" ");
     }
     Serial.println(" ");
   }
}

void clearRows() {
  for(int i=0; i<4; i++){
  for(int j=0; j<24; j++) ledBuffer[j + i*24 ] = 0;
  }
}

void setRows() {
   for(int i=0; i<4; i++){
  for(int j=0; j<24; j++) ledBuffer[j + i*24 ] = 0xff;
}
}
// test routine see if a buton is pressed turn on LED if it is
void buttonPressed(){
   // read push button
   for(int j=0; j<4; j++){
   for(int i=0; i<4; i++){
    if(Tlcm.readPush(i,j) != 0) {
 //   Serial.print(i);
 //   Serial.print(j);
 //   Serial.print(" ");
    onLED(i,j);
    if(j==0 && i==0) showBuffer();
          }
          else { 
          // offLED(i,j);
        }
     }
   }
}

// handle incomming message and act on it
void checkSerial() {
  do 
  {
    if (Serial.available())
    {
      if (WaitingForAddress)   // address is the first byte of the two byte command
      {
        byte0 = Serial.read();
        address = byte0 >> 4;
        WaitingForAddress = false; 
        switch(address)  // do one byte commands
        {
         case 9: // clear command
         if((byte0 & 1) ==0) clearRows(); else setRows();
        WaitingForAddress = true; // next byte is a new command
        break;
        }        
      }

      if (Serial.available())
      {
        WaitingForAddress = true;  // the next byte is the first byte of the next command
        byte1 = Serial.read();    // read the second byte of this command

        switch(address)
        {
        case 2:  // led command
          state = byte0 & 15;
          x = (byte1 >> 4) & 0x03;  // mask so we don't go over the 4 by 4 grid
          y = (byte1 & 15) & 0x03;

          if (state == 0){
            offLED(x,y); 
          }
          else {
          onLED(x,y);
          }
          break;

        case 3:   // led intensity command RGB packed into 12 bits following the message
          redOn =   ((byte0 & 0xf) << 4) | byte1;
          greenOn = ((byte0 & 0xf) << 4) | byte1;
          blueOn =  ((byte0 & 0xf) << 4) | byte1;         
          break;
        case 4:  // led test command
          if( (byte1 & 1) == 0) { setRows(); } else { clearRows(); }       
          break;
        case 5:  // enable ADC command - but we don't do this
          break;
        case 6: // shutdown command - not sure what the monome is expected to do here
          ShutdownModeChange = true;
          ShutdownModeVal= byte1 & 15;
          break;
        case 7:  // led row command
          y = byte0 & 0x03; // mask this value so we don't write to an invalid address.
          z = byte1;
          x = 0;
          for(byte i = 1; i<0x10; i <<= 1 ){
          if( (i & z) != 0) { onLED(x,y);} else  { offLED(x,y);}
          x++;
          }
          break;
        case 8:  // coloum command
          x = byte0 & 0x03; // mask this value so we don't write to an invalid address.
          z = byte1;
          y = 0;
          for(byte i = 1; i<0x10; i <<= 1){
          if( (i & z) != 0) { onLED(x,y); } else  { offLED(x,y);}
          y++;
          }
          break;
          default:
          break;
          // extra colour setting commands
        case 13:   // set red led intensity command
          redOn = byte1 | ((byte0 & 0x0f) << 8);
          break;
        case 14:   // set green led intensity command   
          greenOn = byte1 | ((byte0 & 0x0f) << 8);
          break;
        case 15:   // set blue led intensity command   
          blueOn = byte1 | ((byte0 & 0x0f) << 8);         
          break;
          
        } // end switch(address)
      } // end if (Serial.available()
    } // end if (Serial.available();
  } // end do
  while (Serial.available() > 16);
}

void buttonCheck()
{ byte t;
  // read push button array and send message if anything changed from last time
   for(byte j=0; j<4; j++){
   for(byte i=0; i<4; i++){
    if(Tlcm.readPush(i,j) != keyState[i][j] ) {
      // a key has changed
       keyState[i][j] = Tlcm.readPush(i,j);
       // send on or off if pressed
        if(keyState[i][j] == 0) { Serial.print(0x0,BYTE); } else { Serial.print(0x1,BYTE); }
        // send x - y coordnate of switch that has changed in the second byte
       t = (i << 4) | j;
       Serial.print(t,BYTE);
          }
     }
   }
  }

 

