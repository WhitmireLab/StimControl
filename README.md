# STIM CONTROL
This repo contains a Matlab-based stimulus/acquisition interfacing program. 
Initially a fork from [WidefieldImager](https://github.com/churchlandlab/WidefieldImager) by the Churchland lab, and incorporating portions of code taken from the Whitmire Lab's QST control program, it aims to provide a fully modular and configurable interface for neural stimulus and imaging.

# NOTES FOR USERS
## PROTOCOL FILES
In development. See ProtocolFiles for current setup.

## PARAMETER FILES
Parameters are read from .csv files. These parameters can be either broad (simply select which types of input/output you would like) or granular (configure channels individually). Currently only granular  config files are supported.

### DAQs
#### General Params
Information for DAQ parameters can be found [here](https://au.mathworks.com/help/daq/daq.html#d126e10400)
- Vendor (string: "ni" / "adi" / "mcc" / "directsound" / "digilent") - the device vendor
- Rate

#### Channel Params
DAQ Channel Param files take the following fields and possible values. Information about DAQ channel configuration can be found [here](https://au.mathworks.com/help/daq/daq.interfaces.dataacquisition.addinput.html)
- deviceID (string or blank) - the name of the DAQ. Leave blank for default value. Currently only one DAQ per param file is supported. You can get the names of all DAQs connected to the computer using "daqlist" in the MATLAB terminal.
- portNum (string or int) - the channel identifier. e.g. '1', pf0', 'port0/line7', 'port0/line20:21'
- ioType (string: 'input' / 'output' / 'bidirectional') - the channel type. 
- signalType (string: 
    - input: 'Voltage'/ 'Current'/ 'Thermocouple'/ 'Accelerometer'/ 'RTD'/ 'Bridge'/ 'Microphone'/ 'IEPE'/ 'Digital'/ 'EdgeCount'/ 'Frequency'/ 'PulseWidth'/ 'Position'/ 'Audio'
    - output: 'Voltage'/ 'Current'/ 'Digital'/ 'PulseGeneration'/ 'Audio'/ 'Sine'/ 'Square'/ 'Triangle'/ 'RampUp'/ 'RampDown'/ 'DC'/ 'Arbitrary'
    - bidirectional)


# NOTES FOR DEVELOPERS
## General Notes
I'm not a native MATLAB developer, so I've found it helpful to put comments in functions of the documentation that I found useful when building that function. 

## Adding New Hardware
New hardware components should implement the HardwareComponent abstract class (which outlines required functions and properties), and have their defaults written in a struct of named Component Properties. 

### Component Properties
Component properties are defined per hardware component. A ComponentProperties struct is a struct of named Component Properties.Each Component Property is a struct with 5 fields: 
|Field          |Required   |Description|
|-----          |-----      |-----|
|default        |required   |Default value for the field|
|allowable      |optional   |Allowable values for the field. Should be a cell array.|
|validatefcn    |optional   |Validation function handle for inserted value. Takes value as arg. If allowable is set, will also check value's membership|
|dependencies   |optional   |Validation function handle for requirements for field to be set. Takes full struct as arg.|
|required       |required   |Function handle that returns hether a field needs to be set. Takes full struct as arg. Will only be evaluated if dependencies evaluates to true.|
|note           |optional   |Basically comments.|

## To Do List
### General
- GUI that spits out hardware parameters and protocol
- Implement additional hardware: Aurora serial
- See about making a generic inspect() style interface for all components [(see here)](https://au.mathworks.com/help/instrument/generic-instrument-drivers.html?s_tid=CRUX_lftnav)
- add ability to repeat stimulus independently within a trial
- I don't looove that the component defaults are hardcoded but they're also not really hardcoded? maybe if we just add the option to ignore defaults we should be fine?

### Widefield GUI
- jank when changing bin size / folders / etc.
- creating new animal may also create erroneous experiment folders if you're ALSO changing experiment
- Session param saving! (nb this should be done in matlab)
- ROI masking
- be able to also see deltaF/F (set pre-stim time and set average for pre-stim as zero) (for fluorescence trace: (F - F0) / F0)

### Camera
- Visualisation: Inticator when saturation / brightness is reaching full intensity so we know to adjust gain / light
- Figure out the buffering issues for multi-image-per-trigger acquisition, maybe thread it (check [imaq documentation](https://au.mathworks.com/help/imaq/videoinput.html) and [parallel computing documentation](https://au.mathworks.com/help/parallel-computing/quick-start-parallel-computing-in-matlab.html))

### DAQ
- get session loading working
- add parametrised analog outputs - ramp, noise, sine