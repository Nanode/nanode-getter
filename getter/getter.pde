// This routine subscribes to Pachube Feed 9675 and retrieves the 6 numerical commands that have been left there.
// These commands are used to control servo pointer angle and RGB lamp PWM channels.

#include <EtherShield.h>
#include <EEPROM.h>
#include <Flash.h>

//Ascii header and serial menu
FLASH_STRING(nanode_header,
"_______ ___    ___ ____ __/\\__ ___    ___  ______     ______     _______ _\n"
"       /   |  /  //    |*   * /   |  /  /,   ___ \\   /  __  \\   /      /\n"
"_____ /    | /  //     |/,'.\\/    | /  //  ;    \\ \\ /  /  \\  \\ /   ___/ __\n"
"     /     |/  //  /|  |    /     |/  //  /    /  //  /   /  //      /   \n"
"___ /  /|     //  /_|  |   /  /|     //  /    /  //  /   /  //   ___/ ____\n"
"   /  / |    //  ___   |  /  / |    / \\  \\___,  //  /__~  ~ /      /     \n"
"_ /__/  |___//__/   |__| /__/  |___/   \\______, /_______ ~ /______/ ______\n"
"                         Knowing is half the battle.\n");

FLASH_STRING(nanode_standby, 
"Pachube Command Get Example Feed: \n"
"Please Wait 30 secs for Pachube Connection\n");

FLASH_STRING(nanode_menu,
"/---------------------------\\\n"
"| Nanode configuration menu |\n"
"\\---------------------------/\n"
"0-Nanode MAC\n" 			//get 6 hex chars 00 to FF
"1-Nanode IP\n" 			//get 4 intger segments client ip address "myip[4]"
"2-Gateway IP\n" 			//get 4 intger segments gateway ip address. "qwip[4]"
"3-Webserver IP\n" 		//get 4 intger segments webserver ip address. "wsip[4]"
"4-API Key\n" 			//enter your Pachube API Key string here.
"5-Feed ID\n" 			//enter your Pachube Feed ID here.
"6-Mode\n"
"7-Display Config\n"
"8-Display Mode Pinout\n"
"9-Display RAM Usage\n"
"Please enter your choice:");

FLASH_STRING(nanode_pinout,
"                             /\\      /\\\n"
"                           _/  \\____/  \\_\n"
"                          /              \\\n"
"                         /   O        O   \\\n"
"                       =|        __       |=\n"
"                       =|        \\/       |=\n"
"                    ____\\       ||       /_____\n"
"  DIGITAL:         |     \\_____/  \\_____/      |  ANALOG:\n"
"                   | _                       _ |\n"
"  RX  [00]         ||0|                     |0||    [05]\n"
"  TX  [01]         ||0|  _._._._._._._._.   |0||    [04]\n"
"      [02]         ||0| |_ _ _ _ _ _ _ _ |  |0||    [03]\n"
"  PWM [03] RGB LED ||0|   ' ' ' ' ' ' ' '   |0||    [02]\n"
"      [04] METER   ||0| =  _    ._._._._.   |0||    [01]\n"
"  PWM [05] RGB LED ||0| - |0|  | _ _ _ _ |  |0||    [00]\n"
"  PWM [06] RGB LED ||0|    -    ' ' ' ' '    - |\n"
"      [07]         ||0|  _                  |0||   [Vin]\n"
"                   | -  | |     <>  <>  0   |0||   [GND]\n"
"      [08]         ||0| = =   [][][][][][]  |0||   [GND]\n"
"  PWM [09]         ||0| | |  __________     |0||    [5V]\n"
"  PWM [10]         ||0| = = | ******** |    |0||   [3V3]\n"
"  PWM [11]         ||0| | | | -------- |    |0|| [RESET]\n"
"      [12]         ||0| = = ||        || O   - |\n"
"      [13]         ||0| | | ||        ||       |\n"
"      [GND]        ||0| = = ||        || O     |\n"
"      [AREF]       ||0|  -  ||        ||       |\n"
"                   |_-______||        ||_____-_|\n"
"                            ||________||	 \n");

 uint8_t * heapptr, * stackptr;
void check_mem() {
  stackptr = (uint8_t *)malloc(4);          // use stackptr temporarily
  heapptr = stackptr;                     // save value of heap pointer
  free(stackptr);      // free up the memory again (sets stackptr to 0)
  stackptr =  (uint8_t *)(SP);           // save value of stack pointer
}
//  for the serial command interpreter
long previousMillis = 0;        // will store last time serial output was updated
int interval = 1000;           	// interval at which to generate serial output (milliseconds)

