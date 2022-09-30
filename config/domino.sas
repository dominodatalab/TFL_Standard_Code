/******************************************************************************
*  ____                  _
* |  _ \  ___  _ __ ___ (_)_ __   ___
* | | | |/ _ \| '_ ` _ \| | '_ \ / _ \
* | |_| | (_) | | | | | | | | | | (_) |
* |____/ \___/|_| |_| |_|_|_| |_|\___/
* ____________________________________________________________________________
* Sponsor              : Domino
* Compund              : -
* Study                : -
* Analysis             : -
* Program              : domino.sas
* ____________________________________________________________________________
* DESCRIPTION 
*
* This is the standard Domino SAS setup file and contains definitions that
* are used across the reporting effort. 
*
* DO NOT EDIT THIS FILE WITHOUT PRIOR APPROVAL 
*
* Program description:
* 0. Read environment variables
* 1. Set global pathname macro variables
* 2. Define standard libraries
*                                                                   
* Input files:
* - none
* 
* Input Environment Variables:
* - DOMINO_PROJECT_NAME
* - DOMINO_WORKING_DIR
* - DCUTDTC
*
* Outputs:                                                   
* - global variables defined
* - SAS Libnames defined
* - sasautos path set for shared macros
*
* Macros: 
* - none
*
* Assumptions: 
* - Must be run on the Domino platform (assumes Domino environment vars)
* ____________________________________________________________________________
* PROGRAM HISTORY                                                         
*  2022-06-06  | Stuart.Malcolm  | Program created
*  2022-09-28  | Stuart.Malcolm  | Ported code to TFL_Standard_Repo 
* ----------------------------------------------------------------------------
*  YYYYMMDD  |  username        | ..description of change..         
*****************************************************************************/

%macro __setup();

* global constants - USER CONFIGURABLE. Change these here if needed;

* Location of Domino Datasets folders that are defined in this project;
* Likely to change depending whether project is DFS or Git hosted;
%global __localdata_path;
%let __localdata_path = /domino/datasets/local;

* globals read in from env vars; 
%global __WORKING_DIR  ; * path to root of working directory ;
%global __PROJECT_NAME ; * project name <PROTOCOL>_<TYPE> ;
%global __DCUTDTC      ; * cutoff date in ISO8901 format ;

* globals derived from env vars;
%global __PROTOCOL;      * Protocol identifier e.g H2QMCLZZT; 
%global __PROJECT_TYPE ; * project type: SDTM | ADAM | TFL ;

* other globals exported by setup;
%global __prog_path;     * full path to the program being run;
%global __prog_name;     * filename (without extension) of program;
%global __prog_ext;      * extension of program (usuall sas);

%global __full_path;     * full path and filename ;
%global __runmode;       * INTERACTIVE or BATCH (or UNKNOWN);

* ==================================================================;
* grab the environment varaibles that we need to create pathnames;
* ==================================================================;
%let __WORKING_DIR  = %sysget(DOMINO_WORKING_DIR);
%let __PROJECT_NAME = %sysget(DOMINO_PROJECT_NAME);
%let __DCUTDTC      = %sysget(DCUTDTC);
* runtime check that e.g. DCUTDTC is not missing;
%if &__DCUTDTC. eq %str() %then %put %str(ER)ROR: Envoronment Variable DCUTDTC not set;

* ==================================================================;
* extract the protocol and project type from the project name;
* ==================================================================;
%if %sysfunc(find(&__PROJECT_NAME.,_)) ge 1 %then %do;
  %let __PROTOCOL     = %scan(&__PROJECT_NAME.,1,'_');
  %let __PROJECT_TYPE = %scan(&__PROJECT_NAME.,2,'_');
  %end;
%else %do;
  %put %str(ER)ROR: Project Name (DOMINO_PROJECT_NAME) ill-formed. Expecting <PROTOCOL>_<TYPE> ;
%end;

* ==================================================================;
* define library locations - these are dependent on the project type;
* ==================================================================;

* SDTM ;
* ------------------------------------------------------------------;
%if %sysfunc(find(%upcase(&__PROJECT_TYPE.),SDTM)) ge 1 %then %do;
  * Local read/write access to SDTM and QC folders ;
  libname SDTM   "&__localdata_path./SDTM";
  libname SDTMQC "&__localdata_path./SDTMQC";
  libname SDTMQC "&__localdata_path./RAW";
%end;

* TFL ;
* ------------------------------------------------------------------;
* this must come before ADAM code block so that combines ADAM+TFL ;
* projects hasve the ADAM librry defined last (i.e. local not imported snapshot);
%if %sysfunc(find(%upcase(&__PROJECT_TYPE.),TFL)) ge 1 %then %do;
  * imported read-only access to ADaM folder;
  libname ADAM "/mnt/imported/data/ADAM" access=readonly;
  * local read/write for TFL datasets ;
  libname TFL   "&__localdata_path./TFL";
  libname TFLQC "&__localdata_path./TFLQC";
%end;

