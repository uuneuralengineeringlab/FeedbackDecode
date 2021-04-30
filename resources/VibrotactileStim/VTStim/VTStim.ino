//Bytes available in serial buffer
int BAvail;

//Assigning pins for pwm output
int P0 = 3; 
int P1 = 5;
int P2 = 6;
int P3 = 9; 
int P4 = 10;
int P5 = 11; 

//PWM output
byte PWM[6] = {0,0,0,0,0,0};

void setup(void)
{
  // start serial port
  Serial.begin(115200);
}

//Main function
void loop(void)
{ 
 
  BAvail = Serial.available();
  if (BAvail>=6) { 
      Serial.readBytes(PWM,BAvail); //empty buffer regardless of how many bytes received
   
      analogWrite(P0,PWM[0]);
      analogWrite(P1,PWM[1]);
      analogWrite(P2,PWM[2]); 
      analogWrite(P3,PWM[3]); 
      analogWrite(P4,PWM[4]); 
      analogWrite(P5,PWM[5]); 

      /*
      Serial.print(PWM[0]);
      Serial.print(", ");
      Serial.print(PWM[1]);
      Serial.print(", ");
      Serial.print(PWM[2]);
      Serial.print(", ");
      Serial.print(PWM[3]);
      Serial.print(", ");
      Serial.print(PWM[4]);
      Serial.print(", ");
      Serial.print(PWM[5]);
      Serial.print(", ");
      Serial.println();  
      */

  } //end if BAvail>0
  
} //end loop