int incomingByte = 0;		// for incoming serial data
boolean dataReady = false;
int i = 0;
int len = 4;                    // expected string is 6 bytes long
// char inString[34];           // expected input string could be up to 33 characters long
char sub_add_String[4];         // sub-address is up to 3 characters

char arg0_String[6];            // arg0 is up to 5 digits
char arg1_String[6];            // arg1 is up to 5 digits
char arg2_String[6];            // arg2 is up to 5 digits
char arg3_String[6];            // arg3 is up to 5 digits
char arg4_String[6];            // arg4 is up to 5 digits
char arg5_String[6];            // arg5 is up to 5 digits

char inByte;
char inChar;
char commandChar = 0;           // holds the command character
char nextChar;
int incoming;

int temporary = 0;
int temp2 = 0;
int sub_add = 0;
char arg0 = 0;
unsigned int arg1 = 0;      	// Initialise the six input arguments
unsigned int arg2 = 0;
unsigned int arg3 = 0;
unsigned int arg4 = 0;
unsigned int arg5 = 0;
unsigned int arg6 = 0;      	//arg6 is the message number - incremented each time a command is sent

int k = 0;
int o = 0;
int q;                     	//pointers for string handling
int r;
int s;
int t;
int u;
int n = 0;

int PWMpin = 5;    		// PWM output on pin 5 to MPPT active load
int PWMval = 0;
int LEDpin = 6;    		// PWM drive to LED driver
int LEDval = 0;
int FANpin = 3;    		// PWM to fan speed control
int FANval = 0;

int servoVal = 90;

int RedPin = 3;   		// PWM for RGB LEDS
int GreenPin = 5;
int BluePin = 6;
 
#include <SoftwareSerial.h>
#include <math.h>

#include <Servo.h> 

Servo EWservo;

//*****************************************************************************************
#define STATUS_BUFFER_SIZE 50

static char statusstr[STATUS_BUFFER_SIZE];

 
static uint8_t mymac[6] = {0x54,0x55,0x58,0x10,0x00,0x28};
static uint8_t myip[4] = {192,168,1,252};
 
// Default gateway. The ip address of your DSL router. It can be set to the same as
// websrvip the case where there is no default GW to access the 
// web server (=web server is on the same lan as this host) 
static uint8_t gwip[4] = {91,109,222,137};


static uint8_t inString[34];    // an array for the input string

int combuf_start;     // start of command buffer
 
 
//============================================================================================================
// Pachube declarations
//============================================================================================================
#define PORT 80                   // HTTP
 
// the etherShield library does not really support sending additional info in a get request
// here we fudge it in the host field to add the API key
// Http header is
// Host: <HOSTNAME>
// X-PachubeApiKey: xxxxxxxx
// For more information on Pachube API keys please go to http://api.pachube.com/#security-authentication
// User-Agent: Arduino/1.0
// Accept: text/html

// Uncomment the next line to define the 'hostname' and add your api key by replacing "my_pachube_api_key_goes_here" with your PachubeApiKey
#define HOSTNAME "www.pachube.com\r\nX-PachubeApiKey: my_pachube_api_key_goes_here" 
 
static uint8_t websrvip[4] = {173,203,98,29};  // www.pachube.com

// Uncomment the next line to define the 'httppath' and add your feed number key by replacing "my_pachube_feed_id" with your feed id e.g. "/api/9675.csv"
#define HTTPPATH "/api/my_pachube_feed_id.csv"      // The feed
  
EtherShield es=EtherShield();
 
#define BUFFER_SIZE 500
static uint8_t buf[BUFFER_SIZE+1];
 
