# STIM CONTROL
This repo contains a Matlab-based stimulus/acquisition interfacing program. 
Initially a fork from [WidefieldImager](https://github.com/churchlandlab/WidefieldImager) by the Churchland lab, and incorporating portions of code taken from the [Poulet Lab](https://github.com/poulet-lab)'s QST control program, it aims to provide a fully modular and configurable interface for neural stimulus and imaging.

# Supported Libraries / Hardware
- imaq toolbox (currently gentl and gige have been explicitly tested)
- data acquisition toolbox
- Serial library

# Getting Started
Check out [the wiki](github.com/WhitmireLab/StimControl/wiki) for in-depth explanations for users and developers. The general use flow is:
* Configure session-wide parameters like active hardware and DAQ channel visibility through the config files
* Open StimControl
* configure device parameters in the setup tab if desired, press save if desired
* In the session tab, choose an animal and experiment. Press 'start' to start a full session, or 'start passive' to start a session with all selected devices awaiting triggers