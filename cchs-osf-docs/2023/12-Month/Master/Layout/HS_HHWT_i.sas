INFILE &datafid. LRECL=30;
INPUT
   @1   SAMPLEID  $22.
   @23  WTS_MHH    8.2; 
run;