void browserresult_callback(uint8_t statuscode,uint16_t datapos){
//  Serial.print("Received data, status:"); Serial.println(statuscode,DEC);
  if (datapos != 0)
  {
//    Serial.println((char*)&buf[datapos]);  // This prints out the response from Pachube server
    // now search for the csv data - it follows the first blank line
    
    int j = 1;                  // pointer to instring buffer
    uint16_t pos = datapos;
    while (buf[pos])
    {
      while (buf[pos]) if (buf[pos++] == '\n') break;
      if (buf[pos] == 0) break; // run out of buffer
      if (buf[pos++] == '\r') break; // \n\r means a blank line (\r\n\r\n)
    }
    
//     inString[j]=buf[pos];               // copy buf character to instring[j]
//     Serial.print( inString[j]);
    
    
    if (buf[pos])  // we didn't run out of buffer
    {
      
//      inString[j]=buf[pos];               // copy buf character to instring[j]
//      Serial.print( inString[j]);
      pos++;  //skip over the '\n' remaining
      j++;    // increment pointer
      
      
//      Serial.print("CSV line is:");
//      Serial.println((char*)&buf[pos]);   //Print out the CSV string
     
    }
  }
  

// Copy the command buffer from buf to inString  
 // print out the command buffer  - use a pointer ip to point to the start of the buffer
 // and then index in 267 bytes to get to the start of the command data

 int j =  1;
 
 uint8_t* ip ;
 
 ip  = &buf[0];       // ip points to the buffer start in RAM
  
 for (int i = 0; i<=33; i++) {
      
//      inString[j] = *(ip + 267);           // inString[j] is the contents of the address pointed to by ip + 472 bytes in to the buffer

   inString[j] = buf[i + 267]; 
      
      Serial.print(char(inString[j]));
          
        if (inString[j] == 0) break;         // run out of buffer
      
       j++;
       ip++;
      
 } 


 
 //  Print out inString to make sure its correct
 
 for(int k=0; k<=34; k++) {
   
  if (inString[k] == 0) break;  
   
 //  Serial.print(char(inString[k]));
 
 }

 Serial.println();    // followed by a /nl

 ethernet_command();            // decode and act upon the ethernet command and print to serial
}

void setup(){
  Serial.begin(9600);
  pinMode(RedPin, OUTPUT);
  pinMode(GreenPin, OUTPUT);
  pinMode(BluePin, OUTPUT);
  
  analogWrite(RedPin, 128);    // Set LEDS to half brightness
   analogWrite(GreenPin, 128);
    analogWrite(BluePin, 128);
    
  EWservo.attach(4);          // Attach the East-West tracking servo to digital 10
  EWservo.write(90);           // set servo to mid-point

//print ascii and menu here 
nanode_header.print(Serial); Serial.println();
nanode_menu.print(Serial); Serial.println();

 //                       uint8_t mem_mymac[6] = {0x54,0x55,0x58,0x10,0x00,0x28};
/*
                        int mem_index = 0;
                        int segment_index = 0;
                        int mem_address = 0;
                        int mem_value = 0;
                        uint8_t mem_mymac[6] = {0x54,0x55,0x58,0x10,0x00,0x28};
                        unsigned int mem_PORT = 80;
                        */
int addr = 0;
char val = 0x00;
byte value;

  while(Serial.available()==0){}
		incomingByte = Serial.read();
		switch (incomingByte){
		case '0':
  // need to divide by 4 because analog inputs range from
  // 0 to 1023 and each byte of the EEPROM can only hold a
  // value from 0 to 255.
//  int val = analogRead(0) / 4;
  
  // write the value to the appropriate byte of the EEPROM.
  // these values will remain there when the board is
  // turned off.
  EEPROM.write(addr, val);


/*
http://arduino.cc/en/Reference/EEPROMWrite
An EEPROM write takes 3.3 ms to complete. The EEPROM memory has a specified life of 100,000 write/erase cycles, so you may need to be careful about how often you write to it.
http://www.arduino.cc/en/Reference/Delay
  delay(5); //this should be long enough for the device to write the value
*/

  delay(100);
  
  value = EEPROM.read(addr);

  // advance to the next address.  there are 512 bytes in 
  // the EEPROM, so go back to 0 when we hit 512.
  addr += 1;
  val += 1;
  if (addr == 512)
    addr = 0;
  
  Serial.print(addr);
  Serial.print("\t");
  Serial.print(value, HEX);
  Serial.println();
  
  // there are only 512 bytes of EEPROM, from 0 to 511, so if we're
  // on address 512, wrap around to address 0
  if (addr == 512)
    addr = 0;
/*
Serial.print("Before: ");
for (addr = 0; addr<6; addr++)
{
value = EEPROM.read(addr);
  Serial.print(addr);
  Serial.print("\t");
  Serial.print(value, HEX);
}

val = 0x54;
EEPROM.write(addr, val);
delay(10);
addr += 1;

val = 0x55;
EEPROM.write(addr, val);
delay(10);
addr += 1;

val = 0x58;
EEPROM.write(addr, val);
delay(5);
addr += 1;

val = 0x10;
EEPROM.write(addr, val);
delay(5);
addr += 1;

val = 0x00;
EEPROM.write(addr, val);
delay(5);
addr += 1;

val = 0x28;
EEPROM.write(addr, val);
delay(5);
addr += 1;

addr=0;
Serial.print("\nAfter: ");
for (addr = 0; addr<6; addr++)
{
value = EEPROM.read(addr);
  Serial.print(addr);
  Serial.print("\t");
  Serial.print(value, HEX);
}
*/
			break;
		case '1':
                        Serial.println("Please enter the Nanode IP Address: ");
			break;
		case '2':
                        Serial.println("Please enter the Gateway IP Address: ");
                        break;
		case '3':
                        Serial.println("Please enter the Webserver IP Address: ");
                        break;
		case '4':
                        Serial.println("Please enter the API Key: ");
			break;
		case '5':
                        Serial.println("Please enter the Feed ID: ");
                        break;
		case '6':				
                        Serial.println("Please choose the Mode: ");
			break;
		case '7':				
                        Serial.println("Here is the current Nanode config: ");
                        //EEPROM.read(address)
           /*             mem_value = EEPROM.read(mem_address);
                        Serial.print(mem_address);
                        Serial.print("\t");
                        Serial.print(mem_value);
                        Serial.println();
                        mem_address++;
                        if (mem_address == 1024)
                        {
                          mem_address = 0;
                        break;
                        }
                        delay(500);
                        break;
          */
		case '8':
                        nanode_pinout.print(Serial); Serial.println();
                        break;
                case '9':
                        check_mem();
                        Serial.print("\nRAM available ");
                        Serial.println(((uint16_t)stackptr - (uint16_t)heapptr),DEC);                
                        break;                         
                default:
                        break;
		}
  
  /*initialize enc28j60*/
  es.ES_enc28j60Init(mymac);
 
  //init the ethernet/ip layer:
  es.ES_init_ip_arp_udp_tcp(mymac, myip, PORT);
  
  // init the web client:
  es.ES_client_set_gwip(gwip);  // e.g internal IP of dsl routeru
  
  es.ES_client_set_wwwip(websrvip);  // target web server
 
}
 
