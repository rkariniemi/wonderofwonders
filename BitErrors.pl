#if 0   // don't include header in comments/line count
# ##############################################################################
#    FILE NAME: Bit Errors.pl
#
#
#  DESCRIPTION:  Test 1775 PCB and software based FOG products using automated perl scripts for BIT Test
#
#
#        NOTES:  This Perl script in conjunction with the TestImu.pl Perl script is used to identify
#				 any error Bit error that is detected when the ?bit or ?bit2 command is sent to the system.
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
#Software Revision XA Version 02
use strict;
use warnings;

#use Const::Fast;
use Readonly;
use constant COLUMNS => qw/ 0 12 24 /;
Readonly my $foo => 'a scalar value';

# the following Failure Bits are for the 1775 and forward.

Readonly my @bitErrorStrings => qw/FAILED_GYRO_X_SLD
 FAILED_GYRO_X_MODDAC
 FAILED_GYRO_X_PHASE
 FAILED_GYRO_X_COMMS
 FAILED_GYRO_Y_SLD
 FAILED_GYRO_Y_MODDAC
 FAILED_GYRO_Y_PHASE
 RESERVED_0
 FAILED_GYRO_Y_COMMS
 FAILED_GYRO_Z_SLD
 FAILED_GYRO_Z_MODDAC
 FAILED_GYRO_Z_PHASE
 FAILED_GYRO_Z_COMMS
 FAILED_ACCEL_X
 FAILED_ACCEL_Y
 RESERVED_1
 FAILED_ACCEL_Z
 FAILED_GYRO_X_BOBBIN_TEMP
 FAILED_GYRO_X_SLD_TEMP
 FAILED_GYRO_Y_BOBBIN_TEMP
 FAILED_GYRO_Y_SLD_TEMP
 FAILED_GYRO_Z_BOBBIN_TEMP
 FAILED_GYRO_Z_SLD_TEMP
 RESERVED_2
 FAILED_ACCEL_X_TEMP
 FAILED_ACCEL_Y_TEMP
 FAILED_ACCEL_Z_TEMP
 FAILED_GCB_TEMP
 FAILED_ICB_TEMP
 FAILED_GCB_DSP_FLASH
 FAILED_GCB_FPGA_FLASH
 RESERVED_3
 FAILED_ICB_DSP_FLASH
 FAILED_ICB_FPGA_FLASH
 FAILED_GCB_1V2
 FAILED_GCB_3V3
 FAILED_GCB_5V0
 FAILED_ICB_1V2
 FAILED_ICB_3V3
 RESERVED_4
 FAILED_ICB_5V0
 FAILED_ICB_15V0
 FAILED_GCB_FPGA
 FAILED_ICB_FPGA
 FAILED_HIGH_SPEED_SPORT
 FAILED_AUX_SPORT
 FAILED_SW_RESOURCE
 RESERVED_5
 FAILED_GYRO_EOVP
 FAILED_GYRO_EOVN
 FAILED_GYRO_X_VOLTS
 FAILED_GYRO_Y_VOLTS
 FAILED_GYRO_Z_VOLTS
 FAILED_ICB_MAG_FIELD
 FAILED_ICB_MAG_SR_OFFSET
 RESERVED_6
 FAILED_GCB_ADC_COMMS
 FAILED_MSYNC_EXT  /;

