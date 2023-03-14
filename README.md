<!--
Copyright (c) 2023 The MathWorks, Inc.
All Rights Reserved.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
-->

# Polyspace Access Utility

Polyspace Access Utility is a bash script for dealing with basic operations when using Polyspace® Access&trade;:
- backup
- clean-up
- statistics
- restart
- debug

The script is compatible with Polyspace Access R2022a, R2022b and R2023a

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
