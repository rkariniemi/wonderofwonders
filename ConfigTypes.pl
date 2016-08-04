#if 0   // don't include header in comments/line count
# ##############################################################################
#    FILE NAME: ConfigTypes.pl
#
#
#  DESCRIPTION:  Select each 1775 PCB and software based FOG product to test using automated perl scripts
#
#
#        NOTES:  This Perl script in conjunction with the TestImu.pl Perl script is used to select each type
#				 of 1775 PCB configuration. It is made to be used with SetSysConfig.pl and TestImu.pl.
#
#
#       Copyright (C) 2014  KVH Industries, Inc.
#                 All rights reserved
#
#       Proprietary Notice: This document contains proprietary information ofh
#       KVH Industries, Inc. and neither the document nor said proprietary
#       information shall be published, reproduced, copied, disclosed or used
#       for any purpose other than the consideration of this document without
#       the expressed written permission of a duly authorized representative
#       of said Company.
#
# ##############################################################################
#endif // don't include header in comments/line count

#! C:\Perl64\bin

use strict;
use warnings;

use Const::Fast;

use constant COLUMNS => qw/ 0 12 24 /;
const my $foo => 'a scalar value';

const my @configTypeStrings => qw/1775IMU
 1750IMU
 1725IMU
 1760DSPU3
 1760DSPU2
 1760DSPU1
 1760DSP3
 1760DSP2
 1760DSP1
 IRS3AXIS /;

 sub Get_Config_Type($) {
        my ($typeNumber) = @_;
        return ($configTypeStrings[$typeNumber]);
}

 1;
