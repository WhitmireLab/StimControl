# PARAMETER FILES
Parameters are read from .csv files. These parameters can be either broad (simply select which types of input/output you would like) or granular (configure channels individually). Currently only granular  config files are supported.

## DAQs
### General Params
- Rate


### Channel Params
DAQ Channel Param files take the following fields and possible values
- daqName (string or blank) - the name of the DAQ. Leave blank for default value. Currently only one DAQ per param file is supported. You can get the names of all DAQs connected to the computer using "daqlist" in the MATLAB terminal.
- index (string or int) - the channel identifier. can be in integer or string form. If in string form, the program will first attempt to parse as an index (e.g. (1:3)), then as a channel name (e.g. 'pf0', 'port0/line7', 'port0/line20:21')
- ioType (string: 'input' / 'output' / 'bidirectional') - the channel type. 
- signalType
