# Polyspace Access Utility

Polyspace Access Utility is a bash script for dealing with basic operations when using Polyspace Access:
- backup
- clean-up
- statistics
- restart
- debug

# Installation

The tool should be installed in a subfolder of the Polyspace Access installation.  
Since it is a simple bash script, there is else nothing to install. It is using the tool whiptail, which is installed by default on most Linux distributions.
If whiptail is not installed, you can install it like this:

```
 sudo apt install whiptail
```

# Usage

Launch the script `access_util.sh` in su mode. The script will then read the Polyspace Access configuration files to get the settings used by Polyspace Access.  
In the menu, use up and down cursor keys to chose the command to be launched then Enter to validate your choice.  
A log file named log.txt is written in case of a problem.


# License

The license for Polyspace Access Utility is available in the LICENSE.TXT file in this GitHub repository.

# Community Support

[MATLAB Central](https://www.mathworks.com/matlabcentral)

Copyright 2023 The MathWorks, Inc.