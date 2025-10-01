INFILE &datafid LRECL=29;
INPUT
   @1   SAMPLEID	$20.
   @21  PERSONID	2.
   @23  WTSE_SHH    7.2;	
run;
