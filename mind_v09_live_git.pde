//// prototype visualizer for neurosky mindwave eeg device
//// by Tue Brisson Mosich
//// requires the thinkgear connector application
//// blobby2 shader based on genekogans shader examples -- https://github.com/genekogan/Processing-Shader-Examples

import neurosky.*; 
import org.json.*; 
import grafica.*;
import java.util.Random;
import processing.sound.*;
import java.util.concurrent.TimeUnit;

//v0 format
//output.println(millis2 + "," + signal + "," + attention + "," + meditation + "," + eegdelta + "," + eegtheta + "," + eegloalpha + "," + eeghialpha + "," + eeglobeta + "," + eeghibeta + "," + eegmidgamma + "," + eeglogamma + "," + blink); // Write a line the file
int version=0; //for future use

//// SELECT RECORD OR PLAYBACK MODE

boolean recordingmode=true;


//// INPUT FILENAME FOR PLAYBACK
// -- files are automatically created when recording, look in the folder where this program is stored --

String filename="filename_here.txt";

//// SETTINGS

boolean playsound=true; //play sound or not
boolean showstrobe=true; //turn strobing when high att on/off
boolean shownumbers=true; //turn text/numbers on/off
boolean showgraph=true; //turn att/med graphs on/off
boolean showshader=true; //turn shader/red animation on/off


int randseed=666; //set random seed for strobe etc
int interval=1000; //speed; 2000 millis for v0 data format // TODO get actual interval when displaying
int attcol=#00FF00; //color of attention graph
int medcol=#8e44ad; //color of meditation graph
int maxYvalues=1000; //number of values of graph to show at one time (how compressed/zoomed in)
float graphlinewidth=5.0; //thickness of graph line

int graphxscale=20;
int graphyscale=7;

String stringversion = "BrainCOM v.0.7: ";

// VARS FOR RECORDING
String[] date = new String[6];
String txtdate = "20210000000000";
PrintWriter output;
ThinkGearSocket neuroSocket; 
float eegdelta=15; 
float eegtheta=25; 
int eegloalpha=35; 
int eeghialpha=45; 
int eeglobeta=55; 
int eeghibeta=67; 
int eegmidgamma=75; 
int eeglogamma=85; 
int blink=95; 

// VARS FOR RECORDING & DISPLAYING
int signal=200; 
int attention=10; 
int meditation=10; 
int millis_stamp=0; 

int currentatt;
int currentmed;
int currentsig;


//OTHER VARS
PFont font; 
boolean blinker=false; 
boolean startup=true; 
int timer=0; 
int txttimer=0; 
int strober; 
int number = 0; 
boolean txtflash=true; 
float easing = 0.1; //speed/granularity of easing
float attease; 
float medease; 
int timeease;
int starttime=0;
boolean gettimeonce=true;
boolean playing=false; 

PShader blobbyShader; 
PGraphics pg; 

int place=0; //place in saved dataarray
int arraylength;

int[] timestamp;
int[] sig;
int[] att;
int[] med;

//note scale array -- select one here or create your own
// a simple chromatic and minor pentatonic scale is provided
//uncomment/comment out the one you want/dont want

//float[] notes_att =  { 440.00, 466.16, 493.88, 523.25, 554.37, 587.33, 622.25, 659.25, 698.46, 739.99, 783.99, 830.61 };
//float[] notes_att =  { 220.00, 233.08, 246.94, 261.63, 277.18, 293.66, 311.13, 329.63, 349.23, 369.99, 392.00, 415.30 }; //chromatic
//float[] notes_med =  { 110.00, 116.54, 123.47, 130.81, 138.59, 146.83, 155.56, 164.81, 174.61, 185.00, 196.00, 207.65 }; //chromatic

float[] notes_att =  { 261.63, 293.66, 329.63, 392.00, 440.00 }; //min pent
float[] notes_med =  { 130.81, 146.83, 164.81, 196.00, 220.00 }; //min pent


public GPlot plot2, plot3;

TriOsc oscAtt;
TriOsc oscMed;