void loop()
{
  static uint32_t timetosend;
  uint16_t dat_p;
  while(1){
    // handle ping and wait for a tcp packet - calling this routine powers the sending and receiving of data
    dat_p=es.ES_packetloop_icmp_tcp(buf,es.ES_enc28j60PacketReceive(BUFFER_SIZE, buf));
    if (dat_p == 0)
    {
      if (millis() - timetosend > 3000)  // every 8 seconds
      {
        timetosend = millis();
//        Serial.println("Sending request");
        // note the use of PSTR - this puts the string into code space and is compulsary in this call
        // second parameter is a variable string to append to HTTPPATH, this string is NOT a PSTR
        es.ES_client_browse_url(PSTR(HTTPPATH), NULL, PSTR(HOSTNAME), &browserresult_callback);
      }
    }
  }
}




 /****************************** Functions **************************************/
 
 /*************************************************************************************************/
 // Gets the serial command from the serial port, decodes it and performs action
 /*********************************************************************************************/
// Decodes a serial input string in the form  a255,65535,65535,65535,65535 CR
// So an alpha command a (arg0), followed by up to 5 numerical arguments (arg1 to arg5)
// If any of the arguments are missing they will default to zero
// so b1  =  b,1,0,0,0,0 and b,1 = b,1,0,0,0,0
// Always produces 6 comma separated terms, of which the first is alpha 
// (or punctuation character except comma)
 /*************************************************************************************************/
// a = command 
// 255 = 8-bit sub address
// , is delimiter
// 65535 is integer arg1
// , is delimiter
// 65535 is integer arg2
// , is delimiter
// 65535 is integer arg3
// , is delimiter
// 65535 is integer arg4
// , is delimiter
// 65535 is integer arg5
/*********************************************************************************************/
 

/*************************************************************************************************//*


int serialReader(){ 
  
  initStrings();                          // Clear the string buffers before we start
  
  if  (Serial.available() > 0) {          // if there are bytes waiting on the serial port
    inByte = Serial.read();               // read a byte
    delay(10);                            // *** added to make it work ***

    if (inByte == 13){                    //  follow the false code until you get a CR - this packs inString with the complete string
      dataReady = true;
  
  */