Readonly my @bitErrorStringsDSP3 => qw/FAILED_GYRO_X_SLD
 FAILED_GYRO_X_MODDAC
 FAILED_GYRO_X_PHASE
 FAILED_GYRO_X_COMMS
 FAILED_GYRO_Y_SLD
 FAILED_GYRO_Y_MODDAC
 FAILED_GYRO_Y_PHASE
 RESERVED_0
 FAILED_GYRO_Y_COMMS
 FAILED_GYRO_Z_SLD
 FAILED_GYRO_Z_MODDAC
 FAILED_GYRO_Z_PHASE
 FAILED_GYRO_Z_COMMS
 MASKED_ACCEL_X
 MASKED_ACCEL_Y
 RESERVED_1
 MASKED_ACCEL_Z
 FAILED_GYRO_X_BOBBIN_TEMP
 FAILED_GYRO_X_SLD_TEMP
 FAILED_GYRO_Y_BOBBIN_TEMP
 FAILED_GYRO_Y_SLD_TEMP
 FAILED_GYRO_Z_BOBBIN_TEMP
 FAILED_GYRO_Z_SLD_TEMP
 RESERVED_2
 MASKED_ACCEL_X_TEMP
 MASKED_ACCEL_Y_TEMP
 MASKED_ACCEL_Z_TEMP
 FAILED_GCB_TEMP
 FAILED_ICB_TEMP
 FAILED_GCB_DSP_FLASH
 FAILED_GCB_FPGA_FLASH
 RESERVED_3
 FAILED_ICB_DSP_FLASH
 FAILED_ICB_FPGA_FLASH
 FAILED_GCB_1V2
 FAILED_GCB_3V3
 FAILED_GCB_5V0
 FAILED_ICB_1V2
 FAILED_ICB_3V3
 RESERVED_4
 FAILED_ICB_5V0
 FAILED_ICB_15V0
 FAILED_GCB_FPGA
 FAILED_ICB_FPGA
 FAILED_HIGH_SPEED_SPORT
 FAILED_AUX_SPORT
 FAILED_SW_RESOURCE
 RESERVED_5
 FAILED_GYRO_EOVP
 FAILED_GYRO_EOVN
 FAILED_GYRO_X_VOLTS
 FAILED_GYRO_Y_VOLTS
 FAILED_GYRO_Z_VOLTS
 FAILED_ICB_MAG_FIELD
 FAILED_ICB_MAG_SR_OFFSET
 RESERVED_6
 FAILED_GCB_ADC_COMMS
 FAILED_MSYNC_EXT  /;

