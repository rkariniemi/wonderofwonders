#if 0   // don't include header in comments/line count
# ##############################################################################
#    FILE NAME:  BitErrorValues.pl
#
#
#  DESCRIPTION:  Test 1775 PCB and software based FOG products using automated perl scripts for BIT Test
#
#
#        NOTES:  This Perl script in conjunction with the TestImu.pl and BitErrors.pl Perl scripts verifies the bittest command
#				 which allows the user to overwrite the system status bits to verify that errors in the system are detected correctly.
#
#
#       Copyright (C) 2014  KVH Industries, Inc.
#                 All rights reserved
#
#       Proprietary Notice: This document contains proprietary information of
#       KVH Industries, Inc. and neither the document nor said proprietary
#       information shall be published, reproduced, copied, disclosed or used
#       for any purpose other than the consideration of this document without
#       the expressed written permission of a duly authorized representative
#       of said Company.
#
# ##############################################################################
#endif // don't include header in comments/line count

#! C:\Perl64\bin
#software Revision XA Version 02
use strict;
use warnings;

#use Const::Fast;
use Readonly;
use constant COLUMNS => qw/ 0 12 24 /;
Readonly my $foo => 'a scalar value';

Readonly my @bitErrorValues => qw/0x7f7f7f7e
 0x7f7f7f7d
 0x7f7f7f7b
 0x7f7f7f77
 0x7f7f7f6f
 0x7f7f7f5f
 0x7f7f7f3f
 0x7f7f7e7f
 0x7f7f7d7f
 0x7f7f7b7f
 0x7f7f777f
 0x7f7f6f7f
 0x7f7f5f7f
 0x7f7f3f7f
 0x7f7e7f7f
 0x7f7d7f7f
 0x7f7b7f7f
 0x7f777f7f
 0x7f6f7f7f
 0x7f5f7f7f
 0x7f3f7f7f
 0x7e7f7f7f
 0x7d7f7f7f
 0x7b7f7f7f
 0x777f7f7f
 0x6f7f7f7f
 0x5f7f7f7f
 0x3f7f7f7f/;

# the following Failure Bits are for the 1775 PCB and software based FOG systems and forward.


 sub Get_Bit_Error_String($) {
        my ($bitNumber) = @_;
        return ($bitErrorValues[$bitNumber]);
}


 sub Get_Bit_Error_StringSize {

    my $arrSize = @bitErrorValues;
    print "bitErrorValuesString size  = $arrSize \n";
    return ($arrSize);
}

1;