* ADAM ;
* ------------------------------------------------------------------;
%if %sysfunc(find(%upcase(&__PROJECT_TYPE.),ADAM)) ge 1 %then %do;
  * imported read-only SDTM data, using the data cutoff date.. ;
  * ..to identify the correct snapshot to use ;
  libname SDTM "/domino/datasets/snapshots/SDTM/SDTM_&__DCUTDTC." access=readonly;
  * local read/write acces to ADaM and QC folders;
  libname ADAM   "&__localdata_path./ADAM";
  libname ADAMQC "&__localdata_path./ADAMQC";
%end;


* RunAll ;
* ------------------------------------------------------------------;
%if %sysfunc(find(%upcase(&__PROJECT_TYPE.),RUNALL)) ge 1 %then %do;
  * imported read-only SDTM data, using the data cutoff date.. ;
  * ..to identify the correct snapshot to use ;
  libname SDTM "/mnt/imported/data/snapshots/SDTM/SDTM_&__DCUTDTC." access=readonly;
  * local read/write acces to ADaM and QC folders;
  libname ADAM   "&__localdata_path./ADAM";
  libname ADAMQC "&__localdata_path./ADAMQC";
  * local read/write for TFL datasets ;
  libname TFL   "&__localdata_path./TFL";
  libname TFLQC "&__localdata_path./TFLQC";
%end;

* ==================================================================;
* Set SASAUTOS to search for shared macros ;
* ==================================================================;
options
  MAUTOSOURCE
  MAUTOLOCDISPLAY 
  sasautos=("/repos/SDTM_Standard_Code/share/macros","/repos/TFL_Standard_Code/share/macros","/mnt/share/macros",SASAUTOS) ;

* ==================================================================;
* Determine if we are running Interactive or Batch ;
* ==================================================================;

* default position is that we dont know how program is running;
%let __runmode=UNKNOWN;

%* ------------------------------------------------------------------;
%* Are we running in INTERACTIVE mode? ;
%* Check for macro var _SASPROGRAMFILE. only present in SAS Studio ;
%* ------------------------------------------------------------------;
   %if %symexist(_SASPROGRAMFILE) %then %do;
      %let __full_path = %str(&_SASPROGRAMFILE.);
      %let __runmode=INTERACTIVE;
      %put %str(TR)ACE: (domino.sas) Running in SAS Studio.;
   %end;

%* ------------------------------------------------------------------;
%* Are we running in BATCH mode? ;
%* Check for Operating System parameter SYSIN. This parameter indicates batch execution ;
%* ------------------------------------------------------------------;
   %else %if %quote(%sysfunc(getoption(sysin))) ne %str() %then %do;
      %let __full_path = %quote(%sysfunc(getoption(sysin)));
      %let __runmode=BATCH;
      %put %str(TR)ACE: (domino.sas) Running in BATCH SAS.;
   %end;

%* Runtime check that we can identify runtime mode;
%if &__full_path eq %str() %then %put %str(WAR)NING: Cannot determine program name;

* ------------------------------------------------------------------;
* get program name, path and extension ;
* ------------------------------------------------------------------;
%local filename;
%* scan from right to left for first backslash. ;
%* everything to the right of that slash is filename with extension. ;
%let filename = %scan(&__full_path, -1, /);

%* find the numeric position of the filename. ;
%* everything to up to that point (minus 1) is the folder. ;
%let __prog_path= %substr(&__full_path., 1, %index(&__full_path., &filename.) - 1);

%* isolate filename as everything up to but not including the period. ;
%let __prog_name = %scan(&filename, 1, .);

%* everything after the period is the extension. ;
%let __prog_ext = %scan(&filename, 2, .);

* ==================================================================;
* Redirect log files (BATCH MODE ONLY);
* ==================================================================;
%if &__runmode eq %str(BATCH) %then %do;
  * Redirect SAS LOG files when in batch mode;
  *PROC PRINTTO LOG="&__WORKING_DIR./logs/&__prog_name..log" NEW;
%end;

%mend __setup;
* invoke the setup macro - so user program only needs to include this file;
%__setup;

* ==================================================================;
* write to log for traceability ;
* this is done outside the setup macro to ensure global vars are defined;
* ==================================================================;
%put TRACE: (domino.sas) [__WORKING_DIR = &__WORKING_DIR.] ;
%put TRACE: (domino.sas) [__PROJECT_NAME = &__PROJECT_NAME.];
%put TRACE: (domino.sas) [__DCUTDTC = &__DCUTDTC.];
%put TRACE: (domino.sas) [__PROTOCOL = &__PROTOCOL.];
%put TRACE: (domino.sas) [__PROJECT_TYPE = &__PROJECT_TYPE.];
%put TRACE: (domino.sas) [__localdata_path = &__localdata_path.];
%put TRACE: (domino.sas) [__prog_path = &__prog_path.];
%put TRACE: (domino.sas) [__prog_name = &__prog_name.];
%put TRACE: (domino.sas) [__prog_ext = &__prog_ext.];

* List all the libraries that are currently defined;
libname _all_ list;

*EOF;