void setup() { 
  
  size(1024, 768, P3D); //use this line for windowed mode
  //fullScreen(P3D);   //use this line for fullscreen
  background(0); 
  smooth(8);

  font = createFont("Verdana", 20); 
  textFont(font); 

  // setup for the shader
  pg = createGraphics(width, height, P3D); 
  blobbyShader = loadShader("blobby2.glsl");
  
  //set random seed
  randomSeed(randseed);

  // create sine oscillator
  oscAtt = new TriOsc(this);
  oscMed = new TriOsc(this);


  //setup for the two graphs
  plot2 = new GPlot(this);
  plot2.setPos(width/graphxscale, height/graphyscale);
  plot2.setDim(width-15*graphxscale, height/3);
  plot2.setYLim(0, 200);
  plot2.setLineColor(attcol);
  plot2.setLineWidth(graphlinewidth);
  plot2.deactivateZooming();
  plot2.deactivateCentering();
  plot2.deactivatePanning();
  plot2.setFixedYLim(true);

  plot3 = new GPlot(this);
  plot3.setPos(width/graphxscale, height/graphyscale);
  plot3.setDim(width-15*graphxscale, height/3);
  plot3.setYLim(0, 200);
  plot3.setLineColor(medcol);
  plot3.setLineWidth(graphlinewidth);
  plot3.deactivateZooming();
  plot3.deactivateCentering();
  plot3.deactivatePanning();
  plot3.setFixedYLim(true);

  ////IF DISPLAYING ONLY
  if (recordingmode==false) {
    //load saved data from txt file
    String[] lines = loadStrings(filename); //filename in data folder of sketch
    println("there are " + lines.length + " entries in the file");
    arraylength=lines.length;

    timestamp= new int[lines.length];
    sig= new int[lines.length];
    att= new int[lines.length];
    med= new int[lines.length];

    for (int i = 0; i < lines.length; i++) {
      String[] list = split(lines[i], ',');
      timestamp[i]=int(list[0]);
      sig[i]=int(list[1]);
      att[i]=int(list[2]);
      med[i]=int(list[3]);
    }
  }

  ////IF RECORDING ONLY
  if (recordingmode==true) {
    //setup for the filename generation

    date[0] = String.valueOf(year());   // 2003, 2004, 2005, etc.
    date[1] = String.valueOf(month());  // Values from 1 - 12
    date[2] = String.valueOf(day());    // Values from 1 - 31
    date[3] = String.valueOf(hour());    // Values from 0 - 23
    date[4] = String.valueOf(minute());  // Values from 0 - 59
    date[5] = String.valueOf(second());  // Values from 0 - 59
    txtdate = join(date, "-");
    output = createWriter(txtdate+".txt"); 

    //setup communication with mindwave sensor

    ThinkGearSocket neuroSocket = new ThinkGearSocket(this); 
    try { 
      neuroSocket.start();
      println("start");
    } 
    catch (Exception e) { 
      println("Is ThinkGear running??");
    }
  }


  if (version==0) { //for future versions
  }

  // rest of setup


}

void draw() { 
  //main loop

  //playback only
  if (recordingmode==false) {
    currentatt = att[place];
    currentmed = med[place];
    currentsig = sig[place];

    if (gettimeonce==true) {
      starttime = millis();
      gettimeonce=false;
    }
    int targettime = timestamp[place]; 
    timeease = targettime + millis()-starttime;

    if (startup==false) {
      if (millis() - timer >= interval) { 
        timer = millis();
        if (place <arraylength) {
          place++;
          gettimeonce=true;
        } else place=0;
      }
    } else startup=false;
  } 


  // recording only
  if (recordingmode==true) {
    timeease=millis();
    currentatt = attention;
    currentmed = meditation;
    currentsig = signal;
    //data logger
    if (millis() - timer >= interval) { 
      timeease=millis();
      output.println(timeease + "," + signal + "," + attention + "," + meditation + "," + eegdelta + "," + eegtheta + "," + eegloalpha + "," + eeghialpha + "," + eeglobeta + "," + eeghibeta + "," + eegmidgamma + "," + eeglogamma + "," + blink); // Write a line the file
      timer = millis();
      output.flush(); // Writes the remaining data to the file so data isnt lost if prg crash
    }
  }

  if (showshader) {
    blobbyShader.set("time", (float) timeease/1000.0); //seed for blobby animation
    blobbyShader.set("resolution", float(pg.width), float(pg.height)); 
    blobbyShader.set("depth", map(attease-medease, -100, 100, 0.24, 0.35)); 
    blobbyShader.set("rate", map(attease-medease, -100, 100, 0.40, 0.86)); 
    blobbyShader.set("alpha", 0.1); 
    blobbyShader.set("colr", map(currentatt-currentmed, -100, 100, 0.49, 0.24)); 
    blobbyShader.set("colg", map(currentatt-currentmed, -100, 100, 1, 0.1)); 
    blobbyShader.set("colb", map(currentatt-currentmed, -100, 100, 1, 0));
    showShader();
  } else {
    background(0);
    smooth();
  }

  if (showstrobe) {
    showStrobe();
  }

  if (playsound) {

    if (!playing) {
      oscAtt.play();
      oscMed.play();
      playing=true;
    }

    float freqAtt = getNote(attease, notes_att);
    float ampAtt=map(attease, 0, 100, 0.0, 1.0);
    float addAtt=0.0;
    float posAtt=1;
    oscAtt.set(freqAtt, ampAtt, addAtt, posAtt);


    float freqMed = getNote(medease, notes_med);
    float ampMed=map(medease, 0, 100, 0.0, 1.0);
    float addMed=0.0;
    float posMed=1;
    oscMed.set(freqMed, ampMed, addMed, posMed);

    // println(freqAtt+", "+freqMed);
  }

  if (shownumbers) {
    showNumbers();
  }


  //easing (make the graphs and animation smoother)
  float targetatt = currentatt; 
  float attx = targetatt - attease; 
  attease += attx * easing; 

  float targetmed = currentmed; 
  float medx = targetmed - medease; 
  medease += medx * easing; 


  if (showgraph) {
    plot2.addPoint(timeease, attease);
    plot3.addPoint(timeease, medease);
    //println(plot2.getPoints().getNPoints());
    if (plot2.getPoints().getNPoints()>maxYvalues) {
      plot2.removePoint(0);
      plot3.removePoint(0);
    }
    showGraph();
  }
} 

