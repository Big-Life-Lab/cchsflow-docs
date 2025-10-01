INFILE &datafid. LRECL=27;
INPUT
   @1   SAMPLEID	$20.
   @21  WTS_SHH    7.2;	
run;