/*************************************************************************************************/  
//Get the various field from the ethernet command and decode them

   int ethernet_command()   {
      
      // now start to strip out the command and argument fields
      
      inChar = inString[1];               // get the leading character - this is the command character
      
      arg0 = inChar;                      // arg0 is the command character

      
      /*******************************************************************************************/
      // Now we process the arg1_String  checking whether we are b1 or b,1 format
      /*******************************************************************************************/
      
      // q is a pointer which increments it's way through inString
      
       k =  0;                          //reset the string pointer
       
       nextChar = inString[2];           // check if the second character is a comma (b,1 format)- if so start at the 3rd character
       
       if ( nextChar==44)  q=3;         // If character 2 is a comma - arg 1 will be in position 3
       else q=2;                        // b1 format
       
       
      for (int p = q; p <34; p++) {     // Now start at the location after the comma and strip out the arg1_String
      
      
      
        nextChar = inString[p];         // get the next Char
        
       q++;                             // Increment pointer q to keep track of where we are in inString
      
         if (nextChar == 44 || nextChar == 13 ) {          // if it's a comma (ASCII 44) then bail out
         
         q--;
      
       
        break;
       
      }
        
      arg1_String[k] = nextChar;    // start packing the arg1_String
      
      k++;                             // increment the pointer to arg1_String
      
     
        
      }
      
      
       // arg1_String should now contain up to 5 characters
      
      
      
      /*******************************************************************************************/
      // Now we process the arg2_String in the same way
      /*******************************************************************************************/
      
      k =  0;                    //reset the string pointer
       
      for (int p = q+1; p <34; p++) {   // Now start at the location after the 2nd comma and strip out the arg2_String
      
      nextChar = inString[p];         // get the next Char
      
      q++;
      
     if (nextChar == 44 || nextChar == 13 ) {          // if it's a comma (ASCII 44) then bail out
      
       
       break;
       
      }
        
      arg2_String[k] = nextChar;    // start packing the arg1_String
      
      k++;                             // increment the pointer to arg2_String
      
     
        
      }
      
      /*******************************************************************************************/
      // Now we process the arg3_String in the same way
      /*******************************************************************************************/
      
      k =  0;                    //reset the string pointer
       
      for (int p = q+1; p <34; p++) {   // Now start at the location after the 2nd comma and strip out the arg3_String
      
      nextChar = inString[p];         // get the next Char
      
      q++;
      
      if (nextChar == 44 || nextChar == 13 ) {          // if it's a comma (ASCII 44) then bail out
      
       break;
       
      }
        
      arg3_String[k] = nextChar;    // start packing the arg1_String
      
      k++;                             // increment the pointer to arg3_String
    
      }
      
      /*******************************************************************************************/
      // Now we process the arg4_String in the same way
      /*******************************************************************************************/
      
      k =  0;                    //reset the string pointer
       
      for (int p = q+1; p <34; p++) {   // Now start at the location after the 2nd comma and strip out the arg4_String
      
      nextChar = inString[p];         // get the next Char
      
      q++;
      
      if (nextChar == 44 ) {         // if it's a comma (ASCII 44) then bail out
      
       break;
       
      }
        
      arg4_String[k] = nextChar;    // start packing the arg1_String
      
      k++;                             // increment the pointer to arg4_String
     
      }
      
      
      /*******************************************************************************************/
      // Now we process the arg5_String in the same way
      /*******************************************************************************************/
      
      k =  0;                    //reset the string pointer
       
      for (int p = q+1; p <34; p++) {   // Now start at the location after the 2nd comma and strip out the arg5_String
      
      nextChar = inString[p];         // get the next Char
      
      q++;
      
     if (nextChar == 44 || nextChar == 13 ) {          // if it's a comma (ASCII 44) then bail out
    
       break;
       
      }
        
      arg5_String[k] = nextChar;    // start packing the arg1_String
      
      k++;                             // increment the pointer to arg5_String
        
      }
      
      /*************************************************************************/
      //  Now ennumerate the arg strings
      
      
       // Ennumerate the arguments
 
       arg1 = atoi(arg1_String);          // get enumerated arg1
       arg2 = atoi(arg2_String);          // get enumerated arg2
       arg3 = atoi(arg3_String);          // get enumerated arg3
       arg4 = atoi(arg4_String);          // get enumerated arg4
       arg5 = atoi(arg5_String);          // get enumerated arg5
       arg6++;                            // increment the message number
      
     
      
      temporary = arg1;              // convert ascii to integer
      
      

      if (temporary > 255) temporary = 255;
     
      
     
      
      
      
/******************************************************************************************/
// Action Routines:  Work out the command, the argument and what to do with it
// Echo the command (verbose form) and value to serial terminal
/******************************************************************************************/


    switch  (inChar){          //  
    
    case 97:
    
    Serial.print (" Active Load ");
    PWMval = temporary;
    analogWrite(PWMpin, PWMval);       // Update the PWM pin
    break;
    
    case 98:
    Serial.print (" Blue ");
    int BlueVal; 
    BlueVal = temporary; 
   analogWrite(BluePin,BlueVal);
    break;
    
    
    
    
    case 99:
    Serial.print (" Current ");
    
    break;
    
    case 100:
    Serial.print (" Distance ");
    break;
    
    case 101:
    Serial.print (" Echo ");
    break;
    
    case 102:
    Serial.print (" Fan Speed ");
    
    FANval = temporary;
    analogWrite(FANpin, FANval);      // Update the fan speed
    break;
    
    case 103:
    Serial.print (" Green ");
    int GreenVal; 
    GreenVal = temporary; 
   analogWrite(GreenPin,GreenVal);
    break;
    
    
    
    case 105:
    Serial.print (" Interval ");
    
    interval = temporary;     // Update the interval
    
    break;
    
    case 108:
    Serial.print (" Lamp ");
    LEDval = temporary;
    analogWrite(RedPin, arg1);    // Set LEDS to half brightness
    analogWrite(GreenPin, arg2);
    analogWrite(BluePin, arg3);
//    analogWrite(LEDpin, LEDval);      // Update the LED brightness
    break;
    
    case 114:
    Serial.print (" Red ");
    int RedVal; 
    RedVal = temporary; 
   analogWrite(RedPin,RedVal);
    break;
    
    
    
     case 115:
    Serial.print (" Servo Angle ");
    
    servoVal = temporary;
    
    EWservo.write(servoVal);  // set servo to new position
    
    break;
    
    
 
    
    // Add more command case statements here
     
    }
    
 

       
       // Now clear the temporary arg strings so no characters left in buffers
       
       for (int j = 0; j < 4; j++) {        // clear the sub_add_String
      arg1_String[j] = 0;
      }
      for (int j = 0; j < 4; j++) {        // clear the sub_add_String
      arg1_String[j] = 0;
      }
      for (int j = 0; j < 4; j++) {        // clear the sub_add_String
      arg2_String[j] = 0;
      }
      for (int j = 0; j < 4; j++) {        // clear the sub_add_String
      arg3_String[j] = 0;
      }
      for (int j = 0; j < 4; j++) {        // clear the sub_add_String
      arg4_String[j] = 0;
      }
      for (int j = 0; j < 4; j++) {        // clear the sub_add_String
      arg5_String[j] = 0;
      }
       
       
//        analogWrite(RedPin, arg3/2);    // Set LEDS to half brightness
  // analogWrite(GreenPin,arg4/2);
    // analogWrite(BluePin, arg5/2);
       
       
       
   // Print out the ennumerated arguments noting that arg0 is a character   
      
      sprintf( statusstr, "%c,%u,%u,%u,%u,%u,%u", arg0,  arg1,  arg2, arg3,  arg4 ,  arg5, arg6 );
      Serial.println(statusstr);   // print out the string for debug purposes
      
      
      
 //     clear the inStrings
 
      for (int j = 0; j < 34; j++) {        // clear the inString for next time
     inString[j] = 0;
      }
 
      
//      i = 0;
      
//      return incoming;
      
      
    }
//    else dataReady = false;      // No CR seen yet so put digits into array
//    Serial.print(inByte); 


//    inString[i] = inByte;
    
   
    
//    i++;
 
  
//  }


// }

/***************************************************************************************************/
// Initialise the strings to zero 
/***************************************************************************************************/

 int initStrings()  {


 /*
 
        arg0 = 0;                            // Initialise the six input arguments
        arg1 = 0;      
        arg2 = 0;
        arg3 = 0;
        arg4 = 0;
        arg5 = 0;
   */   
      for (int j = 0; j < 4; j++) {        // clear the sub_add_String
      sub_add_String[j] = 0;
      }
      
      for (int j = 0; j < 6; j++) {        // clear the arg1_String
      arg1_String[j] = 0;
      }
      
      for (int j = 0; j < 6; j++) {        // clear the arg2_String
      arg2_String[j] = 0;
      }
      
       for (int j = 0; j < 6; j++) {        // clear the arg1_String
      arg3_String[j] = 0;
      }
      
      for (int j = 0; j < 6; j++) {        // clear the arg2_String
      arg4_String[j] = 0;
      }
      
      for (int j = 0; j < 6; j++) {        // clear the arg2_String
      arg5_String[j] = 0;
      }
      
    }