Readonly my @bitErrorStringsDSP2 => qw/FAILED_GYRO_X_SLD
 FAILED_GYRO_X_MODDAC
 FAILED_GYRO_X_PHASE
 FAILED_GYRO_X_COMMS
 MASKED_GYRO_Y_SLD
 MASKED_GYRO_Y_MODDAC
 MASKED_GYRO_Y_PHASE
 RESERVED_0
 MASKED_GYRO_Y_COMMS
 FAILED_GYRO_Z_SLD
 FAILED_GYRO_Z_MODDAC
 FAILED_GYRO_Z_PHASE
 FAILED_GYRO_Z_COMMS
 MASKED_ACCEL_X
 MASKED_ACCEL_Y
 RESERVED_1
 MASKED_ACCEL_Z
 FAILED_GYRO_X_BOBBIN_TEMP
 FAILED_GYRO_X_SLD_TEMP
 MASKED_GYRO_Y_BOBBIN_TEMP
 MASKED_GYRO_Y_SLD_TEMP
 FAILED_GYRO_Z_BOBBIN_TEMP
 FAILED_GYRO_Z_SLD_TEMP
 RESERVED_2
 MASKED_ACCEL_X_TEMP
 MASKED_ACCEL_Y_TEMP
 MASKED_ACCEL_Z_TEMP
 FAILED_GCB_TEMP
 FAILED_ICB_TEMP
 FAILED_GCB_DSP_FLASH
 FAILED_GCB_FPGA_FLASH
 RESERVED_3
 FAILED_ICB_DSP_FLASH
 FAILED_ICB_FPGA_FLASH
 FAILED_GCB_1V2
 FAILED_GCB_3V3
 FAILED_GCB_5V0
 FAILED_ICB_1V2
 FAILED_ICB_3V3
 RESERVED_4
 FAILED_ICB_5V0
 FAILED_ICB_15V0
 FAILED_GCB_FPGA
 FAILED_ICB_FPGA
 FAILED_HIGH_SPEED_SPORT
 FAILED_AUX_SPORT
 FAILED_SW_RESOURCE
 RESERVED_5
 FAILED_GYRO_EOVP
 FAILED_GYRO_EOVN
 FAILED_GYRO_X_VOLTS
 MASKED_GYRO_Y_VOLTS
 FAILED_GYRO_Z_VOLTS
 FAILED_ICB_MAG_FIELD
 FAILED_ICB_MAG_SR_OFFSET
 RESERVED_6
 FAILED_GCB_ADC_COMMS
 FAILED_MSYNC_EXT  /;
 
 Readonly my @bitErrorStringsDSP1 => qw/MASKED_GYRO_X_SLD
 MASKED_GYRO_X_MODDAC
 MASKED_GYRO_X_PHASE
 MASKED_X_COMMS
 MASKED_GYRO_Y_SLD
 MASKED_GYRO_Y_MODDAC
 MASKED_GYRO_Y_PHASE
 RESERVED_0
 MASKED_GYRO_Y_COMMS
 FAILED_GYRO_Z_SLD
 FAILED_GYRO_Z_MODDAC
 FAILED_GYRO_Z_PHASE
 FAILED_GYRO_Z_COMMS
 MASKED_ACCEL_X
 MASKED_ACCEL_Y
 RESERVED_1
 MASKED_ACCEL_Z
 MASKED_X_BOBBIN_TEMP
 MASKED_GYRO_X_SLD_TEMP
 MASKED_GYRO_Y_BOBBIN_TEMP
 MASKED_GYRO_Y_SLD_TEMP
 FAILED_GYRO_Z_BOBBIN_TEMP
 FAILED_GYRO_Z_SLD_TEMP
 RESERVED_2
 MASKED_ACCEL_X_TEMP
 MASKED_ACCEL_Y_TEMP
 MASKED_ACCEL_Z_TEMP
 FAILED_GCB_TEMP
 FAILED_ICB_TEMP
 FAILED_GCB_DSP_FLASH
 FAILED_GCB_FPGA_FLASH
 RESERVED_3
 FAILED_ICB_DSP_FLASH
 FAILED_ICB_FPGA_FLASH
 FAILED_GCB_1V2
 FAILED_GCB_3V3
 FAILED_GCB_5V0
 FAILED_ICB_1V2
 FAILED_ICB_3V3
 RESERVED_4
 FAILED_ICB_5V0
 FAILED_ICB_15V0
 FAILED_GCB_FPGA
 FAILED_ICB_FPGA
 FAILED_HIGH_SPEED_SPORT
 FAILED_AUX_SPORT
 FAILED_SW_RESOURCE
 RESERVED_5
 FAILED_GYRO_EOVP
 FAILED_GYRO_EOVN
 MASKED_GYRO_X_VOLTS
 MASKED_GYRO_Y_VOLTS
 FAILED_GYRO_Z_VOLTS
 FAILED_ICB_MAG_FIELD
 FAILED_ICB_MAG_SR_OFFSET
 RESERVED_6
 FAILED_GCB_ADC_COMMS
 FAILED_MSYNC_EXT  /;

 sub Get_Bit_String($) {
        my ($bitNumber) = @_;
        return ($bitErrorStrings[$bitNumber]);
}


 sub Get_Bit_StringSize {

    my $arrSize = @bitErrorStrings;
    print "bitErrorStringsDSP3 size  = $arrSize \n";
    return ($arrSize);
}

 sub Get_Bit_String_DSP3($) {
        my ($bitNumber) = @_;
        return ($bitErrorStringsDSP3[$bitNumber]);
}


 sub Get_Bit_StringSize_DSP3 {

    my $arrSize = @bitErrorStringsDSP3;
    print "bitErrorStringsDSP3 size  = $arrSize \n";
    return ($arrSize);
}
 
 sub Get_Bit_String_DSP2($) {
        my ($bitNumber) = @_;
        return ($bitErrorStringsDSP2[$bitNumber]);
}


 sub Get_Bit_StringSize_DSP2 {

    my $arrSize = @bitErrorStringsDSP2;
    print "bitErrorStringsDSP2 size  = $arrSize \n";
    return ($arrSize);
} 

 sub Get_Bit_String_DSP1($) {
        my ($bitNumber) = @_;
        return ($bitErrorStringsDSP1[$bitNumber]);
}


 sub Get_Bit_StringSize_DSP1 {

    my $arrSize = @bitErrorStringsDSP1;
    print "bitErrorStringsDSP1 size  = $arrSize \n";
    return ($arrSize);
}

1;