//end main loop



//functions
float getNote(float input, float[] notearray ) {
  float myNumber = map(input, 0, 100, notearray[0], notearray[notearray.length-1]);
  float distance = abs(notearray[0] - myNumber);
  int idx = 0;
  for (int c = 1; c < notearray.length; c++) {
    float cdistance = abs(notearray[c] - myNumber);
    if (cdistance < distance) {
      idx = c;
      distance = cdistance;
    }
  }
  float note = notearray[idx];
  return note;
}

void showStrobe() {
  if (currentatt >= 80 && millis() - strober > random(200, 2000)) { 
    background(random(255), random(255), random(255)); 
    strober = millis();
  }
} 


void showNumbers() {
  textAlign(LEFT);
  fill(255, 0, 0); 
  if (txtflash) { 
    text("LIVE BRAIN ACTIVITY VISUALIZER", 30, 40);
  } 
  if (millis() - txttimer >= 1000) { 
    txtflash = !txtflash; 
    txttimer = millis();
  } 
  text(stringversion, 30, 70); 
  if (currentsig == 200) { 
    text("Waiting for brain...", 220, 70);
  }     
  if (currentsig == 0) { 
    text("Reading brain...", 220, 70);
  }     
  if (currentsig > 0 && currentsig < 200) { 
    text("Searching for brain...", 220, 70);
  }   

  text("timecode: ", 30, height-50);
  text("signal ", 30, 130);
  text("att. ", 30, 160);
  text("med. ", 30, 190);

  textAlign(RIGHT);

  //calc numbers to display, convert to H:MM:SS:mmm
  int t_hours=int(TimeUnit.MILLISECONDS.toHours(timeease));
  int t_mins=int(TimeUnit.MILLISECONDS.toMinutes(timeease) - 
    TimeUnit.HOURS.toMinutes(TimeUnit.MILLISECONDS.toHours(timeease)));
  int t_secs=int(TimeUnit.MILLISECONDS.toSeconds(timeease) - 
    TimeUnit.MINUTES.toSeconds(TimeUnit.MILLISECONDS.toMinutes(timeease)));
  float t_time = timeease/1000.0;
  float t_millisdec = t_time % 1;
  int t_millis= int(t_millisdec*1000);
  String timecode = nf(t_hours, 1)+":"+ nf(t_mins, 2)+":"+ nf(t_secs, 2)+":"+ nf(t_millis, 3);

  text(timecode, 300, height-50);
  text(currentsig, 160, 130);
  text(currentatt, 160, 160);
  text(currentmed, 160, 190);
}

void showGraph() {
  plot2.beginDraw();
  plot2.drawLines();
  plot2.endDraw();

  plot3.beginDraw();
  plot3.drawLines();
  plot3.endDraw();
}

void showShader() {
  pg.beginDraw();
  pg.shader(blobbyShader); 
  pg.rect(0, 0, pg.width, pg.height); 
  pg.endDraw();
  image(pg, 0, 0);
}


//read all the data form the eeg sensor

void poorSignalEvent(int sig) { 
  signal=sig;
} 

void attentionEvent(int attentionLevel) { 
  attention = attentionLevel;
} 


void meditationEvent(int meditationLevel) { 
  meditation = meditationLevel;
} 

void blinkEvent(int blinkStrength) {
  blink=blinkStrength;
} 

void eegEvent(int delta, int theta, int low_alpha, int high_alpha, int low_beta, int high_beta, int low_gamma, int mid_gamma) { 
  eegdelta=log(delta); 
  eegtheta=log(theta); 
  eegloalpha=low_alpha; 
  eeghialpha=high_alpha; 
  eeglobeta=low_beta; 
  eeghibeta=high_beta; 
  eegmidgamma=mid_gamma; 
  eeglogamma=low_gamma;
} 

void rawEvent(int[] raw) { //we don't use the raw eeg data atm
}  

/// key commands

void keyPressed() { 
  if (key == 's') { 
    println("Saving screenshot..."); 
    String s = nf(number, 4) + "-" + timeease +".png"; 
    //String s = txtdate + "-" + nf(number, 4) +".png"; 
    save(s); 
    number++; 
    println("Done saving.");
  } else if (key == ESC) { 
    println("Exiting..");
    if (recordingmode==true) {
      output.flush(); // Writes the remaining data to the file
      output.close(); // Finishes the file
      try { 
        neuroSocket.stop();
        super.stop();
      } 
      catch (Exception e) { 
        println("Is ThinkGear running??");
      }
    }
    exit(); // Stops the program
  } else if (key == 'f') { 
    place+=10;
    if (place >=arraylength) {
      place=0;
    } 
    println("ff> "+place);
  } else if (key == 'g') { 
    place+=100;
    if (place >=arraylength) {
      place=0;
    } 
    println("ff>> "+place);
  }
} 


void stop() { 
  neuroSocket.stop(); 
  super.stop();
} 
