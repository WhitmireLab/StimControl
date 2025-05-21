# PARAMETER FILES
Parameters are read from .csv files. These parameters can be either broad (simply select which types of input/output you would like) or granular (configure channels individually). Currently only granular  config files are supported.

## DAQs
### General Params
Information for DAQ parameters can be found [here](https://au.mathworks.com/help/daq/daq.html#d126e10400)
- Vendor (string: "ni" / "adi" / "mcc" / "directsound" / "digilent") - the device vendor
- Rate


### Channel Params
DAQ Channel Param files take the following fields and possible values. Information about DAQ channel configuration can be found [here](https://au.mathworks.com/help/daq/daq.interfaces.dataacquisition.addinput.html)
- deviceID (string or blank) - the name of the DAQ. Leave blank for default value. Currently only one DAQ per param file is supported. You can get the names of all DAQs connected to the computer using "daqlist" in the MATLAB terminal.
- portNum (string or int) - the channel identifier. e.g. '1', pf0', 'port0/line7', 'port0/line20:21'
- ioType (string: 'input' / 'output' / 'bidirectional') - the channel type. 
- signalType (string: 
    - input: 'Voltage'/ 'Current'/ 'Thermocouple'/ 'Accelerometer'/ 'RTD'/ 'Bridge'/ 'Microphone'/ 'IEPE'/ 'Digital'/ 'EdgeCount'/ 'Frequency'/ 'PulseWidth'/ 'Position'/ 'Audio'
    - output: 'Voltage'/ 'Current'/ 'Digital'/ 'PulseGeneration'/ 'Audio'/ 'Sine'/ 'Square'/ 'Triangle'/ 'RampUp'/ 'RampDown'/ 'DC'/ 'Arbitrary'
    - bidirectional)
