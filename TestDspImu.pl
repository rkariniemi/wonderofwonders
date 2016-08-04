#if 0   // don't include header in comments/line count
# ##############################################################################
#    FILE NAME:  TestDspImu.pl
#
#
#  DESCRIPTION:  Test a DSP or IMU device using automated perl scripts;
#
#
#        NOTES:  These tests are for devices based on the 1775 IMU SW and board set
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

use strict;
use warnings;

use Win32::SerialPort;
use Time::Piece;
use Time::HiRes qw[gettimeofday tv_interval];
use Text::CSV_XS;
use File::Copy;
use Cwd;
use Readonly;
use File::Compare;
use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
use Diagnostics;
use CGI::Fast;
use IO::Handle;
# We will use the scripts below to process the BIT command test and the BITTEST
# The BITEST Test is only run by user request with the -BIT option and is not really a part of the
# automated test as it takes a long time to run and we seperated it out puposefully
# Note: BitErrors.pl and BitErrorValues.pl need to be in the directory where this test script 
# is run from.
 
require 'BitErrors.pl'; #Required for BITTEST test
require 'BitErrorValues.pl'; #Required for BITTEST test
#Note: Text file testsequence.txt is required for TestAxisRotation test
#Note: TestFilterFiles folder (and all text files in it) is required for TestFilt test 
################### Constants  ########################################

# constants are defined by using CAPS and underbars
# version and revision should change anytime there is a change in the scripts.
Readonly::Scalar my $VERSION  => "XA";
Readonly::Scalar my $REVISION  => "0.21";

#  IMU Variants
Readonly::Scalar my $IMU1775IMU  => "1775IMU";
Readonly::Scalar my $DSP1760_1   => "1760DSP1";
Readonly::Scalar my $DSP1760_2   => "1760DSP2";
Readonly::Scalar my $DSP1760_3   => "1760DSP3";
Readonly::Scalar my $IMU1750IMU  => "1750IMU";
Readonly::Scalar my $IMU1725IMU  => "1725IMU";

Readonly::Scalar my $DSP1760_1U  => "1760DSPU1";
Readonly::Scalar my $DSP1760_2U  => "1760DSPU2";
Readonly::Scalar my $DSP1760_3U  => "1760DSPU3";

# 1775 IMU Support
Readonly::Scalar my $FC20_A_CHEBY  => "FC20,A,-1.138633489609,+0.337049782276,+0.092850729823,+0.012714813463,+0.092850737274\r\n     -1.395040988922,+0.552889108658,+0.318473041058,-0.479098021984,+0.318473070860\r\n     -1.640967369080,+0.765086650848,+0.522430896759,-0.920742452145,+0.522430896759\r\n     -1.814886569977,+0.926091849804,+0.640401542187,-1.169597864151,+0.640401721001\r\n";
Readonly::Scalar my $FC20_G_CHEBY  => "FC20,G,-1.599482536316,+0.643328189850,+0.067608766258,-0.091371893883,+0.067608781159\r\n     -1.748315811157,+0.780189573765,+0.341927200556,-0.651980519295,+0.341927081347\r\n     -1.870245933533,+0.893383502960,+0.548774719238,-1.074411749840,+0.548774600029\r\n     -1.948574304581,+0.968216598034,+0.646299600601,-1.272957086563,+0.646299779415\r\n";

Readonly::Scalar my $FC20_A_BUTTER => "FC20,A,-1.364886999130,+0.468523174524,+0.025909043849,+0.051818087697,+0.025909043849\r\n     -1.422433137894,+0.530438959599,+0.027001453564,+0.054002907127,+0.027001453564\r\n     -1.542610883713,+0.659741759300,+0.029282720760,+0.058565441519,+0.029282720760\r\n     -1.734025955200,+0.865691006184,+0.032916266471,+0.065832532942,+0.032916266471\r\n";
Readonly::Scalar my $FC20_G_BUTTER => "FC20,G,-1.712612628937,+0.733960628510,+0.005336999428,+0.010673998855,+0.005336999428\r\n     -1.748011827469,+0.769801020622,+0.005447298754,+0.010894597508,+0.005447298754\r\n     -1.817424297333,+0.840078651905,+0.005663588643,+0.011327177286,+0.005663588643\r\n     -1.916875600815,+0.940769672394,+0.005973517895,+0.011947035789,+0.005973517895\r\n";

# 1750 IMU 1725 IMU and DSP 1760 Support
Readonly::Scalar my $FC_A_CHEBY  => "FC,A,-1.138633489609,+0.337049782276,+0.092850729823,+0.012714813463,+0.092850737274\r\n     -1.395040988922,+0.552889108658,+0.318473041058,-0.479098021984,+0.318473070860\r\n     -1.640967369080,+0.765086650848,+0.522430896759,-0.920742452145,+0.522430896759\r\n     -1.814886569977,+0.926091849804,+0.640401542187,-1.169597864151,+0.640401721001\r\n";
Readonly::Scalar my $FC_G_CHEBY  => "FC,G,-1.261740446091,+0.408295989037,+0.083280630410,-0.020005717874,+0.083280637860\r\n     -1.496196269989,+0.610108315945,+0.322479069233,-0.531046152115,+0.322479158640\r\n     -1.711938619614,+0.799575090408,+0.528525292873,-0.969414055347,+0.528525292873\r\n     -1.860565900803,+0.937896430492,+0.641346275806,-1.205362200737,+0.641346335411\r\n";

Readonly::Scalar my $FC_A_BUTTER => "FC,A,-1.364886999130,+0.468523174524,+0.025909043849,+0.051818087697,+0.025909043849\r\n     -1.422433137894,+0.530438959599,+0.027001453564,+0.054002907127,+0.027001453564\r\n     -1.542610883713,+0.659741759300,+0.029282720760,+0.058565441519,+0.029282720760\r\n     -1.734025955200,+0.865691006184,+0.032916266471,+0.065832532942,+0.032916266471\r\n";
Readonly::Scalar my $FC_G_BUTTER => "FC,G,-1.459706068039,+0.534825861454,+0.018779948354,+0.037559896708,+0.018779948354\r\n     -1.513291120529,+0.591168344021,+0.019469305873,+0.038938611746,+0.019469305873\r\n     -1.623405694962,+0.706949830055,+0.020886035636,+0.041772071272,+0.020886035636\r\n     -1.793962001801,+0.886283278465,+0.023080321029,+0.046160642058,+0.023080321029\r\n";

# the custom coefficients were generated from the fc20,a and fc20,g commands at dr=1000 and
# were changed a little to insure they are not exacxtly the same as the generated values
# and also insuring they do not inject unity gain errors
Readonly::Scalar my $FC20_A_CUSTOM_COMMAND => "=FC20,a,-1.4597,0.5348,0.0188,0.0376,0.0188,-1.5133,0.5912,0.0195,0.0389,0.0195,-1.6234,0.7069,0.0209,0.0418,0.0209,-1.7940,0.8862,0.0231,0.0462,0.0233";
Readonly::Scalar my $FC20_G_CUSTOM_COMMAND => "=FC20,g,-1.5994,0.6433,0.0676,-0.0913,0.0676,-1.7483,0.7801,0.3419,-0.6519,0.3419,-1.8702,0.8934,0.5488,-1.0744,0.5488,-1.9486,0.9682,0.6463,-1.2730,0.6463";

# these are the 1750 versions of the fc20 commands
Readonly::Scalar my $FC_A_CUSTOM_COMMAND => "=FC,a,-1.4597,0.5348,0.0188,0.0376,0.0188,-1.5133,0.5912,0.0195,0.0389,0.0195,-1.6234,0.7069,0.0209,0.0418,0.0209,-1.7940,0.8862,0.0231,0.0462,0.0233";
Readonly::Scalar my $FC_G_CUSTOM_COMMAND => "=FC,g,-1.5994,0.6433,0.0676,-0.0913,0.0676,-1.7483,0.7801,0.3419,-0.6519,0.3419,-1.8702,0.8934,0.5488,-1.0744,0.5488,-1.9486,0.9682,0.6463,-1.2730,0.6463";


Readonly::Scalar my $NORMAL_FORMAT_A_SIZE => 36;
Readonly::Scalar my $NORMAL_FORMAT_B_SIZE => 40;
Readonly::Scalar my $NORMAL_FORMAT_C_SIZE => 38;

Readonly::Scalar my $FORMAT_A_HEADER => "fe81ff55";
Readonly::Scalar my $FORMAT_B_HEADER => "fe81ff56";
Readonly::Scalar my $FORMAT_C_HEADER => "fe81ff57";

Readonly::Scalar my $FORMAT_BIT_A_HEADER => "fe8100aa";
Readonly::Scalar my $FORMAT_BIT_B_HEADER => "fe8100ab";

Readonly::Scalar my $FORMAT_INVALID_PACKET => "FFFFFFF";

Readonly::Scalar my $RESERVED_BITTEST_ERROR => "RESERVED";


Readonly::Scalar my $FORMAT_BIT_A_RESULT => "7f7f7f7f7f7f";
Readonly::Scalar my $FORMAT_BIT_B_RESULT => "7f7f7f7f7f7f7f7f";

Readonly::Scalar my $FORMAT_BIT_A_SIZE => 11;
Readonly::Scalar my $FORMAT_BIT_B_SIZE => 13;
Readonly::Scalar my $FORMAT_BIT_TEST_SIZE => 4;

Readonly::Scalar my $FORMATA_BIT_ERROR_SIZE => 48;

# locations of values in the packet array using Format A Packets
Readonly::Scalar my $HEADER_LOCATION => 0;
Readonly::Scalar my $GYROX_LOCATION => 1;
Readonly::Scalar my $GYROY_LOCATION => 2;
Readonly::Scalar my $GYROZ_LOCATION => 3;

Readonly::Scalar my $ACCELX_LOCATION => 4;
Readonly::Scalar my $ACCELY_LOCATION => 5;
Readonly::Scalar my $ACCELZ_LOCATION => 6;
Readonly::Scalar my $STATUS_SEQ_TEMP_LOCATION => 7;

# these tabs are used to make viewing the output to the console more readable

Readonly::Scalar my $THREE_TABS  => "\t\t\t";
Readonly::Scalar my $FIVE_TABS  => "\t\t\t\t\t";
Readonly::Scalar my $SIX_TABS   => "\t\t\t\t\t\t";
Readonly::Scalar my $EIGHT_TABS => "\t\t\t\t\t\t\t\t";

# We will use the convention that a return of a function for success is one (1) and failure is zero (0)
Readonly::Scalar my $SUCCESS => 1;
Readonly::Scalar my $FAILED => 0;

# We will use the mode command syntax as zero (0) tor turn off the mode and one (1) to enter the mode
Readonly::Scalar my $SETMODEOFF=> 0;
Readonly::Scalar my $SETMODEON => 1;

# We will use the mode command syntax as zero (0) tor turn off the mode and one (1) to enter the mode
Readonly::Scalar my $SETLOGSOFF=> 0;
Readonly::Scalar my $SETLOGSON => 1;

# Modes of the device
Readonly::Scalar my $DEBUG_MODE=> 0;
Readonly::Scalar my $DEVEL_MODE=> 1;
Readonly::Scalar my $CONFIG_MODE=> 2;
Readonly::Scalar my $NORMAL_MODE=> 3;

# We will use the set or query command syntax as zero (0) tor query the mode and one (1) to set
Readonly::Scalar my $SETCOMMAND=> 0;
Readonly::Scalar my $QUERYCOMMAND => 1;


# TEMP command max and mins
Readonly::Scalar my $MIN_TEMP_C => -40.0;   # degrees C, operational limit of ADS1118
Readonly::Scalar my $MAX_TEMP_C => 125.0;   # upper operational limit of ADS1118
Readonly::Scalar my $MIN_TEMP_F => -40;
Readonly::Scalar my $MAX_TEMP_F => 257;

# VOLTAGE command max and mins - Use 5% tolerances on all voltages.
Readonly::Scalar my $MIN_VOLTAGE_1V3 => 1.14;
Readonly::Scalar my $MAX_VOLTAGE_1V3 => 1.26;

Readonly::Scalar my $MIN_VOLTAGE_3V3 => 3.135;
Readonly::Scalar my $MAX_VOLTAGE_3V3 => 3.465;

Readonly::Scalar my $MIN_VOLTAGE_5V0 => 4.75;
Readonly::Scalar my $MAX_VOLTAGE_5V0 => 5.25;

Readonly::Scalar my $NUM_VOLTAGE_VALUES => 4;
Readonly::Scalar my $NUM_TEMP_VALUESDEBUG => 5;
Readonly::Scalar my $NUM_TEMP_VALUESCONFIG => 2;

# Accel values used for min and max when checking packets
Readonly::Scalar my $MIN_ACCEL_1G_VALUE => -0.5;
Readonly::Scalar my $MAX_ACCEL_1G_VALUE => 1.5;

Readonly::Scalar my $MIN_ACCEL_0G_VALUE => -0.5;
Readonly::Scalar my $MAX_ACCEL_0G_VALUE => 0.5;

# Gyros values used for min and max when checking packets
Readonly::Scalar my $MIN_GYRO_VALUE => -0.05;
Readonly::Scalar my $MAX_GYRO_VALUE => 0.05;

# a counter used in loops
my $indexCount = 0;

# status returned when entering upgrade mode
my $upgradeStatus = $SUCCESS;

#####################################
####                             ####
####     THE CODE BEGINS HERE    ####
####                             ####
#####################################

# we will start indenting here as this is the beginning or the "real" processing

###### Determine passed in arguments for test cases to run  #######
    my $testCaseSelection;
	my $testDevice = ' '; # This is usually left blank or set to IMU for autotesting of 
					# the various FOG products using a single IMU device. 
    my $port_name = 'COM3'; # default
    my $numArgs = $#ARGV + 1;
    #print "thanx, you gave me $numArgs command-line arguments:\n";

    # test if the user entered the correct number of parameters
    if ($numArgs > 0) {
        $port_name = $ARGV[0];
		if ($numArgs > 2) {
            # we will print the options so the user can determine if they
            # are correct when the usage command is generated
            foreach my $argnum (0 .. $#ARGV) {
                print "$ARGV[$argnum]\n";
            }
            $testCaseSelection = $ARGV[1];
			$testDevice = $ARGV[2];
            print "\ntestCaseSelection = $testCaseSelection\n";
			print "\ntestDevice = $testDevice\n";
        }
        elsif ($numArgs > 1) {
         
            # we will print the options so the user can determine if they
            # are correct when the usage command is generated
            foreach my $argnum (0 .. $#ARGV) {
                print "$ARGV[$argnum]\n";
            }
            $testCaseSelection = $ARGV[1];
			print "\ntestCaseSelection = $testCaseSelection\n";
		} else {
            $testCaseSelection = "ALL";
        }

        if ($testCaseSelection eq "-HM" ) {
            dumphelp();
            exit;
        }
    } else {
        print "\nUsage: perl testImu.pl [COM PORT] <test case> <test device>; COM port[e.g. COM4] is mandatory; test case is optional
		unless test device is entered; test device is optional\n";
        exit;
    }


################### FILES  ########################################
# these are temporary files as we will derive the final names using
# the device and the date for the file name

    my $testCsvDataFileName = "testCsv.csv";
    my $testDataFileName = "testfile.txt";
    open my $testCsvFileHandle, '>', $testCsvDataFileName or die "Couldn't open file testCsv.csv, $!";
    open my $testFileHandle, '>', $testDataFileName or die "Couldn't open file testfile.txt, $!";

################### FILES  ########################################

################### COM PORTS  ########################################
    $| = 1; #enable autoflush

    my $comPortConfigFile = 'Com921600.cfg';
    my $imuBaud   = 921600;
    my $port = new Win32::SerialPort ($port_name) || die "Can't open port: $^E\n";

    # we have to be sure that the 921600 and 4147200 baud is available in the Serial Port
    # interface as it is usually not in the Win32::SerialPort module
    $port->{"_L_BAUD"}{921600} = 921600;
    $port->{"_L_BAUD"}{4147200} = 4147200;
    print "baud rate: ", join(" ", $port->baudrate), "\n";

    $port->databits(8);
    $port->baudrate(921600);
    $port->parity("none");
    $port->stopbits(1);
    $port->handshake("none");
    $port->buffers(4096, 4096);

    $port->write_settings || undef $port;
    $port->save($comPortConfigFile);


################### Start Main Calls to Subroutines  ########################################

    # processes the date and times for elapsed time calculation
    my $date = localtime->strftime('%m/%d/%Y');
    my $localTime = localtime;
    my $dataValue = "";
    my $serialNumber = "";
    my $imuVariant = "1775";

    # get the date and write it to the test file

    print "Test DATE = $date time = $localTime\r\n";
    print "Test Software = $0\r\n";
    print "Test Software Version = $VERSION Revision = $REVISION\r\n";
    print $testCsvFileHandle "Test DATE = $date time = $localTime\r\n";
    print $testCsvFileHandle "Test Software = $0\r\n";
    print $testCsvFileHandle "Test Software Version = $VERSION Revision = $REVISION\r\n";
    print $testCsvFileHandle "Test Case Selection = $testCaseSelection\r\n";
    print $testFileHandle "Test DATE = $date time = $localTime\r\n";
    print $testFileHandle "Test Software = $0\r\n";
    print $testFileHandle "Test Software Version = $VERSION Revision = $REVISION\r\n";
    print $testFileHandle "Test Case Selection = $testCaseSelection\r\n";
    (my $sec, my $min, my $hour, my $mday, my $mon, my $year,my $wday,my $yday,my $isdst) = localtime(time);

    print "Time hour = $hour min = $min sec = $sec \r\n";

    # build a time string for use with the filename
    my $timeString = $hour . "_" . $min . "_" . $sec;
    print "\ntimeString = $timeString\n";

    # get the start time for use with elapsed time
    my $startTime = [gettimeofday()];
    my $generalStatus = 1;


    # We want to restart based using a menu command; This is in support of the Jenkins automation. We flash the device and then
    # need to get the device in a known state as the flashing process leaves the device in upgrade mode;
    if ($testCaseSelection eq "-RESTART_ICB_FLASH") {

        # end of test, restart the device
        print "\nRestarting IMU device \n";
        RestartCommand($port);

        # cleanup open resources
        # close and undefine the COM port
        $port->close || warn "Comport Close Failed!\r\n";
        undef $port;
        # close the file handles
        close($testCsvFileHandle);
        close($testFileHandle);
        exit;
    }



    # We want to restart based using a menu command; This is in support of the Jenkins automation. We flash the device and then
    # need to get the device in a known state as the flashing process leaves the device in upgrade mode;
    if ($testCaseSelection eq "-RESTART") {

        # make sure we are not in Upgrade mode
        for ($indexCount = 0; $indexCount< 4; $indexCount++) {
            $generalStatus = SendUpgradeCommand($port,"0",0,$testCsvFileHandle,$testFileHandle);
            if ($generalStatus == $SUCCESS) {
                last;
            }
        }

        # end of test, restart the device
        print "\nRestarting IMU device \n";
        RestartCommand($port);

        # cleanup open resources
        # close and undefine the COM port
        $port->close || warn "Comport Close Failed!\r\n";
        undef $port;
        # close the file handles
        close($testCsvFileHandle);
        close($testFileHandle);
        exit;
    }


    # We want to restart based using a menu command; This is in support of the Jenkins automation. We flash the device and then
    # need to get the device in a known state as the flashing process leaves the device in ttg mode and then config mode;
    if ($testCaseSelection eq "-RESTART_GCB") {
        sleep 2;

        $port->purge_rx;
        $port->purge_tx;

        my $commandStatus = "=tti";

        $port->write($commandStatus . "\r\n");
        select(undef, undef, undef, 1.50);  # sleep 1/2 second 500 milliseconds

        my $result = $port->input;
        print "RESTART_GCB TTI result = $result";

        # Get out of Config mode
        for ($indexCount = 0; $indexCount< 4; $indexCount++) {
            sleep 1;
            $generalStatus = SendConfigCommand($port,"0",0,$testCsvFileHandle,$testFileHandle);
        }

        # end of test, restart the device
        print "\nRestarting IMU device \n";
        RestartCommand($port);

        # cleanup open resources
        # close and undefine the COM port
        $port->close || warn "Comport Close Failed!\r\n";
        undef $port;
        # close the file handles
        close($testCsvFileHandle);
        close($testFileHandle);
        exit;
    }

    # We will send an initial Debug command as it typically fails the first time and we do not want to
    # have the failure in the logs. We will also restart the COM port
    $generalStatus = SendDebugCommand($port,"1",0,$testCsvFileHandle,$testFileHandle);
    portRestart();

    # Go into DEBUG mode;  We should be in Normal Mode when first testing
    # we will use DEBUG mode to change the data rate and process the ?ws command to get the version, etc.
    for (my $indexCount = 0; $indexCount < 4; $indexCount++) {

        $generalStatus = SendDebugCommand($port,"1",1,$testCsvFileHandle,$testFileHandle);

        sleep 1;
        if ($generalStatus == $SUCCESS) {
            print "\n DEBUG Done  $indexCount\r\n";
            TestHalt($port, $testCsvFileHandle,$testFileHandle,0);

            my $dataValue = "50";
            TestSetDR($port,$dataValue,1,$testCsvFileHandle,$testFileHandle);
            last;
        } else {
            print "\n DEBUG RESTART\r\n";
            # we might be in config mode from a previous test so we will send a config,0 to get to normal mode
            SendConfigCommand($port,"0",0,$testCsvFileHandle,$testFileHandle);
            portRestart();
            sleep 1;
        }
    } # end of for (my $indexCount = 0; $indexCount < 4; $indexCount++)

    if ($generalStatus == 0) {
        print "\r\nCan't communicate start over! Must be in NORMAL mode or DEBUG mode to start!\r\n";
        # cleanup open resources
        # close and undefine the COM port
        $port->close || warn "Comport Close Failed!\r\n";
        undef $port;

        # close the file handles
        close($testCsvFileHandle);
        close($testFileHandle);
        exit;
    }


    TestVersion($port,$testCsvFileHandle,$testFileHandle);

    ($generalStatus, $serialNumber) = TestSerialNumberCommand($port,1,$testCsvFileHandle,$testFileHandle);

    # we will use the return of the sysconfig command to determine the device type
    # it will later be used to determine the directory name
    my $deviceName = TestSystemConfigCommand($port);

    # test against a return of unknown if the sysconfig is not valid or the command is not accepted
    if ((index($deviceName,'UNKNOWN') != -1)) {
        $deviceName = "IMU";
    } else {
        print "The deviceName = $deviceName\n\n";
    }

    # we will derive the filename and directory to write to here as we will need it with the testFilt command test;
    my $dateFileName = $date;

    $dateFileName =~ tr|/|_|;  # remove the forward slash and replace with underbars

    # concatenate the time with the data string - $timeString was created above
    $dateFileName = $dateFileName . "_" . $timeString;
    print "\ndateFileName  = $dateFileName\n";

    # setup the location of the directory to store the automated test files to
    my $newDir = setDirectoryStruct($deviceName, $dateFileName, $serialNumber);

     # setup the name of the backup zip file
    my $currentDirectory = cwd(); # get the current working directory
    print "CWD = $currentDirectory\r\n";

    my $BACKUPNAME = $currentDirectory . "/TestResultArchive/" . $deviceName . "_" . $serialNumber . "_" . $dateFileName .".zip";


    # setup test file results
    my $newCsvfile = $newDir . $deviceName . "_" . $serialNumber . "_" . $dateFileName . ".csv";
    my $newTestfile = $newDir . $deviceName . "_" . $serialNumber . "_" . $dateFileName . ".txt";
    #print "\n newDir = $newDir \n";
    #print "\n newfile  = $newfile  newCsvfile = $newCsvfile\n";
    ##########################################################
    ##########################################################
    ###############  Debug Mode test cases #################
    ##########################################################

    print "\r\n ################## Debug Mode Tests ##################\r\n";
    print $testCsvFileHandle "\r\nDebug Mode Tests\r\n\r\n";
    print $testFileHandle "\r\n ################## Debug Mode Tests ##################\r\n\r\n";
	my $ModeStatus = "Debug";
	    # Command Configurabilty Test
    if ( ($testCaseSelection eq "ALL") || ($testCaseSelection eq "-C" )) {
        TestCommandConfigurability($port, $testCsvFileHandle,$testFileHandle);
    }
	
    # Axes commmand Test
    if ( ($testCaseSelection eq "ALL") || ($testCaseSelection eq "-A" )) {
        TestAXESCommand($port,$testCsvFileHandle,$testFileHandle);
    }
	
	# Axes Rotation test.
    if ( ($testCaseSelection eq "ALL") || ($testCaseSelection eq "-AR" )) {
		TestAXESRotationCommand($port,$testCsvFileHandle,$testFileHandle,$deviceName);
    }

    #  1750 AccelType Set commmand Test
    if ( ($testCaseSelection eq "ALL") || ($testCaseSelection eq "-AT" )) {

        if (index($deviceName,'1750') != -1) {

            $dataValue = "30";
            TestAccelTypeSet($port, $dataValue,$testCsvFileHandle,$testFileHandle);

            $dataValue = "2";
            TestAccelTypeSet($port, $dataValue,$testCsvFileHandle,$testFileHandle);

            $dataValue = "10";
	    TestAccelTypeSet($port, $dataValue,$testCsvFileHandle,$testFileHandle);

        }

	if ((index($deviceName,'1750') != -1)) {
            TestAccelTypeNegativeTestSet($port,$testCsvFileHandle,$testFileHandle);
        }
    }

    # Baud Command Test
    if ( ($ModeStatus eq "Config") && ($testCaseSelection eq "ALL") || ($testCaseSelection eq "-BAUD" )) {
       # TestBaudGetCommand($port,$testCsvFileHandle,$testFileHandle);
    }
	
	# Data Rate Command Test
    if (($testCaseSelection eq "ALL") || ($testCaseSelection eq "-DR" )) {
        TestDataRateSetCommand($port,$testCsvFileHandle,$testFileHandle);
    }

    # Echo Test
    # the ECHO test requires a reboot as the echo command remembers the previous echo commands
    #if ( ($testCaseSelection eq "ALL") || ($testCaseSelection eq "-E" )) {

    #    TestRestartShutdown($port, $testCsvFileHandle,$testFileHandle);

    #    sleep 1;

    #    for (my $indexCount = 0; $indexCount < 4; $indexCount++) {
    #        my $generalStatus = SendConfigCommand($port,"0", 0,$testCsvFileHandle,$testFileHandle);
    #        if ($generalStatus) {
    #            last;
    #        }
    #        sleep 1;
    #    } # end of for
    #    TestEchoCommand($port,$testCsvFileHandle,$testFileHandle);
    #}

	# Filter Enable Get Command Test
    if ( ($testCaseSelection eq "ALL") || ($testCaseSelection eq "-FEG" )) {
        TestFilterEnableGet($port,"2",$testCsvFileHandle,$testFileHandle);
    }

	if ( ($testCaseSelection eq "ALL") || ($testCaseSelection eq "-FES" )) {
        TestFilterEnableSet($port,$testCsvFileHandle,$testFileHandle);
    }

    # Filtering Command Test
    if ( ($testCaseSelection eq "ALL") || ($testCaseSelection eq "-F" )) {
        TestFilterCommands($port,$testCsvFileHandle,$testFileHandle, $deviceName);
    }

    # Filtering Command Test for negative testing
    if ( ($testCaseSelection eq "ALL") || ($testCaseSelection eq "-FN" )) {
        if ( (index($deviceName,'1775') != -1) || (index($deviceName,'DSPU') != -1)  ) {
           TestFtNegativeTest1775($port,$testCsvFileHandle,$testFileHandle);
        } else {
           TestFiltTypeNegativeTest($port,$testCsvFileHandle,$testFileHandle,$deviceName);
        }
    }


    # Help Menu Command Test
    if ( ($testCaseSelection eq "ALL") || ($testCaseSelection eq "-H" ) ) {
        TestHelpMenuCommand($port,$testCsvFileHandle,$testFileHandle,$newDir, $DEBUG_MODE );
    }

    # Restart Shutdown Test
    if ( ($testCaseSelection eq "ALL") || ($testCaseSelection eq "-X" )) {
        # TestRestartShutdown($port);
    }

    # Serial Number Test
    if ($testCaseSelection eq "-S" ){
        ($generalStatus, $serialNumber) = TestSerialNumberCommand($port,1,$testCsvFileHandle,$testFileHandle);
    }

    # Temperature Test
    if ( ($testCaseSelection eq "ALL") || ($testCaseSelection eq "-T" )) {
        TestTemperature($port,1,$testCsvFileHandle,$testFileHandle,$deviceName );
    }

    # Voltage Test
    if ( ($testCaseSelection eq "ALL") || ($testCaseSelection eq "-V" )) {
        TestVoltage($port,1,$testCsvFileHandle,$testFileHandle);
    }

    # Msync Get Test
    if ( ($testCaseSelection eq "ALL") || ($testCaseSelection eq "-MG" )) {
        TestGetMsync($port,1,$testCsvFileHandle,$testFileHandle,$newDir);
    }

    # Msync Set Test
    if ( ($testCaseSelection eq "ALL") || ($testCaseSelection eq "-MS" )) {
        TestSetMsync($port,1,$testCsvFileHandle,$testFileHandle,$newDir);
    }

    # Configuration Reset Test
    $ModeStatus = "DEBUG";
    if ( ($testCaseSelection eq "ALL") || ($testCaseSelection eq "-R" )) {
        TestConfigResetConfig($port,$testCsvFileHandle,$testFileHandle,$ModeStatus, $deviceName);
    }

     # Mag Offset Test
    if ( ($testCaseSelection eq "ALL") || ($testCaseSelection eq "-MO" )) {
        TestMagOffsetCommand($port,$testCsvFileHandle,$testFileHandle, $DEBUG_MODE);
    }

    # SysConfig Get Test
    if ( ($testCaseSelection eq "ALL") || ($testCaseSelection eq "-SCG" )) {
        TestGetSysConfig($port,1,$testCsvFileHandle,$testFileHandle,$newDir);
    }

    # SysConfig Set Test
    if ( ($testCaseSelection eq "ALL") || ($testCaseSelection eq "-SCS" )) {
        TestSetSysConfig($port,1,$deviceName,$testCsvFileHandle,$testFileHandle,$newDir);
    }

    # Logs Test
    #if (((index($deviceName,'1775') != -1)  && (($testCaseSelection eq "ALL") || ($testCaseSelection eq "-L" )))|| ($deviceName eq "IRS3AXIS") && (($testCaseSelection eq "ALL") || ($testCaseSelection eq "-L" ))) {
	if ( ($testCaseSelection eq "ALL") || ($testCaseSelection eq "-L" )) {
    TestLogs($port,$testCsvFileHandle,$testFileHandle,$newDir);
    }

    # Clear Logs Test
    #if (((index($deviceName,'1775') != -1) && (($testCaseSelection eq "ALL") || ($testCaseSelection eq "-CL" )))|| ($deviceName eq "IRS3AXIS") && (($testCaseSelection eq "ALL") || ($testCaseSelection eq "-CL" ))) {
	if ( ($testCaseSelection eq "ALL") || ($testCaseSelection eq "-CL" )) {
    TestClearLogs($port,$testCsvFileHandle,$testFileHandle,$newDir);
    }

    # GET Debug Data Test
    if ( ($testCaseSelection eq "ALL") || ($testCaseSelection eq "-D" )) {
        GetDebugTest($port,$testCsvFileHandle,$testFileHandle,$newDir);
    }

    # Version Test
    # We test the version in the early stage of the test, so we will
    # not do it here when all test are being run; It can still be run with the -W switch
    if ($testCaseSelection eq "-W" ) {
        TestVersion($port,$testCsvFileHandle,$testFileHandle);
    }

    
	##########################################################
    ##########################################################
    ###############  Config Mode test cases ##################
    ##########################################################
	
		if ($testCaseSelection ne "-BIT") {
			print "\r\n ################## Config Mode Tests ##################\r\n";
			print $testCsvFileHandle "\r\nConfig Mode Tests\r\n";
			print $testFileHandle "\r\n ################## Config Mode Tests ##################\r\n";

			# make sure we are in CONFIG mode for the config tests
			for (my $indexCount = 0; $indexCount < 4; $indexCount++) {
				$generalStatus = SendConfigCommand($port,"1",1,$testCsvFileHandle,$testFileHandle);
				if ($generalStatus == $SUCCESS) {
					print "\nConfig Done  $indexCount\r\n";
					$ModeStatus = "Config";
					last;
				}
			} # end of for (my $indexCount = 0; $indexCount < 5; $indexCount++)
		}

    # 1750IMU AccelType Get commmand Test
    if ( ($testCaseSelection eq "ALL") || ($testCaseSelection eq "-AT" )) {

        if (index($deviceName,'1750') != -1) {

            TestAccelTypeGet($port,$testCsvFileHandle,$testFileHandle);

            $dataValue = "30";
            TestAccelTypeSet($port, $dataValue,$testCsvFileHandle,$testFileHandle);

            $dataValue = "2";
            TestAccelTypeSet($port, $dataValue,$testCsvFileHandle,$testFileHandle);

            $dataValue = "10";
            TestAccelTypeSet($port, $dataValue,$testCsvFileHandle,$testFileHandle);
		}
		if (index($deviceName,'1750') != -1) {

            TestAccelTypeNegativeTestSet($port,$testCsvFileHandle,$testFileHandle);
        }
    }

	# Command Configurabilty Test
    if ( ($testCaseSelection eq "ALL") || ($testCaseSelection eq "-C" )) {
        TestCommandConfigurability($port, $testCsvFileHandle,$testFileHandle);
    }

    # Baud Test
    if ( ($ModeStatus eq "Config") && ($testCaseSelection eq "ALL") || ($testCaseSelection eq "-BAUD" )) {
        TestBaudGetCommand($port,$testCsvFileHandle,$testFileHandle);
       # TestBaudSetCommand($port,$testCsvFileHandle,$testFileHandle);
    }

    # Data Rate Command Test
    if (($testCaseSelection eq "ALL") || ($testCaseSelection eq "-DR" )) {
        TestDataRateSetCommand($port,$testCsvFileHandle,$testFileHandle);
    }


    # Axes commmand Test
    if ( ($testCaseSelection eq "ALL") || ($testCaseSelection eq "-A" )) {
        TestAXESCommand($port,$testCsvFileHandle,$testFileHandle);
    }


    # Echo Test
    # the ECHO test requires a reboot as the echo command remembers the previous echo commands
    if ( $testCaseSelection eq "-E" ) {

        TestRestartShutdown($port,$testCsvFileHandle,$testFileHandle);

        sleep 1;

        for (my $indexCount = 0; $indexCount < 4; $indexCount++) {
            my $generalStatus = SendConfigCommand($port,"1", 0,$testCsvFileHandle,$testFileHandle);
            if ($generalStatus == $SUCCESS) {
                last;
            }
            sleep 1;
        } # end of for
        TestEchoCommand($port,$testCsvFileHandle,$testFileHandle);
    }

	# Filter Enable Get Command Test
    if ( ($testCaseSelection eq "ALL") || ($testCaseSelection eq "-FEG" )) {
        TestFilterEnableGet($port,"2",$testCsvFileHandle,$testFileHandle);
    }

	# Filter Enable Set Command Test
    if ( ($testCaseSelection eq "ALL") || ($testCaseSelection eq "-FES" )) {
        TestFilterEnableSet($port,$testCsvFileHandle,$testFileHandle);
    }

    # Filtering Command Test
    if ( ($testCaseSelection eq "ALL") || ($testCaseSelection eq "-F" )) {
        TestFilterCommands($port,$testCsvFileHandle,$testFileHandle, $deviceName);
    }

    # Filtering Command Test for negative testing
    if ( ($testCaseSelection eq "ALL") || ($testCaseSelection eq "-FN" )) {

        if ((index($deviceName,'1775') != -1) || (index($deviceName,'DSPU') != -1)) {
           TestFtNegativeTest1775($port,$testCsvFileHandle,$testFileHandle );
        } else {
           TestFiltTypeNegativeTest($port,$testCsvFileHandle,$testFileHandle,$deviceName);
        }
    }


    # Help Menu Command Test
    if (($testCaseSelection eq "ALL") || ($testCaseSelection eq "-H" )) {
        TestHelpMenuCommand($port,$testCsvFileHandle,$testFileHandle,$newDir,$CONFIG_MODE );
    }

    # Linear Format Command Test
    if (($testCaseSelection eq "ALL") ||  ($testCaseSelection eq "-LF" )) {
        TestLinearFormat($port,$testCsvFileHandle,$testFileHandle);
    }

    # Linear Units Command Test
    if (($testCaseSelection eq "ALL") ||  ($testCaseSelection eq "-LU" )) {
        TestLinearUnits($port,$testCsvFileHandle,$testFileHandle);
    }


    # Mag Offset Test
    if ( ($testCaseSelection eq "ALL") || ($testCaseSelection eq "-MO" )) {
       if (index($deviceName,'1775') != -1) {
            TestMagOffsetCommand($port,$testCsvFileHandle,$testFileHandle, $CONFIG_MODE);
       }
    }

    # Restart Shutdown Test
    if ( ($testCaseSelection eq "ALL") || ($testCaseSelection eq "-X" )) {
        # TestRestartShutdown($port);
    }

    # Serial Number Test
    if (($testCaseSelection eq "ALL") || ($testCaseSelection eq "-S" )) {
        ($generalStatus, $serialNumber) = TestSerialNumberCommand($port,1,$testCsvFileHandle,$testFileHandle);
    }

    # Temperature Test
    if ( ($testCaseSelection eq "ALL") || ($testCaseSelection eq "-TC" )) {
        TestConfigTemperature($port,1,$testCsvFileHandle,$testFileHandle);
    }

    # Voltage Test
    if ( ($testCaseSelection eq "ALL") || ($testCaseSelection eq "-V" )) {
        TestVoltage($port,1,$testCsvFileHandle,$testFileHandle);
    }

    # Msync Get Test
    if ( ($testCaseSelection eq "ALL") || ($testCaseSelection eq "-MG" )) {
        TestGetMsync($port,1,$testCsvFileHandle,$testFileHandle,$newDir);
    }

    # Msync Set Test
    if ( ($testCaseSelection eq "ALL") || ($testCaseSelection eq "-MS" )) {
        TestSetMsync($port,1,$testCsvFileHandle,$testFileHandle,$newDir);
    }

    # Configuration Reset Test
    if ( ($testCaseSelection eq "ALL") || ($testCaseSelection eq "-R" )) {
        $ModeStatus = "CONFIG";
        TestConfigResetConfig($port,$testCsvFileHandle,$testFileHandle,$ModeStatus, $deviceName);
    }

    # Self Test Command
    #if ( ($testCaseSelection eq "ALL") || ($testCaseSelection eq "-ST" )) {
    #    TestSelfTestCommand($port,$testCsvFileHandle,$testFileHandle);
    #}

	# Logs Test
    #if (((index($deviceName,'1775') != -1) && (($testCaseSelection eq "ALL") || ($testCaseSelection eq "-L" )))|| ($deviceName eq "IRS3AXIS") && (($testCaseSelection eq "ALL") || ($testCaseSelection eq "-L" ))) {
	if ( ($testCaseSelection eq "ALL") || ($testCaseSelection eq "-L" )) {
    TestLogs($port,$testCsvFileHandle,$testFileHandle,$newDir);
    }

    # Clear Logs Test
    #if (((index($deviceName,'1775') != -1) && (($testCaseSelection eq "ALL") || ($testCaseSelection eq "-CL" )))|| ($deviceName eq "IRS3AXIS") && (($testCaseSelection eq "ALL") || ($testCaseSelection eq "-CL" ))) {
	if ( ($testCaseSelection eq "ALL") || ($testCaseSelection eq "-CL" )) {
    TestClearLogs($port,$testCsvFileHandle,$testFileHandle,$newDir);
    }

    # Version Test
    # We test the version in the early stage of the test, but we want to be sure we can test in the config mode also
    if ( ($testCaseSelection eq "ALL") || ($testCaseSelection eq "-W" ) ) {
        TestVersion($port,$testCsvFileHandle,$testFileHandle);
    }
	
	##########################################################
    ##########################################################
    ###############  Normal Mode test cases #################
    ##########################################################
		
		if ( ($testCaseSelection eq "ALL") || ($testCaseSelection eq "-M" )) {
			print "\r\n ################## NORMAL Mode Tests ##################\r\n";
			print $testCsvFileHandle "\r\nNORMAL Mode Tests\r\n";
			print $testFileHandle "\r\n################## NORMAL Mode Tests ##################\r\n";
			
			# Message Format Test
			$ModeStatus = "NORMAL";

			# reset the config
			print "\n$deviceName\r\n";
			if ( (index($deviceName,'1775') == -1)  && (index($deviceName,'IRS') == -1) && (index($deviceName,'1760DSPU') == -1)) {
				TestMsgFormat1750_60($port,$testCsvFileHandle,$testFileHandle,$newDir,$deviceName,$testDevice);
				print "\nFound 1750 TestMsgFormat placeholder\r\n";
			} else {
				print "\nTesting 1775 or 1760DSPU TestMsgFormat \r\n";
				TestMsgFormat($port,$testCsvFileHandle,$testFileHandle,$newDir,$deviceName,$testDevice);
			}
		}	
	
    # BIT Test
    if ( ($testCaseSelection eq "ALL") || ($testCaseSelection eq "-B" )) {
        my $imuPacket = TestBITFormat($port,$testCsvFileHandle,$testFileHandle,$newDir,1);

        ProcessBITPacket($testCsvFileHandle,$testFileHandle, $imuPacket, $deviceName);
    }

    ##########################################################
    ##########################################################
    ############ ENABLE THIS FOR SWITCHING TO AN IMU VARIANT
    ##########################################################
    if (index($testCaseSelection,'-SW') != -1){

        print "\r\nTestSwitchImuVariant switching selection is $testCaseSelection\r\n";

        # we might be in config mode from a previous test so we will send a config,0 to get to normal mode
        SendConfigCommand($port,"0",0,$testCsvFileHandle,$testFileHandle);

        # we will use DEBUG mode to process the switch
        for ($indexCount = 0; $indexCount < 4; $indexCount++) {
            $generalStatus = SendDebugCommand($port,"1",1,$testCsvFileHandle,$testFileHandle);

            if ($generalStatus == $SUCCESS) {
                print "\n DEBUG Done  $indexCount\r\n";
                sleep 1;
                TestHalt($port, $testCsvFileHandle,$testFileHandle,1);

                last;
            } else {
                print "\n DEBUG RESTART\r\n";
                # we might be in config mode from a previous test so we will send a config,0 to get to normal mode
                SendConfigCommand($port,"0",0,$testCsvFileHandle,$testFileHandle);
                sleep 1;
            }
        } # end of for (my $indexCount = 0; $indexCount < 4; $indexCount++)


        if ($testCaseSelection eq "-SW25" ) {
            TestSwitchImuVariant($port,$testCsvFileHandle,$testFileHandle,$IMU1725IMU);
        } elsif ($testCaseSelection eq "-SW50" ) {
            TestSwitchImuVariant($port,$testCsvFileHandle,$testFileHandle,$IMU1750IMU);
        } elsif ($testCaseSelection eq "-SW60_1" ) {
            TestSwitchImuVariant($port,$testCsvFileHandle,$testFileHandle,$DSP1760_1);
        } elsif ($testCaseSelection eq "-SW60_2" ) {
            TestSwitchImuVariant($port,$testCsvFileHandle,$testFileHandle,$DSP1760_2);
        } elsif ($testCaseSelection eq "-SW60_3" ) {
            TestSwitchImuVariant($port,$testCsvFileHandle,$testFileHandle,$DSP1760_3);
        } elsif ($testCaseSelection eq "-SW75" ) {
            TestSwitchImuVariant($port,$testCsvFileHandle,$testFileHandle,$IMU1775IMU);
        } elsif ($testCaseSelection eq "-SW1760_1U" ) {
            TestSwitchImuVariant($port,$testCsvFileHandle,$testFileHandle,$DSP1760_1U);
        } elsif ($testCaseSelection eq "-SW1760_2U" ) {
            TestSwitchImuVariant($port,$testCsvFileHandle,$testFileHandle,$DSP1760_2U);
        } elsif ($testCaseSelection eq "-SW1760_3U" ) {
            TestSwitchImuVariant($port,$testCsvFileHandle,$testFileHandle,$DSP1760_3U);
        }

    } # end of if ( ($testCaseSelection eq "-SW25" ) ...

     
    ##########################################################
    ##########################################################
    ###############  Upgrade Mode test cases #################
    ##########################################################

    #print "\r\n ################## UPGRADE Mode Tests ##################\r\n\r\n";
    #print $testCsvFileHandle "\r\nUpgrade Mode Tests\r\n";
    #print $testFileHandle "\r\nUpgrade Mode Tests\r\n\r\n";
	
	
    ##########################################################
    ############ ENABLE THIS FOR TESTING THE TESTFILT COMMAND
    ############ THIS COMMAND TAKES A VERY LONG TIME
    ##########################################################
    if ($testCaseSelection eq "-TF" ) {
        TestFiltCommand($port,$testCsvFileHandle,$testFileHandle,$newDir);		
    }
	
	
	##########################################################
    ##########################################################
    ############ ENABLE THIS FOR TESTING THE BITTEST COMMAND
	############ FOR EACH STATUS BIT
    ############ THIS COMMAND TAKES A LONG TIME
    ##########################################################
	# BITTEST Command
    if ($testCaseSelection eq "-BIT" ) {
		ProcessBITTEST($port,1,$testCsvFileHandle,$testFileHandle,$deviceName);
		RestartCommand($port);
    }
	
	##########################################################
    ############ Complete Setting for end of test#############
	
	# send the cfgreset command then the config command to get the device into a known state when required
    if (($testCaseSelection ne "-TF" ) && ($testCaseSelection ne "-BIT" )){
		TestCfgRstCommand($port,$testCsvFileHandle,$testFileHandle);

		# make sure we are out of CONFIG mode
		for (my $indexCount = 0; $indexCount < 4; $indexCount++) {
			$generalStatus = SendConfigCommand($port,"0",0,$testCsvFileHandle,$testFileHandle);
			if ($generalStatus == $SUCCESS) {
				print "\nConfig Done  $indexCount\r\n";
				$ModeStatus = "Config";
				last;
			}
		}
	}
	my $elapsedTime = time - $^T;
    my $elapsedTime2 = tv_interval($startTime) * 1000;

    print "\r\nFinal test elapsedTime = $elapsedTime seconds\r\n";
    print "\r\nFinal test elapsedTime = $elapsedTime2 milliseconds\r\n";

    print $testCsvFileHandle "\nFinal test elapsedTime = $elapsedTime seconds\n";
    print $testCsvFileHandle "\nFinal test elapsedTime ms = $elapsedTime2 milliseconds\n";
    print $testFileHandle "\nFinal test elapsedTime = $elapsedTime seconds\n";
    print $testFileHandle "\nFinal test elapsedTime ms = $elapsedTime2 milliseconds\n";

    print "\n newCsvfile = $newCsvfile\n";
    print "\n newTestfile = $newTestfile\n";

$port->close || warn "Comport Close Failed!\r\n";
undef $port;

# close the file handles
close($testCsvFileHandle);
close($testFileHandle);

CollectNegativeResults($newDir, $deviceName);

# copy the local csv file to the new file directory
copy($testCsvDataFileName,$newCsvfile) or die "File cannot be copied.";
copy($testDataFileName,$newTestfile) or die "File cannot be copied.";
close($newDir);

# lets delete the temporary testCsv.csv file
if (unlink($testCsvDataFileName) == 0) {
    print "File deleted successfully.";
} else {
    print "File was not deleted.";
}

# We will ZIP all the files collected to use as an archive
if ( ($testCaseSelection eq "ALL") ||  ($testCaseSelection eq "-TF") || ($testCaseSelection eq "-BIT")){
    ZipDirectory($newDir, $BACKUPNAME);
}


################### END OF MAIN  ########################################

################### SUBROUTINES  ########################################


############################################################################
#
#  Description: portRestart  - restart the COM port by closing and opening a new session
#
#       Inputs: None
#
#      Returns: None
#
# Side Effects: None
#
#        Notes: Globals are used here as we need to maintain the
#        access to COM port for all the modules
#
############################################################################
sub portRestart
{

    $comPortConfigFile = 'Com921600.cfg';
    my $imuBaud   = 921600;

    # first close the port
    $port->close || warn "close failed";
    sleep 1;

    $port = new Win32::SerialPort ($port_name) || die "Can't open port: $^E\n";

    # we have to be sure that the 921600 and 4147200 baud is available in the Serial Port interface as it is usually not
    $port->{"_L_BAUD"}{921600} = 921600;
    $port->{"_L_BAUD"}{4147200} = 4147200;
    #print "baud rate: ", join(" ", $port->baudrate), "\n";

    $port->databits(8);
    $port->baudrate($imuBaud);
    $port->parity("none");
    $port->stopbits(1);
    $port->handshake("none");
    $port->buffers(4096, 4096);

    $port->write_settings || undef $port;
    $port->save($comPortConfigFile);

} # end of portRestart

############################################################################
#
#  Description: setDirectoryStruct  - set the directory structure to where
#               to store the files using the device name and the date;
#
#       Inputs: $deviceName   - Device Name
#               $dateFileName - Date used in the file name
#
#      Returns: None
#
# Side Effects: None
#
#        Notes:
#
############################################################################
sub setDirectoryStruct
{

    my $deviceName   = shift;
    my $dateFileName = shift;
	my $serialNumber = shift;
    my $newDir = "";

    my $currentDirectory = cwd(); # get the current working directory
    print "CWD = $currentDirectory\r\n";

    $dateFileName =~ tr|/|_|;
    print "\ndateFileName  = $dateFileName\n";

    # form the directory string
    $newDir = $currentDirectory . "/TestResultArchive/" . $deviceName . "_" . $serialNumber . "_". $dateFileName . "/";

    if (-d $newDir) {
        print "Directory $newDir Already Exists\n";;
    } else {
        mkdir $newDir or die "Couldn't create $newDir directory, $!";
        print "Directory $newDir created successfully\n";;
    }

    return $newDir;
} # end of setDirectoryStruct

############################################################################
#
#  Description: Dump the help menu
#
#       Inputs: None
#
#      Returns: None
#
# Side Effects: None
#
#        Notes: Note that the -TF testfilt command is not run as part of the
#               auto test when all commands are tested. The testfilt command
#               takes a very long time and should be run overnight.
#
############################################################################
sub dumphelp
{
	print "     \t\tTest Case Options\r\n\r\n";
    print "-A   \t\tAxes Test\r\n";
    print "-AR  \t\tAxes Rotation Test\r\n";
	print "ALL  \t\ Default option All Tests Note No - in front \r\n";
    print "-BAUD\t\tBaud Test\r\n";
    print "-B   \t\tBIT Test\r\n";
	print "-BIT \t\tBIT Status Bits Test\r\n";
    print "-C   \t\tMessage Configurability Test\r\n";
    print "-DR  \t\tData Rate Test\r\n";
    print "-E   \t\tEcho Test\r\n";
    print "-F   \t\tFilter Test\r\n";
    print "-FN  \t\tFilter Test Negative Testing\r\n";
    print "-H   \t\tHelp Menu Test\r\n";
    print "-HM  \t\tThis Help Menu\r\n";
    print "-LF  \t\tTest Linear Format\r\n";
    print "-L   \t\tTest Logs\r\n";
    print "-M   \t\tMessage Format Test\r\n";
    print "-MG  \t\tMsync Get Test\r\n";
    print "-MS  \t\tMsync Set Test\r\n";
    print "-MO  \t\tMag Offset Test\r\n";
    print "-R   \t\tReset Configuration Test\r\n";
    print "-S   \t\tSerial Number Test\r\n";
    print "-ST  \t\tSelf Test\r\n";
    print "-SW25 \t\tSet device to a 1725\r\n";
    print "-SW50 \t\tSet device to a 1750\r\n";
    print "-SW60_1 \tSet device to a 1760DSP_1\r\n";
    print "-SW60_2 \tSet device to a 1760DSP_2\r\n";
    print "-SW60_3 \tSet device to a 1760DSP_3\r\n";
    print "-SW1760U_1 \tSet device to a 1760DSPU_1\r\n";
    print "-SW1760U_2 \tSet device to a 1760DSPU_2\r\n";
    print "-SW1760U_3 \tSet device to a 1760DSPU_3\r\n";
    print "-SW75 \t\tSet device to a 1775\r\n";
    print "-T   \t\tTemperature Test\r\n";
    print "-TC  \t\tTemperature Config Mode Test\r\n";
    print "-TF  \t\tTest =testfilt Command\r\n";
    print "-V   \t\tVoltage Test\r\n";
    print "-X   \t\tRestart Test\r\n";
    print "-W   \t\tSoftware Version Test\r\n\r\n";
	print "IMU  \t\tDevice Option To Be Used When Using an IMU Device To Test Other\r\n";
	print "     \t\tVarients. Example: perl xxx.pl com4 ALL IMU when device is\r\n";
	print "     \t\tconfigured as a 1760DSP3\r\n";
} # end of dumphelp

############################################################################
#
#  Description: test the testfilt command - captures the filtering in a text
#               file for use with the FFT analysis
#
#       Inputs: $portTest         - comport device is on
#               $csvFileHandle    - file handle to write csv test results
#               $testFileHandle    - file handle to write txt test results
#               $newTestDir       - Directory to write the results to
#
#      Returns: Success or Failure - 0 or 1
#
# Side Effects: None
#
#        Notes: This command takes a very long time and should be run overnight
#
############################################################################
sub TestFiltCommand
{

    my $portTest       = shift;
    my $csvFileHandle  = shift;
    my $testFileHandle  = shift;
    my $newTestDir     = shift;

    my $testFilterFileName;
    my $testFilterFileHandle;
    my $testFilterFileNameWithDir;
    my $file1;
    my $file2;
    my $result;
	# make sure we are in CONFIG mode for the config tests
    for (my $indexCount = 0; $indexCount < 10; $indexCount++) {
        $generalStatus = SendConfigCommand($port,"1",1,$testCsvFileHandle,$testFileHandle);
        if ($generalStatus == $SUCCESS) {
            print "\nConfig Done  $indexCount\r\n";
            $ModeStatus = "Config";
            last;
        }
				
    } # end of for (my $indexCount = 0; $indexCount < 5; $indexCount++)
	if ($generalStatus != $SUCCESS) {
		die "\r\nCouldn't get into Config Mode\r\n";
	}

    #####################################
    # set the data rate to 5000 if a 1775IMU, IRST, 1760DSPU
    if ( (index($deviceName,'1775') != -1) || (index($deviceName,'IRS') != -1) || (index($deviceName,'DSPU') != -1)) {
		my $dataValue = "5000";
		TestSetDR($portTest,$dataValue, 1,$csvFileHandle,$testFileHandle);

		# test the cheby filter here
		# set the filter type for the accels to cheby and verify response
		if ( (index($deviceName,'1775') != -1)) {
			TestFilterTypeSet($portTest, "a","cheby",$csvFileHandle,$testFileHandle);
		}
		# set the filter type for the gyros to cheby and verify response
		TestFilterTypeSet($portTest, "g","cheby",$csvFileHandle,$testFileHandle);
		$testFilterFileName = $deviceName . "_Cheby_5000.txt";
		$testFilterFileNameWithDir = $newTestDir . $testFilterFileName;
		open $testFilterFileHandle, '>', $testFilterFileNameWithDir or die "Couldn't open file IMU1775_Cheby_5000.txt, $!";
		TestFilter($portTest, $testFilterFileHandle,$csvFileHandle);
		close($testFilterFileHandle); # close the file handle
		print "\n\nTEST_FILTER:  OUTPUT FILE  = $testFilterFileNameWithDir\n\n";

		# Compare Filter Test File with Known good file to determine pass or fail
		if ( (index($deviceName,'1775') != -1)) {
			$file1 = "./TestFilterFiles/1775IMUCheby5000.txt";
		}
		else {
			$file1 = "./TestFilterFiles/IRSCheby5000.txt";
		}
		$file2= "$testFilterFileNameWithDir";
		$result = compare ($file1, $file2);
		if ( $result == 0 ) {
            print "\n\nCheby_5000 filter test = $result Passed\n\n";
            print $csvFileHandle "Cheby_5000 filter test,Passed\r\n";
            print $testFileHandle "Cheby_5000 filter test,$THREE_TABS Passed\r\n";
		}
		elsif ($result == 1) {
            print "\n\nCheby_5000 filter test = $result Failed\n\n";
            print $csvFileHandle "Cheby_5000 filter test,Failed,,\r\n";
            print $testFileHandle "Cheby_5000 filter test,$THREE_TABS Failed,,\r\n";
		}
		elsif ($result == -1) {
            print "\n\nCheby_5000 filter test = Failed $result File not found\n\n";
            print $csvFileHandle "Cheby_5000 filter test,Failed\r\n";
            print $testFileHandle "Cheby_5000 filter test,$THREE_TABS Failed File not found\r\n";
		}
		# processImuExcel($testFilterFileNameWithDir);

		# test the butter filter here
		# set the filter type for the accels to butter and verify response
		if ( (index($deviceName,'1775') != -1)) {
			TestFilterTypeSet($portTest, "a","butter",$csvFileHandle,$testFileHandle);
		}
		# set the filter type for the gyros to butter and verify response
		TestFilterTypeSet($portTest, "g","butter",$csvFileHandle,$testFileHandle);
		$testFilterFileName = $deviceName . "_Butter_5000.txt";
		$testFilterFileNameWithDir = $newTestDir . $testFilterFileName;
		open $testFilterFileHandle, '>', $testFilterFileNameWithDir or die "Couldn't open file IMU1775_Butter_5000.txt, $!";
		TestFilter($portTest, $testFilterFileHandle,$csvFileHandle,$testFileHandle);
		close($testFilterFileHandle); # close the file handle
		print "\n\nTEST_FILTER:  OUTPUT FILE  = $testFilterFileNameWithDir\n\n";

		# Compare Filter Test File with Known good file to determine pass or fail
		if ( (index($deviceName,'1775') != -1)) {
			$file1 = "./TestFilterFiles/1775IMUButter5000.txt";
		}
		else {
			$file1 = "./TestFilterFiles/IRSButter5000.txt";
		}
		$file2= "$testFilterFileNameWithDir";
		$result = compare ($file1, $file2);
		if ( $result == 0 ) {
            print "\n\nButter_5000 filter test = $result Passed\n\n";
            print $csvFileHandle "Butter_5000 filter test,Passed\r\n";
            print $testFileHandle "Butter_5000 filter test,$THREE_TABS Passed\r\n";
		}
		elsif ($result == 1) {
            print "\n\nButter_5000 filter test = $result Failed\n\n";
            print $csvFileHandle "Butter_5000 filter test,Failed\r\n";
            print $testFileHandle "Butter_5000 filter test,$THREE_TABS Failed\r\n";
		}
		elsif ($result == -1) {
            print "\n\nButter_5000 filter test = Failed $result File not found\n\n";
            print $csvFileHandle "Butter_5000 filter test,Failed\r\n";
            print $testFileHandle "Butter_5000 filter test,$THREE_TABS Failed File not found\r\n";
		}

		# processImuExcel($testFilterFileNameWithDir);

    }

    #####################################
    # set the data rate to 3600 if a 1775IMU, IRST, 1760DSPU
    if ( (index($deviceName,'1775') != -1) || (index($deviceName,'IRS') != -1) || (index($deviceName,'DSPU') != -1)) {
		$dataValue = "3600";
		TestSetDR($portTest,$dataValue,1,$csvFileHandle,$testFileHandle);

		# test the cheby filter here
		# set the filter type for the accels to cheby and verify response
		if ( (index($deviceName,'1775') != -1)) {
			TestFilterTypeSet($portTest, "a","cheby",$csvFileHandle,$testFileHandle);
		}

		# set the filter type for the gyros to cheby and verify response
		TestFilterTypeSet($portTest, "g","cheby",$csvFileHandle,$testFileHandle);
		$testFilterFileName = $deviceName . "_Cheby_3600.txt";
		$testFilterFileNameWithDir = $newTestDir . $testFilterFileName;
		open $testFilterFileHandle, '>', $testFilterFileNameWithDir or die "Couldn't open file IMU1775_Cheby_3600.txt, $!";
		TestFilter($portTest, $testFilterFileHandle,$csvFileHandle);
		close($testFilterFileHandle); # close the file handle
		print "\n\nTEST_FILTER:  OUTPUT FILE  = $testFilterFileNameWithDir\n\n";

		# Compare Filter Test File with Known good file to determine pass or fail

		if ( (index($deviceName,'1775') != -1)) {
        $file1 = "./TestFilterFiles/1775IMUCheby3600.txt";
		}
		else {
			$file1 = "./TestFilterFiles/IRSCheby3600.txt";
		}
	    $file2= "$testFilterFileNameWithDir";
		$result = compare ($file1, $file2);
		if ( $result == 0 ) {
            print "\n\nCheby_3600 filter test = $result Passed\n\n";
            print $csvFileHandle "Cheby_3600 filter test,Passed\r\n";
            print $testFileHandle "Cheby_3600 filter test,$THREE_TABS Passed\r\n";
		}
		elsif ($result == 1) {
            print "\n\nCheby_3600 filter test = $result Failed\n\n";
            print $csvFileHandle "Cheby_3600 filter test,Failed\r\n";
            print $testFileHandle "Cheby_3600 filter test,$THREE_TABS Failed\r\n";
		}
		elsif ($result == -1) {
            print "\n\nCheby_3600 filter test = Failed $result File not found\n\n";
            print $csvFileHandle "Cheby_3600 filter test,Failed\r\n";
            print $testFileHandle "Cheby_3600 filter test,$THREE_TABS Failed File not found\r\n";
		}

		# processImuExcel($testFilterFileNameWithDir);

		# test the butter filter here
		# set the filter type for the accels to butter and verify response
		if ( (index($deviceName,'1775') != -1)) {
			TestFilterTypeSet($portTest, "a","butter",$csvFileHandle,$testFileHandle);
		}

		# set the filter type for the gyros to butter and verify response
		TestFilterTypeSet($portTest, "g","butter",$csvFileHandle,$testFileHandle);
		$testFilterFileName = $deviceName . "_Butter_3600.txt";
		$testFilterFileNameWithDir = $newTestDir . $testFilterFileName;
		open $testFilterFileHandle, '>', $testFilterFileNameWithDir or die "Couldn't open file IMU1775_Butter_3600.txt, $!";
		TestFilter($portTest, $testFilterFileHandle,$csvFileHandle,$testFileHandle);
		close($testFilterFileHandle); # close the file handle
		print "\n\nTEST_FILTER:  OUTPUT FILE  = $testFilterFileNameWithDir\n\n";

		# Compare Filter Test File with Known good file to determine pass or fail
		if ( (index($deviceName,'1775') != -1)) {
	       $file1 = "./TestFilterFiles/1775IMUButter3600.txt";
		}
		else {
			$file1 = "./TestFilterFiles/IRSButter3600.txt";
		}
		$file2= "$testFilterFileNameWithDir";
		$result = compare ($file1, $file2);
		if ( $result == 0 ) {
            print "\n\nButter_3600 filter test = $result Passed\n\n";
            print $csvFileHandle "Butter_3600 filter test,Passed\r\n";
            print $testFileHandle "Butter_3600 filter test,$THREE_TABS Passed\r\n";
		}
		elsif ($result == 1) {
            print "\n\nButter_3600 filter test = $result Failed\n\n";
            print $csvFileHandle "Butter_3600 filter test,Failed\r\n";
            print $testFileHandle "Butter_3600 filter test,$THREE_TABS Failed\r\n";
		}
		elsif ($result == -1) {
            print "\n\nButter_3600 filter test = Failed $result File not found\n\n";
            print $csvFileHandle "Butter_3600 filter test,Failed\r\n";
            print $testFileHandle "Butter_3600 filter test,$THREE_TABS Failed File not found\r\n";
		}

		# processImuExcel($testFilterFileNameWithDir);
    }

    #####################################
    # set the data rate to 1000
    $dataValue = "1000";
    TestSetDR($portTest,$dataValue,1,$csvFileHandle,$testFileHandle);

    # test the cheby filter here
    # set the filter type for the accels to cheby and verify response
	if ( (index($deviceName,'1775') != -1 )||(index($deviceName,'1750') != -1 ) || (index($deviceName,'1725') != -1 ) ) {
		TestFilterTypeSet($portTest, "a","cheby",$csvFileHandle,$testFileHandle);
	}

    # set the filter type for the gyros to cheby and verify response
    TestFilterTypeSet($portTest, "g","cheby",$csvFileHandle,$testFileHandle);
    $testFilterFileName = $deviceName . "_Cheby_1000.txt";
    $testFilterFileNameWithDir = $newTestDir . $testFilterFileName;
    open $testFilterFileHandle, '>', $testFilterFileNameWithDir or die "Couldn't open file IMU1775_Cheby_1000.txt, $!";
    TestFilter($portTest, $testFilterFileHandle,$csvFileHandle);
    close($testFilterFileHandle); # close the file handle
    print "\n\nTEST_FILTER:  OUTPUT FILE  = $testFilterFileNameWithDir\n\n";

    # Compare Filter Test File with Known good file to determine pass or fail

    if ( (index($deviceName,'1775') != -1)) {
        $file1 = "./TestFilterFiles/1775IMUCheby1000.txt";
    }
    elsif ( (index($deviceName,'IRS') != -1) || (index($deviceName,'DSPU') != -1)) {

        $file1 = "./TestFilterFiles/IRSCheby1000.txt";
    }

    elsif ( (index($deviceName,'DSP') != -1)) {

        $file1 = "./TestFilterFiles/DSP1760Cheby1000.txt";
    }
    elsif ( (index($deviceName,'1725') != -1) || (index($deviceName,'1750') != -1)){
        $file1 = "./TestFilterFiles/1725IMUCheby1000.txt";
    }
    $file2= "$testFilterFileNameWithDir";
    $result = compare ($file1, $file2);
       if ( $result == 0 ) {
            print "\n\nCheby_1000 filter test = $result Passed\n\n";
            print $csvFileHandle "Cheby_1000 filter test,Passed\r\n";
            print $testFileHandle "Cheby_1000 filter test,$THREE_TABS Passed\r\n";
       }
       elsif ($result == 1) {
            print "\n\nCheby_1000 filter test = $result Failed\n\n";
            print $csvFileHandle "Cheby_1000 filter test,Failed\r\n";
            print $testFileHandle "Cheby_1000 filter test,$THREE_TABS Failed\r\n";
       }
       elsif ($result == -1) {
            print "\n\nCheby_1000 filter test = Failed $result File not found\n\n";
            print $csvFileHandle "Cheby_1000 filter test,Failed\r\n";
            print $testFileHandle "Cheby_1000 filter test,$THREE_TABS Failed File not found\r\n";
       }

    # processImuExcel($testFilterFileNameWithDir);

    # test the butter filter here
    # set the filter type for the accels to butter and verify response
	if ( (index($deviceName,'1775') != -1 )||(index($deviceName,'1750') != -1 ) || (index($deviceName,'1725') != -1 ) ) {
		TestFilterTypeSet($portTest, "a","butter",$csvFileHandle,$testFileHandle);
	}

    # set the filter type for the gyros to butter and verify response
    TestFilterTypeSet($portTest, "g","butter",$csvFileHandle,$testFileHandle);

    $testFilterFileName = $deviceName . "_Butter_1000.txt";
    $testFilterFileNameWithDir = $newTestDir . $testFilterFileName;
    open $testFilterFileHandle, '>', $testFilterFileNameWithDir or die "Couldn't open file IMU1775_Butter_1000.txt, $!";

    TestFilter($portTest, $testFilterFileHandle,$csvFileHandle,$testFileHandle);
    close($testFilterFileHandle); # close the file handle

    print "\n\nTEST_FILTER:  OUTPUT FILE  = $testFilterFileNameWithDir\n\n";

    # Compare Filter Test File with Known good file to determine pass or fail

    if ( (index($deviceName,'1775') != -1)) {

        $file1 = "./TestFilterFiles/1775IMUButter1000.txt";
    }

    elsif ( (index($deviceName,'IRS') != -1) || (index($deviceName,'DSPU') != -1)) {

        $file1 = "./TestFilterFiles/IRSButter1000.txt";
    }
    elsif ( (index($deviceName,'DSP') != -1)) {

        $file1 = "./TestFilterFiles/DSP1760Butter1000.txt";
    }
    elsif ( (index($deviceName,'1725') != -1) || (index($deviceName,'1750') != -1)){
        $file1 = "./TestFilterFiles/1725IMUButter1000.txt";
    }
    $file2= "$testFilterFileNameWithDir";
    $result = compare ($file1, $file2);
       if ( $result == 0 ) {
            print "\n\nButter_1000 filter test = $result Passed\n\n";
            print $csvFileHandle "Butter_1000 filter test,Passed\r\n";
            print $testFileHandle "Butter_1000 filter test,$THREE_TABS Passed\r\n";
       }
       elsif ($result == 1) {
            print "\n\nButter_1000 filter test = $result Failed\n\n";
           print $csvFileHandle "Butter_1000 filter test,Failed\r\n";
            print $testFileHandle "Butter_1000 filter test,$THREE_TABS Failed\r\n";
       }
       elsif ($result == -1) {
            print "\n\nButter_1000 filter test = Failed $result File not found\n\n";
            print $csvFileHandle "Butter_1000 filter test,Failed\r\n";
            print $testFileHandle "Butter_1000 filter test,$THREE_TABS Failed File not found\r\n";
       }

    # processImuExcel($testFilterFileNameWithDir);

    # test the uniform averager here
    # set the filter type for the accels to averager and verify response
	if ( (index($deviceName,'1775') != -1 )||(index($deviceName,'1750') != -1 ) || (index($deviceName,'1725') != -1 ) ) {
		TestFilterTypeSet($portTest, "a","ave",$csvFileHandle,$testFileHandle);
	}
    # set the filter type for the gyros to averager and verify response
    TestFilterTypeSet($portTest, "g","ave",$csvFileHandle,$testFileHandle);

    $testFilterFileName = $deviceName . "_Avg_1000.txt";
    $testFilterFileNameWithDir = $newTestDir . $testFilterFileName;
    open $testFilterFileHandle, '>', $testFilterFileNameWithDir or die "Couldn't open file IMU1775_Avg_10.txt, $!";

    TestFilter($portTest, $testFilterFileHandle,$csvFileHandle,$testFileHandle);
    close($testFilterFileHandle);     # close the file handle

    print "\n\nTEST_FILTER:  OUTPUT FILE  = $testFilterFileNameWithDir\n\n";

    # Compare Filter Test File with Known good file to determine pass or fail

    if ( (index($deviceName,'1775') != -1)) {

        $file1 = "./TestFilterFiles/1775IMUAvg1000.txt";
    }

    elsif ( (index($deviceName,'IRS') != -1) || (index($deviceName,'DSPU') != -1)) {

        $file1 = "./TestFilterFiles/IRSAvg1000.txt";
    }
    elsif ( (index($deviceName,'DSP') != -1)) {

        $file1 = "./TestFilterFiles/DSP1760Avg1000.txt";
    }
    elsif ( (index($deviceName,'1725') != -1) || (index($deviceName,'1750') != -1)){
        $file1 = "./TestFilterFiles/1725IMUAvg1000.txt";
    }
    $file2= "$testFilterFileNameWithDir";
    $result = compare ($file1, $file2);
       if ( $result == 0 ) {
            print "\n\nAvg_1000 filter test = $result Passed\n\n";
            print $csvFileHandle "Avg_1000 filter test,Passed\r\n";
            print $testFileHandle "Avg_1000 filter test,$THREE_TABS Passed\r\n";
       }
       elsif ($result == 1) {
            print "\n\nAvg_1000 filter test = $result Failed\n\n";
            print $csvFileHandle "Avg_1000 filter test,Failed\r\n";
            print $testFileHandle "Avg_1000 filter test,$THREE_TABS Failed\r\n";
       }
       elsif ($result == -1) {
            print "\n\nAvg_1000 filter test = Failed $result File not found\n\n";
            print $csvFileHandle "Avg_1000 filter test,Failed\r\n";
            print $testFileHandle "Avg_1000 filter test,$THREE_TABS Failed File not found\r\n";
       }

    # processImuExcel($testFilterFileNameWithDir);

    #####################################
    # set the data rate to 100
    $dataValue = "100";
    TestSetDR($portTest,$dataValue,1,$csvFileHandle,$testFileHandle);

    # test the cheby filter here
    # set the filter type for the accels to cheby and verify response
	if ( (index($deviceName,'1775') != -1 )||(index($deviceName,'1750') != -1 ) || (index($deviceName,'1725') != -1 ) ) {
		TestFilterTypeSet($portTest, "a","cheby",$csvFileHandle,$testFileHandle);
	}
    # set the filter type for the gyros to cheby and verify response
    TestFilterTypeSet($portTest, "g","cheby",$csvFileHandle,$testFileHandle);

    $testFilterFileName = $deviceName . "_Cheby_100.txt";
    $testFilterFileNameWithDir = $newTestDir . $testFilterFileName;
    open $testFilterFileHandle, '>', $testFilterFileNameWithDir or die "Couldn't open file IMU1775_Cheby_100.txt, $!";

    TestFilter($portTest, $testFilterFileHandle,$csvFileHandle,$testFileHandle);
    close($testFilterFileHandle);     # close the file handle

    print "\n\nTEST_FILTER:  OUTPUT FILE  = $testFilterFileNameWithDir\n\n";

    # Compare Filter Test File with Known good file to determine pass or fail

    if ( (index($deviceName,'1775') != -1)) {

        $file1 = "./TestFilterFiles/1775IMUCheby100.txt";
    }

    elsif ( (index($deviceName,'IRS') != -1) || (index($deviceName,'DSPU') != -1)) {

        $file1 = "./TestFilterFiles/IRSCheby100.txt";
    }
    elsif ( (index($deviceName,'DSP') != -1)) {

        $file1 = "./TestFilterFiles/DSP1760Cheby100.txt";
    }
    elsif ( (index($deviceName,'1725') != -1) || (index($deviceName,'1750') != -1)){
        $file1 = "./TestFilterFiles/1725IMUCheby100.txt";
    }
    $file2= "$testFilterFileNameWithDir";
    $result = compare ($file1, $file2);
       if ( $result == 0 ) {
            print "\n\nCheby_100 filter test = $result Passed\n\n";
            print $csvFileHandle "Cheby_100 filter test,Passed\r\n";
            print $testFileHandle "Cheby_100 filter test,$THREE_TABS Passed\r\n";
       }
       elsif ($result == 1) {
            print "\n\nCheby_100 filter test = $result Failed\n\n";
            print $csvFileHandle "Cheby_100 filter test,Failed\r\n";
            print $testFileHandle "Cheby_100 filter test,$THREE_TABS Failed\r\n";
       }
       elsif ($result == -1) {
            print "\n\nCheby_100 filter test = Failed $result File not found\n\n";
            print $csvFileHandle "Cheby_100 filter test,Failed\r\n";
            print $testFileHandle "Cheby_100 filter test,$THREE_TABS Failed File not found\r\n";
       }

    # processImuExcel($testFilterFileNameWithDir);

    # test the Butter filter here
    # set the filter type for the accels to butter and verify response
	if ( (index($deviceName,'1775') != -1 )||(index($deviceName,'1750') != -1 ) || (index($deviceName,'1725') != -1 ) ) {
		TestFilterTypeSet($portTest, "a","butter",$csvFileHandle,$testFileHandle);
	}
    # set the filter type for the gyros to butter and verify response
    TestFilterTypeSet($portTest, "g","butter",$csvFileHandle,$testFileHandle);

    $testFilterFileName = $deviceName . "_Butter_100.txt";
    $testFilterFileNameWithDir = $newTestDir . $testFilterFileName;
    open $testFilterFileHandle, '>', $testFilterFileNameWithDir or die "Couldn't open file IMU1775_Butter_100.txt, $!";

    TestFilter($portTest, $testFilterFileHandle,$csvFileHandle,$testFileHandle);
    close($testFilterFileHandle); # close the file handle

    print "\n\nTEST_FILTER:  OUTPUT FILE  = $testFilterFileNameWithDir\n\n";

    # Compare Filter Test File with Known good file to determine pass or fail

    if ( (index($deviceName,'1775') != -1)) {

        $file1 = "./TestFilterFiles/1775IMUButter100.txt";
    }

    elsif ( (index($deviceName,'IRS') != -1) || (index($deviceName,'DSPU') != -1)) {

        $file1 = "./TestFilterFiles/IRSButter100.txt";
    }
    elsif ( (index($deviceName,'DSP') != -1)) {

        $file1 = "./TestFilterFiles/DSP1760Butter100.txt";
    }
    elsif ( (index($deviceName,'1725') != -1) || (index($deviceName,'1750') != -1)) {
        $file1 = "./TestFilterFiles/1725IMUButter100.txt";
    }
    $file2= "$testFilterFileNameWithDir";
    $result = compare ($file1, $file2);
       if ( $result == 0 ) {
            print "\n\nButter_100 filter test = $result Passed\n\n";
            print $csvFileHandle "Butter_100 filter test,Passed\r\n";
            print $testFileHandle "Butter_100 filter test,$THREE_TABS Passed\r\n";
       }
       elsif ($result == 1) {
            print "\n\nButter_100 filter test = $result Failed\n\n";
            print $csvFileHandle "Butter_100 filter test,Failed\r\n";
            print $testFileHandle "Butter_100 filter test,$THREE_TABS Failed\r\n";
       }
       elsif ($result == -1) {
            print "\n\nButter_100 filter test = Failed $result File not found\n\n";
            print $csvFileHandle "Butter_100 filter test,Failed\r\n";
            print $testFileHandle "Butter_100 filter test,$THREE_TABS Failed File not found\r\n";
       }

    # processImuExcel($testFilterFileNameWithDir);

    #####################################
    # set the data rate to 50
    $dataValue = "50";
    TestSetDR($portTest,$dataValue,1,$csvFileHandle,$testFileHandle);

    # test the cheby filter here
    # set the filter type for the accels to cheby and verify response
	if ( (index($deviceName,'1775') != -1 )||(index($deviceName,'1750') != -1 ) || (index($deviceName,'1725') != -1 ) ) {
		TestFilterTypeSet($portTest, "a","cheby",$csvFileHandle,$testFileHandle);
	}
    # set the filter type for the gyros to cheby and verify response
    TestFilterTypeSet($portTest, "g","cheby",$csvFileHandle,$testFileHandle);

    $testFilterFileName = $deviceName . "_Cheby_50.txt";
    $testFilterFileNameWithDir = $newTestDir . $testFilterFileName;
    open $testFilterFileHandle, '>', $testFilterFileNameWithDir or die "Couldn't open file IMU1775_Cheby_50.txt, $!";

    TestFilter($portTest, $testFilterFileHandle,$csvFileHandle,$testFileHandle);
    close($testFilterFileHandle);     # close the file handle

    print "\n\nTEST_FILTER:  OUTPUT FILE  = $testFilterFileNameWithDir\n\n";

    # Compare Filter Test File with Known good file to determine pass or fail

    if ( (index($deviceName,'1775') != -1)) {

        $file1 = "./TestFilterFiles/1775IMUCheby50.txt";
    }

    elsif ( (index($deviceName,'IRS') != -1) || (index($deviceName,'DSPU') != -1)) {

        $file1 = "./TestFilterFiles/IRSCheby50.txt";
    }
    elsif ( (index($deviceName,'DSP') != -1)) {

        $file1 = "./TestFilterFiles/DSP1760Cheby50.txt";
    }
    elsif ( (index($deviceName,'1725') != -1) || (index($deviceName,'1750') != -1)){
        $file1 = "./TestFilterFiles/1725IMUCheby50.txt";
    }
    $file2= "$testFilterFileNameWithDir";
    $result = compare ($file1, $file2);
       if ( $result == 0 ) {
            print "\n\nCheby_50 filter test = $result Passed\n\n";
            print $csvFileHandle "Cheby_50 filter test,Passed\r\n";
            print $testFileHandle "Cheby_50 filter test,$THREE_TABS Passed\r\n";
       }
       elsif ($result == 1) {
            print "\n\ncheby_50 filter test = $result Failed\n\n";
            print $csvFileHandle "Cheby_50 filter test,Failed\r\n";
            print $testFileHandle "Cheby_50 filter test,$THREE_TABS Failed\r\n";
       }
       elsif ($result == -1) {
            print "\n\nCheby_50 filter test = Failed $result File not found\n\n";
            print $csvFileHandle "Cheby_50 filter test,Failed\r\n";
            print $testFileHandle "Cheby_50 filter test,$THREE_TABS Failed File not found\r\n";
       }

    # processImuExcel($testFilterFileNameWithDir);

    # test the butter filter here
    # set the filter type for the accels to butter and verify response
	if ( (index($deviceName,'1775') != -1 )||(index($deviceName,'1750') != -1 ) || (index($deviceName,'1725') != -1 ) ) {
		TestFilterTypeSet($portTest, "a","butter",$csvFileHandle,$testFileHandle);
	}
    # set the filter type for the gyros to butter and verify response
    TestFilterTypeSet($portTest, "g","butter",$csvFileHandle,$testFileHandle);

    $testFilterFileName = $deviceName . "_Butter_50.txt";
    $testFilterFileNameWithDir = $newTestDir . $testFilterFileName;
    open $testFilterFileHandle, '>', $testFilterFileNameWithDir or die "Couldn't open file IMU1775_Butter_50.txt, $!";

    TestFilter($portTest, $testFilterFileHandle,$csvFileHandle,$testFileHandle);
    close($testFilterFileHandle); # close the file handle

    print "\n\nTEST_FILTER:  OUTPUT FILE  = $testFilterFileNameWithDir\n\n";

    # Compare Filter Test File with Known good file to determine pass or fail

    if ( (index($deviceName,'1775') != -1)) {

        $file1 = "./TestFilterFiles/1775IMUButter50.txt";
    }

    elsif ( (index($deviceName,'IRS') != -1) || (index($deviceName,'DSPU') != -1)) {

        $file1 = "./TestFilterFiles/IRSButter50.txt";
    }
    elsif ( (index($deviceName,'DSP') != -1)) {

        $file1 = "./TestFilterFiles/DSP1760Butter50.txt";
    }
    elsif ( (index($deviceName,'1725') != -1) || (index($deviceName,'1750') != -1)){
        $file1 = "./TestFilterFiles/1725IMUButter50.txt";
    }
    $file2= "$testFilterFileNameWithDir";
    $result = compare ($file1, $file2);
       if ( $result == 0 ) {
            print "\n\nButter_50 filter test = $result Passed\n\n";
            print $csvFileHandle "Butter_50 filter test,Passed\r\n";
            print $testFileHandle "Butter_50 filter test,$THREE_TABS Passed\r\n";
       }
       elsif ($result == 1) {
            print "\n\nButter_50 filter test = $result Failed\n\n";
            print $csvFileHandle "Butter_50 filter test,Failed\r\n";
            print $testFileHandle "Butter_50 filter test,$THREE_TABS Failed\r\n";
       }
       elsif ($result == -1) {
            print "\n\nButter_50 filter test = Failed $result File not found\n\n";
            print $csvFileHandle "Butter_50 filter test,Failed\r\n";
            print $testFileHandle "Butter_50 filter test,$THREE_TABS Failed File not found\r\n";
       }

    # processImuExcel($testFilterFileNameWithDir);

    #####################################
    # set the data rate to 10
    $dataValue = "10";
    TestSetDR($portTest,$dataValue,1,$csvFileHandle,$testFileHandle);

    # test the cheby filter here
    # set the filter type for the accels to cheby and verify response
	if ( (index($deviceName,'1775') != -1 )||(index($deviceName,'1750') != -1 ) || (index($deviceName,'1725') != -1 ) ) {
		TestFilterTypeSet($portTest, "a","cheby",$csvFileHandle,$testFileHandle);
	}
    # set the filter type for the gyros to cheby and verify response
    TestFilterTypeSet($portTest, "g","cheby",$csvFileHandle,$testFileHandle);

    $testFilterFileName = $deviceName . "_Cheby_10.txt";
    $testFilterFileNameWithDir = $newTestDir . $testFilterFileName;
    open $testFilterFileHandle, '>', $testFilterFileNameWithDir or die "Couldn't open file IMU1775_Cheby_10.txt, $!";

    TestFilter($portTest, $testFilterFileHandle,$csvFileHandle);
    close($testFilterFileHandle);     # close the file handle

    print "\n\nTEST_FILTER:  OUTPUT FILE  = $testFilterFileNameWithDir\n\n";

    # Compare Filter Test File with Known good file to determine pass or fail

    if ( (index($deviceName,'1775') != -1)) {

        $file1 = "./TestFilterFiles/1775IMUCheby10.txt";
    }

    elsif ( (index($deviceName,'IRS') != -1) || (index($deviceName,'DSPU') != -1)) {

        $file1 = "./TestFilterFiles/IRSCheby10.txt";
    }
    elsif ( (index($deviceName,'DSP') != -1)) {

        $file1 = "./TestFilterFiles/DSP1760Cheby10.txt";
    }
    elsif ( (index($deviceName,'1725') != -1) || (index($deviceName,'1750') != -1)){
        $file1 = "./TestFilterFiles/1725IMUCheby10.txt";
    }
    $file2= "$testFilterFileNameWithDir";
    $result = compare ($file1, $file2);
       if ( $result == 0 ) {
            print "\n\nCheby_10 filter test = $result Passed\n\n";
            print $csvFileHandle "Cheby_10 filter test,Passed\r\n";
            print $testFileHandle "Cheby_10 filter test,$THREE_TABS Passed\r\n";
       }
       elsif ($result == 1) {
            print "\n\nCheby_10 filter test = $result Failed\n\n";
            print $csvFileHandle "Cheby_10 filter test,Failed\r\n";
            print $testFileHandle "Cheby_10 filter test,$THREE_TABS Failed\r\n";
       }
       elsif ($result == -1) {
            print "\n\nCheby_10 filter test = Failed $result File not found\n\n";
            print $csvFileHandle "Cheby_10 filter test,Failed\r\n";
            print $testFileHandle "Cheby_10 filter test,$THREE_TABS Failed File not found\r\n";
       }

    # processImuExcel($testFilterFileNameWithDir);

    # test the butter filter here
    # set the filter type for the accels to butter and verify response
	if ( (index($deviceName,'1775') != -1 )||(index($deviceName,'1750') != -1 ) || (index($deviceName,'1725') != -1 ) ) {
		TestFilterTypeSet($portTest, "a","butter",$csvFileHandle,$testFileHandle);
	}
    # set the filter type for the gyros to butter and verify response
    TestFilterTypeSet($portTest, "g","butter",$csvFileHandle,$testFileHandle);

    $testFilterFileName = $deviceName . "_Butter_10.txt";
    $testFilterFileNameWithDir = $newTestDir . $testFilterFileName;
    open $testFilterFileHandle, '>', $testFilterFileNameWithDir or die "Couldn't open file IMU1775_Butter_10.txt, $!";

    TestFilter($portTest, $testFilterFileHandle,$csvFileHandle,$testFileHandle);
    close($testFilterFileHandle); # close the file handle

    print "\n\nTEST_FILTER:  OUTPUT FILE  = $testFilterFileNameWithDir\n\n";

    # Compare Filter Test File with Known good file to determine pass or fail

    if ( (index($deviceName,'1775') != -1)) {

        $file1 = "./TestFilterFiles/1775IMUButter10.txt";
    }

    elsif ( (index($deviceName,'IRS') != -1) || (index($deviceName,'DSPU') != -1)) {

        $file1 = "./TestFilterFiles/IRSButter10.txt";
    }
    elsif ( (index($deviceName,'DSP') != -1)) {

        $file1 = "./TestFilterFiles/DSP1760Butter10.txt";
    }
    elsif ( (index($deviceName,'1725') != -1) || (index($deviceName,'1750') != -1)){
        $file1 = "./TestFilterFiles/1725IMUButter10.txt";
    }
    $file2= "$testFilterFileNameWithDir";
    $result = compare ($file1, $file2);
       if ( $result == 0 ) {
            print "\n\nButter_10 filter test = $result Passed\n\n";
            print $csvFileHandle "Butter_10 filter test,Passed\r\n";
            print $testFileHandle "Butter_10 filter test,$THREE_TABS Passed\r\n";
       }
       elsif ($result == 1) {
            print "\n\nButter_10 filter test = $result Failed\n\n";
            print $csvFileHandle "Butter_10 filter test,Failed\r\n";
            print $testFileHandle "Butter_10 filter test,$THREE_TABS Failed\r\n";
       }
       elsif ($result == -1) {
            print "\n\nButter_10 filter test = Failed $result File not found\n\n";
            print $csvFileHandle "Butter_10 filter test,Failed\r\n";
            print $testFileHandle "Butter_10 filter test,$THREE_TABS Failed File not found\r\n";
       }

    # processImuExcel($testFilterFileNameWithDir);


    # test the uniform averager here
    # set the filter type for the accels to averager and verify response
	if ( (index($deviceName,'1775') != -1 )||(index($deviceName,'1750') != -1 ) || (index($deviceName,'1725') != -1 ) ) {
		TestFilterTypeSet($portTest, "a","ave",$csvFileHandle,$testFileHandle);
	}
    # set the filter type for the gyros to averager and verify response
    TestFilterTypeSet($portTest, "g","ave",,$csvFileHandle,$testFileHandle);

    $testFilterFileName = $deviceName . "_Avg_10.txt";
    $testFilterFileNameWithDir = $newTestDir . $testFilterFileName;
    open $testFilterFileHandle, '>', $testFilterFileNameWithDir or die "Couldn't open file IMU1775_Avg_10.txt, $!";

    TestFilter($portTest, $testFilterFileHandle,$csvFileHandle,$testFileHandle);
    close($testFilterFileHandle);     # close the file handle

    print "\n\nTEST_FILTER:  OUTPUT FILE  = $testFilterFileNameWithDir\n\n";

    # Compare Filter Test File with Known good file to determine pass or fail

    if ( (index($deviceName,'1775') != -1)) {

        $file1 = "./TestFilterFiles/1775IMUAvg10.txt";
    }

    elsif ( (index($deviceName,'IRS') != -1) || (index($deviceName,'DSPU') != -1)) {

        $file1 = "./TestFilterFiles/IRSAvg10.txt";
    }
    elsif ( (index($deviceName,'DSP') != -1)) {

        $file1 = "./TestFilterFiles/DSP1760Avg10.txt";
    }
    elsif ( (index($deviceName,'1725') != -1) || (index($deviceName,'1750') != -1)){
        $file1 = "./TestFilterFiles/1725IMUAvg10.txt";
    }
    $file2= "$testFilterFileNameWithDir";
    $result = compare ($file1, $file2);
       if ( $result == 0 ) {
            print "\n\nAvg_10 filter test = $result,$THREE_TABS Passed\n\n";
            print $csvFileHandle "Avg_10 filter test,Passed\r\n";
            print $testFileHandle "Avg_10 filter test, Passed\r\n";
       }
       elsif ($result == 1) {
            print "\n\nAvg_10 filter test = $result $THREE_TABS Failed\n\n";
            print $csvFileHandle "Avg_10 filter test,Failed\r\n";
            print $testFileHandle "Avg_10 filter test, Failed\r\n";
       }
       elsif ($result == -1) {
            print "\n\nAvg_10 filter test = $result $THREE_TABS Failed File not found\n\n";
            print $csvFileHandle "Avg_10 filter test,Failed\r\n";
            print $testFileHandle "Avg_10 filter test, Failed File not found\r\n";
       }

    # processImuExcel($testFilterFileNameWithDir);

    #####################################
    # set the data rate to 5
    $dataValue = "5";
    TestSetDR($portTest,$dataValue,1,$csvFileHandle,$testFileHandle);

    # test the cheby filter here
    # set the filter type for the accels to cheby and verify response
	if ( (index($deviceName,'1775') != -1 )||(index($deviceName,'1750') != -1 ) || (index($deviceName,'1725') != -1 ) ) {
		TestFilterTypeSet($portTest, "a","cheby",$csvFileHandle,$testFileHandle);
	}
    # set the filter type for the gyros to cheby and verify response
    TestFilterTypeSet($portTest, "g","cheby",$csvFileHandle,$testFileHandle);

    $testFilterFileName = $deviceName . "_Cheby_5.txt";
    $testFilterFileNameWithDir = $newTestDir . $testFilterFileName;
    open $testFilterFileHandle, '>', $testFilterFileNameWithDir or die "Couldn't open file IMU1775_Cheby_5.txt, $!";

    TestFilter($portTest, $testFilterFileHandle,$csvFileHandle,$testFileHandle);
    close($testFilterFileHandle);     # close the file handle

    print "\n\nTEST_FILTER:  OUTPUT FILE  = $testFilterFileNameWithDir\n\n";

    # Compare Filter Test File with Known good file to determine pass or fail

    if ( (index($deviceName,'1775') != -1)) {

        $file1 = "./TestFilterFiles/1775IMUCheby5.txt";
    }

    elsif ( (index($deviceName,'IRS') != -1) || (index($deviceName,'DSPU') != -1)) {

        $file1 = "./TestFilterFiles/IRSCheby5.txt";
    }
    elsif ( (index($deviceName,'DSP') != -1)) {

        $file1 = "./TestFilterFiles/DSP1760Cheby5.txt";
    }
    elsif ( (index($deviceName,'1725') != -1) || (index($deviceName,'1750') != -1)){
        $file1 = "./TestFilterFiles/1725IMUCheby5.txt";
    }
    $file2= "$testFilterFileNameWithDir";
    $result = compare ($file1, $file2);
       if ( $result == 0 ) {
            print "\n\nCheby_5 filter test = $result $THREE_TABS Passed\n\n";
            print $csvFileHandle "Cheby_5 filter test,Passed\r\n";
            print $testFileHandle "Cheby_5 filter test, Passed\r\n";
       }
       elsif ($result == 1) {
            print "\n\nCheby_5 filter test = $result $THREE_TABS Failed\n\n";
            print $csvFileHandle "Cheby_5 filter test,Failed\r\n";
            print $testFileHandle "Cheby_5 filter test, Failed\r\n";
       }
       elsif ($result == -1) {
            print "\n\nCheby_5 filter test = $result $THREE_TABS Failed File not found\n\n";
            print $csvFileHandle "Cheby_5 filter test,Failed\r\n";
            print $testFileHandle "Cheby_5 filter test, Failed File not found\r\n";
       }

    # processImuExcel($testFilterFileNameWithDir);

    # test the butter filter here
    # set the filter type for the accels to butter and verify response
	if ( (index($deviceName,'1775') != -1 )||(index($deviceName,'1750') != -1 ) || (index($deviceName,'1725') != -1 ) ) {
		TestFilterTypeSet($portTest, "a","butter",$csvFileHandle,$testFileHandle);
	}
    # set the filter type for the gyros to butter and verify response
    TestFilterTypeSet($portTest, "g","butter",$csvFileHandle,$testFileHandle);

    $testFilterFileName = $deviceName . "_Butter_5.txt";
    $testFilterFileNameWithDir = $newTestDir . $testFilterFileName;
    open $testFilterFileHandle, '>', $testFilterFileNameWithDir or die "Couldn't open file IMU1775_Butter_5.txt, $!";

    TestFilter($portTest, $testFilterFileHandle,$csvFileHandle);
    close($testFilterFileHandle); # close the file handle

    print "\n\nTEST_FILTER:  OUTPUT FILE  = $testFilterFileNameWithDir\n\n";

    # Compare Filter Test File with Known good file to determine pass or fail

    if ( (index($deviceName,'1775') != -1)) {

        $file1 = "./TestFilterFiles/1775IMUButter5.txt";
    }

    elsif ( (index($deviceName,'IRS') != -1) || (index($deviceName,'DSPU') != -1)) {

        $file1 = "./TestFilterFiles/IRSButter5.txt";
    }
    elsif ( (index($deviceName,'DSP') != -1)) {

        $file1 = "./TestFilterFiles/DSP1760Butter5.txt";
    }
    elsif ( (index($deviceName,'1725') != -1) || (index($deviceName,'1750') != -1)){
        $file1 = "./TestFilterFiles/1725IMUButter5.txt";
    }
    $file2= "$testFilterFileNameWithDir";
    $result = compare ($file1, $file2);
       if ( $result == 0 ) {
            print "\n\nButter_5 filter test = $result $THREE_TABS Passed\n\n";
            print $csvFileHandle "Butter_5 filter test,Passed\r\n";
            print $testFileHandle "Butter_5 filter test, Passed\r\n";
       }
       elsif ($result == 1) {
            print "\n\nButter_5 filter test = $result $THREE_TABS Failed\n\n";
            print $csvFileHandle "Butter_5 filter test,Failed\r\n";
            print $testFileHandle "Butter_5 filter test, Failed\r\n";
       }
       elsif ($result == -1) {
            print "\n\nButter_5 filter test = $result $THREE_TABS Failed File not found\n\n";
            print $csvFileHandle "Butter_5 filter test,Failed\r\n";
            print $testFileHandle "Butter_5 filter test, Failed File not found\r\n";
       }
	##################################################################
    # Custom Filters for 1775IMU, DSPU DR=1000 for all custom filter tests
	if ( (index($deviceName,'1775') != -1) || (index($deviceName,'DSPU') != -1)) {
		$dataValue = "1000";
		TestSetDR($portTest,$dataValue,1,$csvFileHandle,$testFileHandle);

		# test the custom filter here
		# cheby,1,0.1,5
		if ( (index($deviceName,'1775') != -1)) {
			# set the filter type for the accels to cheby and verify response
			TestFilterTypeSet($portTest, "a","cheby,1,0.1,5",$csvFileHandle,$testFileHandle);
		}
		# set the filter type for the gyros to cheby and verify response
		TestFilterTypeSet($portTest, "g","cheby,1,0.1,5",$csvFileHandle,$testFileHandle);

		$testFilterFileName = $deviceName . "_Cheby,1,0.1,5.txt";
		$testFilterFileNameWithDir = $newTestDir . $testFilterFileName;
		open $testFilterFileHandle, '>', $testFilterFileNameWithDir or die "Couldn't open file IMU1775_Cheby,1,0.1,5.txt $!";

		TestFilter($portTest, $testFilterFileHandle,$csvFileHandle,$testFileHandle);
		close($testFilterFileHandle);     # close the file handle

		print "\n\nTEST_FILTER:  OUTPUT FILE  = $testFilterFileNameWithDir\n\n";

		# Compare Filter Test File with Known good file to determine pass or fail
		if ( (index($deviceName,'1775') != -1)) {
			$file1 = "./TestFilterFiles/1775IMUCheby,1,0.1,5.txt";
		}
		else {
			$file1 = "./TestFilterFiles/DSPUCheby,1,0.1,5.txt";
		}
		$file2= "$testFilterFileNameWithDir";
		$result = compare ($file1, $file2);
       if ( $result == 0 ) {
            print "\n\nCheby,1,0.1,5 Test = $result $THREE_TABS Passed\n\n";
            print $csvFileHandle "Cheby_1_0.1_5 Test,Passed\r\n";
            print $testFileHandle "Cheby,1,0.1,5 Test, Passed\r\n";
       }
       elsif ($result == 1) {
            print "\n\nCheby,1,0.1,5 Test = $result $THREE_TABS Failed\n\n";
            print $csvFileHandle "Cheby_1_0.1_5 Test,Failed\r\n";
            print $testFileHandle "Cheby,1,0.1,5 Test, Failed\r\n";
       }
       elsif ($result == -1) {
            print "\n\nCheby,1,0.1,5 Test = $result $THREE_TABS Failed File not found\n\n";
            print $csvFileHandle "Cheby_1_0.1_5 Test,Failed\r\n";
            print $testFileHandle "Cheby,1,0.1,5 Test, Failed File not found\r\n";
       }
	   # test the custom filter here
		# cheby,2,0.03,50
		if ( (index($deviceName,'1775') != -1)) {
			# set the filter type for the accels to cheby and verify response
			TestFilterTypeSet($portTest, "a","cheby,2,0.03,50",$csvFileHandle,$testFileHandle);
		}
					
		# set the filter type for the gyros to cheby and verify response
		TestFilterTypeSet($portTest, "g","cheby,2,0.03,50",$csvFileHandle,$testFileHandle);

		$testFilterFileName = $deviceName . "_Cheby,2,0.03,50.txt";
		$testFilterFileNameWithDir = $newTestDir . $testFilterFileName;
		open $testFilterFileHandle, '>', $testFilterFileNameWithDir or die "Couldn't open file IMU1775_Cheby,2,0.03,50.txt $!";

		TestFilter($portTest, $testFilterFileHandle,$csvFileHandle,$testFileHandle);
		close($testFilterFileHandle);     # close the file handle

		print "\n\nTEST_FILTER:  OUTPUT FILE  = $testFilterFileNameWithDir\n\n";

		# Compare Filter Test File with Known good file to determine pass or fail
		if ( (index($deviceName,'1775') != -1)) {
			$file1 = "./TestFilterFiles/1775IMUCheby,2,0.03,50.txt";
		}
		else {
			$file1 = "./TestFilterFiles/DSPUCheby,2,0.03,50.txt";
		}
		$file2= "$testFilterFileNameWithDir";
		$result = compare ($file1, $file2);
       if ( $result == 0 ) {
            print "\n\nCheby,2,0.03,50 Test = $result $THREE_TABS Passed\n\n";
            print $csvFileHandle "Cheby_2_0.03_50 Test,Passed\r\n";
            print $testFileHandle "Cheby,2,0.03,50 Test, Passed\r\n";
       }
       elsif ($result == 1) {
            print "\n\nCheby,2,0.03,50 Test = $result $THREE_TABS Failed\n\n";
            print $csvFileHandle "Cheby_2_0.03_50 Test,Failed\r\n";
            print $testFileHandle "Cheby,2,0.03,50 Test, Failed\r\n";
       }
       elsif ($result == -1) {
            print "\n\nCheby,2,0.03,50 Test = $result $THREE_TABS FailedFile not found\n\n";
            print $csvFileHandle "Cheby_2_0.03_50 Test,Failed\r\n";
            print $testFileHandle "Cheby,2,0.03,50 Test, Failed File not found\r\n";
       }
	   # test the custom filter here
		# cheby,3,0.01,100
		if ( (index($deviceName,'1775') != -1)) {
			# set the filter type for the accels to cheby and verify response
			TestFilterTypeSet($portTest, "a","cheby,3,0.01,100",$csvFileHandle,$testFileHandle);
		}

		# set the filter type for the gyros to cheby and verify response
		TestFilterTypeSet($portTest, "g","cheby,3,0.01,100",$csvFileHandle,$testFileHandle);

		$testFilterFileName = $deviceName . "_Cheby,3,0.01,100.txt";
		$testFilterFileNameWithDir = $newTestDir . $testFilterFileName;
		open $testFilterFileHandle, '>', $testFilterFileNameWithDir or die "Couldn't open file IMU1775_Cheby,3,0.01,100.txt $!";

		TestFilter($portTest, $testFilterFileHandle,$csvFileHandle,$testFileHandle);
		close($testFilterFileHandle);     # close the file handle

		print "\n\nTEST_FILTER:  OUTPUT FILE  = $testFilterFileNameWithDir\n\n";

		# Compare Filter Test File with Known good file to determine pass or fail
		if ( (index($deviceName,'1775') != -1)) {
			$file1 = "./TestFilterFiles/1775IMUCheby,3,0.01,100.txt";
		}
		else {
			$file1 = "./TestFilterFiles/DSPUCheby,3,0.01,100.txt";
		}
		$file2= "$testFilterFileNameWithDir";
		$result = compare ($file1, $file2);
       if ( $result == 0 ) {
            print "\n\nCheby,3,0.01,100 Test = $result $THREE_TABS Passed\n\n";
            print $csvFileHandle "Cheby_3_0.01_100 Test,Passed\r\n";
            print $testFileHandle "Cheby,3,0.01,100 Test, Passed\r\n";
       }
       elsif ($result == 1) {
            print "\n\nCheby,3,0.01,100 Test = $result $THREE_TABS Failed\n\n";
            print $csvFileHandle "Cheby_3_0.01_100 Test,Failed\r\n";
            print $testFileHandle "Cheby,3,0.01,100 Test, Failed\r\n";
       }
       elsif ($result == -1) {
            print "\n\nCheby,3,0.01,100 Test = $result $THREE_TABS Failed File not found\n\n";
            print $csvFileHandle "Cheby_3_0.01_100 Test,Failed\r\n";
            print $testFileHandle "Cheby,3,0.01,100 Test, Failed File not found\r\n";
       }
	   # test the custom filter here
		# cheby,4,0.003,200
		if ( (index($deviceName,'1775') != -1)) {
			# set the filter type for the accels to cheby and verify response
			TestFilterTypeSet($portTest, "a","cheby,4,0.003,200",$csvFileHandle,$testFileHandle);
		}

		# set the filter type for the gyros to cheby and verify response
		TestFilterTypeSet($portTest, "g","cheby,4,0.003,200",$csvFileHandle,$testFileHandle);

		$testFilterFileName = $deviceName . "_Cheby,4,0.003,200.txt";
		$testFilterFileNameWithDir = $newTestDir . $testFilterFileName;
		open $testFilterFileHandle, '>', $testFilterFileNameWithDir or die "Couldn't open file IMU1775_Cheby,4,0.003,200.txt $!";

		TestFilter($portTest, $testFilterFileHandle,$csvFileHandle,$testFileHandle);
		close($testFilterFileHandle);     # close the file handle

		print "\n\nTEST_FILTER:  OUTPUT FILE  = $testFilterFileNameWithDir\n\n";

		# Compare Filter Test File with Known good file to determine pass or fail
		if ( (index($deviceName,'1775') != -1)) {
			$file1 = "./TestFilterFiles/1775IMUCheby,4,0.003,200.txt";
		}
		else {
			$file1 = "./TestFilterFiles/DSPUCheby,4,0.003,200.txt";
		}
		$file2= "$testFilterFileNameWithDir";
		$result = compare ($file1, $file2);
       if ( $result == 0 ) {
            print "\n\nCheby,4,0.003,200 Test = $result $THREE_TABS Passed\n\n";
            print $csvFileHandle "Cheby_4_0.003_200 Test,Passed\r\n";
            print $testFileHandle "Cheby_4_0.003_200 Test, Passed\r\n";
       }
       elsif ($result == 1) {
            print "\n\nCheby,4,0.003,200 Test = $result $THREE_TABS Failed\n\n";
            print $csvFileHandle "Cheby_4_0.003_200 Test,Failed\r\n";
            print $testFileHandle "Cheby,4,0.003,200 Test, Failed\r\n";
       }
       elsif ($result == -1) {
            print "\n\nCheby,4,0.003,200 Test = $result $THREE_TABS Failed File not found\n\n";
            print $csvFileHandle "Cheby_4_0.003_200 Test,Failed\r\n";
            print $testFileHandle "Cheby,4,0.003,200 Test, Failed File not found\r\n";
       }
	   # test the custom filter here
		# cheby,5,0.001,300
		if ( (index($deviceName,'1775') != -1)) {
			# set the filter type for the accels to cheby and verify response
			TestFilterTypeSet($portTest, "a","cheby,5,0.001,300",$csvFileHandle,$testFileHandle);
		}

		# set the filter type for the gyros to cheby and verify response
		TestFilterTypeSet($portTest, "g","cheby,5,0.001,300",$csvFileHandle,$testFileHandle);

		$testFilterFileName = $deviceName . "_Cheby,5,0.001,300.txt";
		$testFilterFileNameWithDir = $newTestDir . $testFilterFileName;
		open $testFilterFileHandle, '>', $testFilterFileNameWithDir or die "Couldn't open file IMU1775_Cheby,5,0.001,300.txt $!";

		TestFilter($portTest, $testFilterFileHandle,$csvFileHandle,$testFileHandle);
		close($testFilterFileHandle);     # close the file handle

		print "\n\nTEST_FILTER:  OUTPUT FILE  = $testFilterFileNameWithDir\n\n";

		# Compare Filter Test File with Known good file to determine pass or fail
		if ( (index($deviceName,'1775') != -1)) {
			$file1 = "./TestFilterFiles/1775IMUCheby,5,0.001,300.txt";
		}
		else {
			$file1 = "./TestFilterFiles/DSPUCheby,5,0.001,300.txt";
		}
		$file2= "$testFilterFileNameWithDir";
		$result = compare ($file1, $file2);
       if ( $result == 0 ) {
            print "\n\nCheby,5,0.001,300 Test = $result $THREE_TABS Passed\n\n";
            print $csvFileHandle "Cheby_5_0.001_300 Test,Passed\r\n";
            print $testFileHandle "Cheby,5,0.001,300 Test, Passed\r\n";
       }
       elsif ($result == 1) {
            print "\n\nCheby,5,0.001,300 Test = $result $THREE_TABS Failed\n\n";
            print $csvFileHandle "Cheby_5_0.001_300 Test,Failed\r\n";
            print $testFileHandle "Cheby,5,0.001,300 Test, Failed\r\n";
       }
       elsif ($result == -1) {
            print "\n\nCheby,5,0.001,300 Test = $result $THREE_TABS Failed File not found\n\n";
            print $csvFileHandle "Cheby_5_0.001_300 Test,Failed\r\n";
            print $testFileHandle "Cheby,5,0.001,300 Test, Failed File not found\r\n";
       }
	   # test the custom filter here
		# cheby,6,0.001,400
		if ( (index($deviceName,'1775') != -1)) {
			# set the filter type for the accels to cheby and verify response
			TestFilterTypeSet($portTest, "a","cheby,6,0.001,400",$csvFileHandle,$testFileHandle);
		}

		# set the filter type for the gyros to cheby and verify response
		TestFilterTypeSet($portTest, "g","cheby,6,0.001,400",$csvFileHandle,$testFileHandle);

		$testFilterFileName = $deviceName . "_Cheby,6,0.001,400.txt";
		$testFilterFileNameWithDir = $newTestDir . $testFilterFileName;
		open $testFilterFileHandle, '>', $testFilterFileNameWithDir or die "Couldn't open file IMU1775_Cheby,6,0.001,400.txt $!";

		TestFilter($portTest, $testFilterFileHandle,$csvFileHandle,$testFileHandle);
		close($testFilterFileHandle);     # close the file handle

		print "\n\nTEST_FILTER:  OUTPUT FILE  = $testFilterFileNameWithDir\n\n";

		# Compare Filter Test File with Known good file to determine pass or fail
		if ( (index($deviceName,'1775') != -1)) {
			$file1 = "./TestFilterFiles/1775IMUCheby,6,0.001,400.txt";
		}
		else {
			$file1 = "./TestFilterFiles/DSPUCheby,6,0.001,400.txt";
		}
		$file2= "$testFilterFileNameWithDir";
		$result = compare ($file1, $file2);
       if ( $result == 0 ) {
            print "\n\nCheby,6,0.001,400 Test = $result $THREE_TABS Passed\n\n";
            print $csvFileHandle "Cheby_6_0.001_400 Test,Passed\r\n";
            print $testFileHandle "Cheby,6,0.001,400 Test, Passed\r\n";
       }
       elsif ($result == 1) {
            print "\n\nCheby,6,0.001,400 Test = $result $THREE_TABS Failed\n\n";
            print $csvFileHandle "Cheby_6_0.001_400Test,Failed\r\n";
            print $testFileHandle "Cheby,6,0.001,400 Test, Failed\r\n";
       }
       elsif ($result == -1) {
            print "\n\nCheby,6,0.001,400 Test = $result $THREE_TABS Failed File not found\n\n";
            print $csvFileHandle "Cheby_6_0.001_400 Test,Failed\r\n";
            print $testFileHandle "Cheby,6,0.001,400 Test, Failed File not found\r\n";
       }
	   # test the custom filter here
		# cheby,7,0.01,1000
		if ( (index($deviceName,'1775') != -1)) {
			# set the filter type for the accels to cheby and verify response
			TestFilterTypeSet($portTest, "a","cheby,7,0.01,1000",$csvFileHandle,$testFileHandle);
		}

		# set the filter type for the gyros to cheby and verify response
		TestFilterTypeSet($portTest, "g","cheby,7,0.01,1000",$csvFileHandle,$testFileHandle);

		$testFilterFileName = $deviceName . "_Cheby,7,0.01,1000.txt";
		$testFilterFileNameWithDir = $newTestDir . $testFilterFileName;
		open $testFilterFileHandle, '>', $testFilterFileNameWithDir or die "Couldn't open file IMU1775_Cheby,7,0.01,1000.txt $!";

		TestFilter($portTest, $testFilterFileHandle,$csvFileHandle,$testFileHandle);
		close($testFilterFileHandle);     # close the file handle

		print "\n\nTEST_FILTER:  OUTPUT FILE  = $testFilterFileNameWithDir\n\n";

		# Compare Filter Test File with Known good file to determine pass or fail
		if ( (index($deviceName,'1775') != -1)) {
			$file1 = "./TestFilterFiles/1775IMUCheby,7,0.01,1000.txt";
		}
		else {
			$file1 = "./TestFilterFiles/DSPUCheby,7,0.01,1000.txt";
		}
		$file2= "$testFilterFileNameWithDir";
		$result = compare ($file1, $file2);
       if ( $result == 0 ) {
            print "\n\nCheby,7,0.01,1000 Test = $result $THREE_TABS Passed\n\n";
            print $csvFileHandle "Cheby_7_0.01_1000 Test,Passed\r\n";
            print $testFileHandle "Cheby,7,0.01,1000 Test, Passed\r\n";
       }
       elsif ($result == 1) {
            print "\n\nCheby,7,0.01,1000 Test = $result $THREE_TABS Failed\n\n";
            print $csvFileHandle "Cheby_7_0.01_1000 Test,Failed\r\n";
            print $testFileHandle "Cheby,7,0.01,1000 Test, Failed\r\n";
       }
       elsif ($result == -1) {
            print "\n\nCheby,7,0.01,1000 Test = $result $THREE_TABS Failed File not found\n\n";
            print $csvFileHandle "Cheby_7_0.01_1000 Test,Failed\r\n";
            print $testFileHandle "Cheby,7,0.01,1000 Test,$THREE_TABS Failed File not found\r\n";
       }
	   # test the custom filter here
		# cheby,8,0.01,2500
		if ( (index($deviceName,'1775') != -1)) {
			# set the filter type for the accels to cheby and verify response
			TestFilterTypeSet($portTest, "a","cheby,8,0.01,2500",$csvFileHandle,$testFileHandle);
		}

		# set the filter type for the gyros to cheby and verify response
		TestFilterTypeSet($portTest, "g","cheby,8,0.01,2500",$csvFileHandle,$testFileHandle);

		$testFilterFileName = $deviceName . "_Cheby,8,0.01,2500.txt";
		$testFilterFileNameWithDir = $newTestDir . $testFilterFileName;
		open $testFilterFileHandle, '>', $testFilterFileNameWithDir or die "Couldn't open file IMU1775_Cheby,8,0.01,2500.txt $!";

		TestFilter($portTest, $testFilterFileHandle,$csvFileHandle,$testFileHandle);
		close($testFilterFileHandle);     # close the file handle

		print "\n\nTEST_FILTER:  OUTPUT FILE  = $testFilterFileNameWithDir\n\n";

		# Compare Filter Test File with Known good file to determine pass or fail
		if ( (index($deviceName,'1775') != -1)) {
			$file1 = "./TestFilterFiles/1775IMUCheby,8,0.01,2500.txt";
		}
		else {
			$file1 = "./TestFilterFiles/DSPUCheby,8,0.01,2500.txt";
		}
		$file2= "$testFilterFileNameWithDir";
		$result = compare ($file1, $file2);
       if ( $result == 0 ) {
            print "\n\nCheby,8,0.01,2500 Test = $result $THREE_TABS Passed\n\n";
            print $csvFileHandle "Cheby_8_0.01_2500 Test,Passed\r\n";
            print $testFileHandle "Cheby,8,0.01,2500 Test, Passed\r\n";
       }
       elsif ($result == 1) {
            print "\n\nCheby,8,0.01,2500 Test = $result $THREE_TABS Failed\n\n";
            print $csvFileHandle "Cheby_8_0.01_2500 Test,Failed\r\n";
            print $testFileHandle "Cheby,8,0.01,2500 Test, Failed\r\n";
       }
       elsif ($result == -1) {
            print "\n\nCheby,8,0.01,2500 Test = $result $THREE_TABS Failed File not found\n\n";
            print $csvFileHandle "Cheby_8_0.01_2500 Test,Failed\r\n";
            print $testFileHandle "Cheby,8,0.01,2500 Test, Failed File not found\r\n";
       }
	   # test the custom filter here
		# butter,1,5
		if ( (index($deviceName,'1775') != -1)) {
			# set the filter type for the accels to butter and verify response
			TestFilterTypeSet($portTest, "a","butter,1,5",$csvFileHandle,$testFileHandle);
		}

		# set the filter type for the gyros to butter and verify response
		TestFilterTypeSet($portTest, "g","butter,1,5",$csvFileHandle,$testFileHandle);

		$testFilterFileName = $deviceName . "_Butter,1,5.txt";
		$testFilterFileNameWithDir = $newTestDir . $testFilterFileName;
		open $testFilterFileHandle, '>', $testFilterFileNameWithDir or die "Couldn't open file IMU1775_Butter,1,5.txt $!";

		TestFilter($portTest, $testFilterFileHandle,$csvFileHandle,$testFileHandle);
		close($testFilterFileHandle);     # close the file handle

		print "\n\nTEST_FILTER:  OUTPUT FILE  = $testFilterFileNameWithDir\n\n";

		# Compare Filter Test File with Known good file to determine pass or fail
		if ( (index($deviceName,'1775') != -1)) {
			$file1 = "./TestFilterFiles/1775IMUButter,1,5.txt";
		}
		else {
			$file1 = "./TestFilterFiles/DSPUButter,1,5.txt";
		}
		$file2= "$testFilterFileNameWithDir";
		$result = compare ($file1, $file2);
       if ( $result == 0 ) {
            print "\n\nButter,1,0.1,5 Test = $result $THREE_TABS Passed\n\n";
            print $csvFileHandle "Butter_1_5 Test,Passed\r\n";
            print $testFileHandle "Butter,1,5 Test, Passed\r\n";
       }
       elsif ($result == 1) {
            print "\n\nButter,1,5 Test = $result $THREE_TABS Failed\n\n";
            print $csvFileHandle "Butter_1_5 Test,Failed\r\n";
            print $testFileHandle "Butter,1,5 Test, Failed\r\n";
       }
       elsif ($result == -1) {
            print "\n\nButter,1,5 Test = $result $THREE_TABS Failed File not found\n\n";
            print $csvFileHandle "Butter_1_5 Test,Failed\r\n";
            print $testFileHandle "Butter,1,5 Test, Failed File not found\r\n";
       }
	   # test the custom filter here
		# butter,2,50
		if ( (index($deviceName,'1775') != -1)) {
			# set the filter type for the accels to butter and verify response
			TestFilterTypeSet($portTest, "a","butter,2,50",$csvFileHandle,$testFileHandle);
		}

		# set the filter type for the gyros to butter and verify response
		TestFilterTypeSet($portTest, "g","butter,2,50",$csvFileHandle,$testFileHandle);

		$testFilterFileName = $deviceName . "_Butter,2,50.txt";
		$testFilterFileNameWithDir = $newTestDir . $testFilterFileName;
		open $testFilterFileHandle, '>', $testFilterFileNameWithDir or die "Couldn't open file IMU1775_Butter,2,50.txt $!";

		TestFilter($portTest, $testFilterFileHandle,$csvFileHandle,$testFileHandle);
		close($testFilterFileHandle);     # close the file handle

		print "\n\nTEST_FILTER:  OUTPUT FILE  = $testFilterFileNameWithDir\n\n";

		# Compare Filter Test File with Known good file to determine pass or fail
		if ( (index($deviceName,'1775') != -1)) {
			$file1 = "./TestFilterFiles/1775IMUButter,2,50.txt";
		}
		else {
			$file1 = "./TestFilterFiles/DSPUButter,2,50.txt";
		}
		$file2= "$testFilterFileNameWithDir";
		$result = compare ($file1, $file2);
       if ( $result == 0 ) {
            print "\n\nButter,2,50 Test = $result $THREE_TABS Passed\n\n";
            print $csvFileHandle "Butter_2_50 Test,Passed\r\n";
            print $testFileHandle "Butter,2,50 Test, Passed\r\n";
       }
       elsif ($result == 1) {
            print "\n\n1775IMUButter,2,50 Test = $result $THREE_TABS Failed\n\n";
            print $csvFileHandle "Butter_2_50 Test,Failed\r\n";
            print $testFileHandle "Butter,2,50 Test, Failed\r\n";
       }
       elsif ($result == -1) {
            print "\n\nButter,2,50 Test = $result $THREE_TABS Failed File not found\n\n";
            print $csvFileHandle "Butter_2_50 Test,Failed\r\n";
            print $testFileHandle "Butter,2,50 Test, Failed File not found\r\n";
       }
	   # test the custom filter here
		# butter,3,100
		if ( (index($deviceName,'1775') != -1)) {
			# set the filter type for the accels to butter and verify response
			TestFilterTypeSet($portTest, "a","butter,3,100",$csvFileHandle,$testFileHandle);
		}

		# set the filter type for the gyros to butter and verify response
		TestFilterTypeSet($portTest, "g","butter,3,100",$csvFileHandle,$testFileHandle);

		$testFilterFileName = $deviceName . "_Butter,3,100.txt";
		$testFilterFileNameWithDir = $newTestDir . $testFilterFileName;
		open $testFilterFileHandle, '>', $testFilterFileNameWithDir or die "Couldn't open file IMU1775_Butter,3,100.txt $!";

		TestFilter($portTest, $testFilterFileHandle,$csvFileHandle,$testFileHandle);
		close($testFilterFileHandle);     # close the file handle

		print "\n\nTEST_FILTER:  OUTPUT FILE  = $testFilterFileNameWithDir\n\n";

		# Compare Filter Test File with Known good file to determine pass or fail
		if ( (index($deviceName,'1775') != -1)) {
			$file1 = "./TestFilterFiles/1775IMUButter,3,100.txt";
		}
		else {
			$file1 = "./TestFilterFiles/DSPUButter,3,100.txt";
		}
		$file2= "$testFilterFileNameWithDir";
		$result = compare ($file1, $file2);
       if ( $result == 0 ) {
            print "\n\nButter,3,100 Test = $result $THREE_TABS Passed\n\n";
            print $csvFileHandle "Butter_3_100 Test,Passed\r\n";
            print $testFileHandle "Butter,3,100 Test, Passed\r\n";
       }
       elsif ($result == 1) {
            print "\n\nButter,3,100 Test = $result $THREE_TABS Failed\n\n";
            print $csvFileHandle "Butter_3_100 Test,Failed\r\n";
            print $testFileHandle "Butter,3,100 Test, Failed\r\n";
       }
       elsif ($result == -1) {
            print "\n\nButter,3,100 Test = $result $THREE_TABS Failed File not found\n\n";
            print $csvFileHandle "Butter_3_100 Test,Failed\r\n";
            print $testFileHandle "Butter,3,100 Test, Failed File not found\r\n";
       }
	   # test the custom filter here
		# butter,4,200
		if ( (index($deviceName,'1775') != -1)) {
			# set the filter type for the accels to butter and verify response
			TestFilterTypeSet($portTest, "a","butter,4,200",$csvFileHandle,$testFileHandle);
		}

		# set the filter type for the gyros to butter and verify response
		TestFilterTypeSet($portTest, "g","butter,4,200",$csvFileHandle,$testFileHandle);

		$testFilterFileName = $deviceName . "_Butter,4,200.txt";
		$testFilterFileNameWithDir = $newTestDir . $testFilterFileName;
		open $testFilterFileHandle, '>', $testFilterFileNameWithDir or die "Couldn't open file IMU1775_Butter,4,200.txt $!";

		TestFilter($portTest, $testFilterFileHandle,$csvFileHandle,$testFileHandle);
		close($testFilterFileHandle);     # close the file handle

		print "\n\nTEST_FILTER:  OUTPUT FILE  = $testFilterFileNameWithDir\n\n";

		# Compare Filter Test File with Known good file to determine pass or fail
		if ( (index($deviceName,'1775') != -1)) {
			$file1 = "./TestFilterFiles/1775IMUButter,4,200.txt";
		}
		else {
			$file1 = "./TestFilterFiles/DSPUButter,4,200.txt";
		}
		$file2= "$testFilterFileNameWithDir";
		$result = compare ($file1, $file2);
       if ( $result == 0 ) {
            print "\n\nButter,4,200 Test = $result $THREE_TABS Passed\n\n";
            print $csvFileHandle "Butter_4_200 Test,Passed\r\n";
            print $testFileHandle "Butter,4,200 Test, Passed\r\n";
       }
       elsif ($result == 1) {
            print "\n\nButter,4,200 Test = $result $THREE_TABS Failed\n\n";
            print $csvFileHandle "Butter_4_200 Test,Failed\r\n";
            print $testFileHandle "Butter,4,200 Test, Failed\r\n";
       }
       elsif ($result == -1) {
            print "\n\nButter,4,200 Test = $result $THREE_TABS File not found\n\n";
            print $csvFileHandle "Butter_4_200 Test,Failed\r\n";
            print $testFileHandle "Butter,4,200 Test, Failed File not found\r\n";
       }
	   # test the custom filter here
		# butter,5,300
		if ( (index($deviceName,'1775') != -1)) {
			# set the filter type for the accels to butter and verify response
			TestFilterTypeSet($portTest, "a","butter,5,300",$csvFileHandle,$testFileHandle);
		}

		# set the filter type for the gyros to butter and verify response
		TestFilterTypeSet($portTest, "g","butter,5,300",$csvFileHandle,$testFileHandle);

		$testFilterFileName = $deviceName . "_Butter,5,300.txt";
		$testFilterFileNameWithDir = $newTestDir . $testFilterFileName;
		open $testFilterFileHandle, '>', $testFilterFileNameWithDir or die "Couldn't open file IMU1775_Butter,5,300.txt $!";

		TestFilter($portTest, $testFilterFileHandle,$csvFileHandle,$testFileHandle);
		close($testFilterFileHandle);     # close the file handle

		print "\n\nTEST_FILTER:  OUTPUT FILE  = $testFilterFileNameWithDir\n\n";

		# Compare Filter Test File with Known good file to determine pass or fail
		if ( (index($deviceName,'1775') != -1)) {
			$file1 = "./TestFilterFiles/1775IMUButter,5,300.txt";
		}
		else {
			$file1 = "./TestFilterFiles/DSPUButter,5,300.txt";
		}
		$file2= "$testFilterFileNameWithDir";
		$result = compare ($file1, $file2);
       if ( $result == 0 ) {
            print "\n\nButter,5,300 Test = $result $THREE_TABS Passed\n\n";
            print $csvFileHandle "Butter_5_300 Test,Passed\r\n";
            print $testFileHandle "Butter,5,300 Test, Passed\r\n";
       }
       elsif ($result == 1) {
            print "\n\nButter,5,0.001,300 Test = $result $THREE_TABS Failed\n\n";
            print $csvFileHandle "Butter,5,300 Test,Failed\r\n";
            print $testFileHandle "Butter,5,300 Test, Failed\r\n";
       }
       elsif ($result == -1) {
            print "\n\nButter,5,300 Test = $result $THREE_TABS Failed File not found\n\n";
            print $csvFileHandle "Butter_5_300 Test,Failed\r\n";
            print $testFileHandle "Butter,5,300 Test, Failed File not found\r\n";
       }
	   # test the custom filter here
		# butter,6,400
		if ( (index($deviceName,'1775') != -1)) {
			# set the filter type for the accels to butter and verify response
			TestFilterTypeSet($portTest, "a","butter,6,400",$csvFileHandle,$testFileHandle);
		}

		# set the filter type for the gyros to butter and verify response
		TestFilterTypeSet($portTest, "g","butter,6,400",$csvFileHandle,$testFileHandle);

		$testFilterFileName = $deviceName . "_Butter,6,400.txt";
		$testFilterFileNameWithDir = $newTestDir . $testFilterFileName;
		open $testFilterFileHandle, '>', $testFilterFileNameWithDir or die "Couldn't open file IMU1775_Butter,6,400.txt $!";

		TestFilter($portTest, $testFilterFileHandle,$csvFileHandle,$testFileHandle);
		close($testFilterFileHandle);     # close the file handle

		print "\n\nTEST_FILTER:  OUTPUT FILE  = $testFilterFileNameWithDir\n\n";

		# Compare Filter Test File with Known good file to determine pass or fail
		if ( (index($deviceName,'1775') != -1)) {
			$file1 = "./TestFilterFiles/1775IMUButter,6,400.txt";
		}
		else {
			$file1 = "./TestFilterFiles/DSPUButter,6,400.txt";
		}
		$file2= "$testFilterFileNameWithDir";
		$result = compare ($file1, $file2);
       if ( $result == 0 ) {
            print "\n\nButter,6,400 Test = $result $THREE_TABS Passed\n\n";
            print $csvFileHandle "Butter_6_400 Test,Passed\r\n";
            print $testFileHandle "Butter,6,400 Test, Passed\r\n";
       }
       elsif ($result == 1) {
            print "\n\nButter,6,0.001,400 Test = $result $THREE_TABS Failed\n\n";
            print $csvFileHandle "Butter_6_400Test,Failed\r\n";
            print $testFileHandle "Butter,6,400 Test, Failed\r\n";
       }
       elsif ($result == -1) {
            print "\n\nButter,6,400 Test = $result $THREE_TABS Failed File not found\n\n";
            print $csvFileHandle "Butter_6_400 Test,Failed\r\n";
            print $testFileHandle "Butter,6,400 Test, Failed File not found\r\n";
       }
	   # test the custom filter here
		# butter,7,1000
		if ( (index($deviceName,'1775') != -1)) {
			# set the filter type for the accels to butter and verify response
			TestFilterTypeSet($portTest, "a","butter,7,1000",$csvFileHandle,$testFileHandle);
		}
		
		# set the filter type for the gyros to butter and verify response
		TestFilterTypeSet($portTest, "g","butter,7,1000",$csvFileHandle,$testFileHandle);

		$testFilterFileName = $deviceName . "_Butter,7,1000.txt";
		$testFilterFileNameWithDir = $newTestDir . $testFilterFileName;
		open $testFilterFileHandle, '>', $testFilterFileNameWithDir or die "Couldn't open file IMU1775_Butter,7,1000.txt $!";

		TestFilter($portTest, $testFilterFileHandle,$csvFileHandle,$testFileHandle);
		close($testFilterFileHandle);     # close the file handle

		print "\n\nTEST_FILTER:  OUTPUT FILE  = $testFilterFileNameWithDir\n\n";

		# Compare Filter Test File with Known good file to determine pass or fail
		if ( (index($deviceName,'1775') != -1)) {
			$file1 = "./TestFilterFiles/1775IMUButter,7,1000.txt";
		}
		else {
			$file1 = "./TestFilterFiles/DSPUButter,7,1000.txt";
		}
		$file2= "$testFilterFileNameWithDir";
		$result = compare ($file1, $file2);
       if ( $result == 0 ) {
            print "\n\nButter,7,0.01,1000 Test = $result $THREE_TABS Passed\n\n";
            print $csvFileHandle "Butter_7_1000 Test,Passed\r\n";
            print $testFileHandle "Butter,7,1000 Test, Passed\r\n";
       }
       elsif ($result == 1) {
            print "\n\nButter,7,1000 Test = $result $THREE_TABS Failed\n\n";
            print $csvFileHandle "Butter_7_1000 Test,Failed\r\n";
            print $testFileHandle "Butter,7,1000 Test, Failed\r\n";
       }
       elsif ($result == -1) {
            print "\n\nButter,7,1000 Test = $result $THREE_TABS Failed File not found\n\n";
            print $csvFileHandle "Butter_7_1000 Test,Failed\r\n";
            print $testFileHandle "Butter,7,1000 Test, Failed File not found\r\n";
       }
	   # test the custom filter here
		# butter,8,2500
		if ( (index($deviceName,'1775') != -1)) {
			# set the filter type for the accels to butter and verify response
			TestFilterTypeSet($portTest, "a","butter,8,2500",$csvFileHandle,$testFileHandle);
		}

		# set the filter type for the gyros to butter and verify response
		TestFilterTypeSet($portTest, "g","butter,8,2500",$csvFileHandle,$testFileHandle);

		$testFilterFileName = $deviceName . "_Butter,8,2500.txt";
		$testFilterFileNameWithDir = $newTestDir . $testFilterFileName;
		open $testFilterFileHandle, '>', $testFilterFileNameWithDir or die "Couldn't open file IMU1775_Butter,8,2500.txt $!";

		TestFilter($portTest, $testFilterFileHandle,$csvFileHandle,$testFileHandle);
		close($testFilterFileHandle);     # close the file handle

		print "\n\nTEST_FILTER:  OUTPUT FILE  = $testFilterFileNameWithDir\n\n";

		# Compare Filter Test File with Known good file to determine pass or fail
		if ( (index($deviceName,'1775') != -1)) {
			$file1 = "./TestFilterFiles/1775IMUButter,8,2500.txt";
		}
		else {
			$file1 = "./TestFilterFiles/DSPUButter,8,2500.txt";
		}
		$file2= "$testFilterFileNameWithDir";
		$result = compare ($file1, $file2);
       if ( $result == 0 ) {
            print "\n\nButter,8,2500 Test = $result $THREE_TABS Passed\n\n";
            print $csvFileHandle "1775IMUButter_8_2500 Test,Passed\r\n";
            print $testFileHandle "1775IMUButter,8,2500 Test, Passed\r\n";
       }
       elsif ($result == 1) {
            print "\n\nButter,8,2500 Test = $result $THREE_TABS Failed\n\n";
            print $csvFileHandle "Butter_8_2500 Test,Failed\r\n";
            print $testFileHandle "Butter,8,2500 Test, Failed\r\n";
       }
       elsif ($result == -1) {
            print "\n\nButter,8,2500 Test = $result $THREE_TABS Failed File not found\n\n";
            print $csvFileHandle "Butter_8_2500 Test,Failed\r\n";
            print $testFileHandle "Butter,8,2500 Test, Failed File not found\r\n";
       }
	}
	# send the cfgreset command and then restart the device to get it into a known state
    TestCfgRstCommand($port,$testCsvFileHandle,$testFileHandle);
    RestartCommand($port);
 }# end of TestFiltCommand


###########################################################
#   TestMsgFormat1750_60
#
#   Description: Message Format Test
#                Test the output format of the 1750 and 1760
#
#        Inputs: $portTest         - comport device is on
#                $csvFileHandle    - file handle to write csv test results
#                $testFileHandle    - file handle to write txt test results
#                $storageDirectory - directory to write the output file in hex to
#
#       Returns: Success or Failure - 0 or 1
#
#  Side Effects:
#
#         Notes:
#
###########################################################
sub TestMsgFormat1750_60
{
    my $portTest         = shift;
    my $csvFileHandle    = shift;
    my $testFileHandle   = shift;
    my $storageDirectory = shift;
    my $deviceName       = shift;
	my $testDevice		 = shift;

    my $testString    = "" ;
    my $indexCount    = 0;
    my $stringCount   = 0;
    my $imuPacket;
    my $mainFormatAStatus  = $SUCCESS;
    my $negativeTestStatus = $SUCCESS;
	
	# ensure the data rate is set to 10 hZ as it is easeier to work with over the COM port
    my $dataValue = "10";
    TestSetDR($portTest,$dataValue,0, $csvFileHandle);

    # we will first test the NORMAL mode Format A
    my $normalFileName = $storageDirectory . "/testNormalA.txt";
    open my $normalFileHandleA, '>', $normalFileName or die "Couldn't open file testNormalA.txt, $!";

    if (!$normalFileHandleA) {
        print "The testNormalA.txt did not open - test Failed\r\n";
        print $csvFileHandle "Message Format A,Failed\r\n";
        print $testFileHandle "Message Format A,Failed,testNormalA.txt not opened\r\n";
        $mainFormatAStatus = $FAILED;
    }
    else {

        #make sure we are in CONFIG mode
        for ($indexCount = 0; $indexCount< 4; $indexCount++) {
            $generalStatus = SendConfigCommand($portTest,"1",0,$csvFileHandle);
            if ($generalStatus == $SUCCESS) {
                last;
            }
        }

        $testString = $FORMAT_A_HEADER;
        ($stringCount, $imuPacket) = GetNormalTest($portTest,$normalFileHandleA,$testString);

        ProcessImupacket($csvFileHandle,$testFileHandle, $imuPacket,$deviceName,$testDevice);

        #make sure we are in CONFIG mode
        for ($indexCount = 0; $indexCount< 4; $indexCount++) {
            $generalStatus  = SendConfigCommand($portTest,"1",0,$csvFileHandle);
            if ($generalStatus == $SUCCESS) {
                last;
            }
        }
        close ($normalFileHandleA);

        if ($stringCount == $NORMAL_FORMAT_A_SIZE ) {
            print "\r\nThe Normal Format A Packet Size = $stringCount \t\tPassed\r\n";
            print $csvFileHandle "Message Format A, Passed\r\n";
            print $testFileHandle "Message Format A Packet Size = $stringCount Passed\r\n";
        } else {
            print "\r\nThe Normal Format A Packet Size = $stringCount \t\tFailed\r\n";
            print $csvFileHandle "Message Format A,Failed\r\n";
            print $testFileHandle "Message Format A Packet Size = $stringCount Failed\r\n";
            $mainFormatAStatus = $FAILED;
        }

    } # end of else of if (!$normalFileHandleA)


    # perform the negative testing as the non-1775 variants only use Format A
    my $commandStatus = "=outputfmt,B";
    $portTest->write($commandStatus."\n");

    sleep 1;

    my $result = $portTest->input;
    print "Message Format Non-1775 negative test result = $result";
    print "Message Format Non-1775 negative test command $commandStatus\r\n";
    #print $testFileHandle "Message Format1750_60 command negative test = $commandStatus\r\n";
    #print $testFileHandle "Message Format1750_60 negative test result = $result";

    if ( (index($result,'USAGE: =OUTPUTFMT') != -1) || (index($result,'INVALID,=OUTPUTFMT') != -1)  ) {
        print "Message Format Non-1775 $commandStatus negative test \t\t\tPassed\r\n\r\n";
        print $csvFileHandle "Message Format Non-1775 =outputfmt B negative test,Passed\r\n";
        print $testFileHandle "Message Format Non-1775 $commandStatus negative test Passed $result\r\n";
        $negativeTestStatus   = $SUCCESS;
    } else {
        print "Message Format Non-1775 \t\t\tFailed\r\n";
        print $csvFileHandle "Message Format Non-1775 =outputfmt B negative test,Failed\r\n";
        print $testFileHandle "Message Format Non-1775 $commandStatus negative test Failed $result\r\n";
        $negativeTestStatus = $FAILED;
    }

    if ( ($mainFormatAStatus == $SUCCESS) && ($negativeTestStatus == $SUCCESS) ) {
        print "\r\nThe Message Format Test $THREE_TABS Passed\r\n";
        print $csvFileHandle "Message Format Test,Passed\r\n";
        print $testFileHandle "Message Format Test, Passed\r\n";
    } else {
        print "\r\nThe Message Format Test $THREE_TABS Failed\r\n";
        print $csvFileHandle "Message Format Test,Failed\r\n";
        print $testFileHandle "Message Format Test, Failed\r\n";
    }

} # end of TestMsgFormat1750_60


###########################################################
#   TestMsgFormat
#
#   Description: Message Format Test
#                Test the output formats A, B, and C for the 1775
#
#        Inputs: $portTest         - comport device is on
#                $csvFileHandle    - file handle to write csv test results
#                $testFileHandle    - file handle to write txt test results
#                $storageDirectory - directory to write the output file in hex to
#
#       Returns: Success or Failure - 1 or 0
#
#  Side Effects:
#
#         Notes:
#
###########################################################
sub TestMsgFormat
{
    my $portTest         = shift;
    my $csvFileHandle    = shift;
    my $testFileHandle    = shift;
    my $storageDirectory = shift;
    my $deviceName       = shift;
	my $testDevice		= shift;
    my $testString    = "";
    my $indexCount    = 0;
    my $stringCount   = 0;
    my $globalTest    = 1;
    my $generalStatus = 1;
    my $imuPacket;
	
	# ensure the data rate is set to 10 hZ as it is easeier to work with over the COM port
    $dataValue = "10";
    TestSetDR($portTest,$dataValue,0, $csvFileHandle);

    # we will first test the NORMAL mode Format A
    my $normalFileName = $storageDirectory . "/testNormalA.txt";
    open my $normalFileHandleA, '>', $normalFileName or die "Couldn't open file testNormalA.txt, $!";

    if (!$normalFileHandleA) {
        print "The testNormalA.txt did not open - test Failed\r\n";
        print $csvFileHandle "Message Format A,Failed\r\n";
        print $testFileHandle "Message Format A,Failed, testNormalA.txt not opened\r\n";
        $globalTest = 0;
    }
    else {

         #make sure we are in CONFIG mode
         for ($indexCount = 0; $indexCount< 4; $indexCount++) {
            $generalStatus  = SendConfigCommand($portTest,"1",0,$csvFileHandle,$testFileHandle);
            if ($generalStatus == $SUCCESS) {
                last;
            }
        }

        my $dataValue = "A";
        TestOutputFormatCommand($portTest,$dataValue,$csvFileHandle,$testFileHandle,1);

        $testString = $FORMAT_A_HEADER;
        ($stringCount, $imuPacket) = GetNormalTest($portTest,$normalFileHandleA,$testString);

        ProcessImupacket($csvFileHandle,$testFileHandle, $imuPacket,$deviceName,$testDevice);

        #make sure we are in CONFIG mode
        for ($indexCount = 0; $indexCount< 4; $indexCount++) {
            $generalStatus  = SendConfigCommand($portTest,"1",0,$csvFileHandle,$testFileHandle);
            if ($generalStatus == 1) {
                last;
            }
        }
        close ($normalFileHandleA);

        if ($stringCount == $NORMAL_FORMAT_A_SIZE ) {
            print "\r\nThe Normal Format A Packet Size = $stringCount $THREE_TABS Passed\r\n";
            print $csvFileHandle "Message Format A, Passed\r\n";
            print $testFileHandle "Message Format A Packet Size = $stringCount, Passed, ,\r\n";
        } else {
            print "\r\nThe Normal Format A Packet Size = $stringCount $THREE_TABS Failed\r\n";
            print $csvFileHandle "Message Format A,Failed\r\n";
            print $testFileHandle "Message Format A Packet Size = $stringCount,Failed, ,\r\n";
            $globalTest = $FAILED;
        }

    } # end of else of if (!$normalFileHandleA)


    $normalFileName = $storageDirectory . "/testNormalB.txt";
    open my $normalFileHandleB, '>', $normalFileName or die "Couldn't open file testNormalB.txt, $!";

    if (!$normalFileHandleB) {
        print "Message Format B $THREE_TABS Failed, testNormalB.txt not opened\r\n";
        print $csvFileHandle "Message Format B,Failed\r\n";
        print $testFileHandle "Message Format B,Failed, testNormalB.txt not opened\r\n";
        $globalTest = 0;
    }
    else {

        #make sure we are in CONFIG mode
        for ($indexCount = 0; $indexCount < 4; $indexCount++) {
            $generalStatus  = SendConfigCommand($portTest,"1",0,$csvFileHandle,$testFileHandle);
            if ($generalStatus == $SUCCESS) {
                last;
            }
        }

        $dataValue = "B";
        TestOutputFormatCommand($portTest,$dataValue,$csvFileHandle,$testFileHandle, 1);
        select(undef, undef, undef, 0.75);
        $testString = $FORMAT_B_HEADER;
        ($stringCount, $imuPacket) = GetNormalTest($portTest,$normalFileHandleB,$testString);

        #make sure we are in CONFIG mode
        for ($indexCount = 0; $indexCount< 4; $indexCount++) {
            $generalStatus  = SendConfigCommand($portTest,"1",0,$csvFileHandle,$testFileHandle);
            if ($generalStatus == 1) {
                last;
            }
        }
        close ($normalFileHandleB);

        if ($stringCount == $NORMAL_FORMAT_B_SIZE) {
            print "Message Format B Packet Size = $stringCount $THREE_TABS Passed\r\n";
            print $csvFileHandle "Message Format B,Passed\r\n";
            print $testFileHandle "Message Format B Packet Size = $stringCount,Passed, ,\r\n";
        } else {
            print "The Format B Packet Size = $stringCount \t\tFailed\r\n";
            print $csvFileHandle "Message Format B,Failed\r\n";
            print $testFileHandle "Message Format B Packet Size = $stringCount,Failed\r\n";
            $globalTest = 0;
        }
    } # end of else of if (!$normalFileHandleB)

    # do not test format C if we are a DSP1760U variant
    if (index($deviceName,'1775IMU') != -1) {

        $normalFileName = $storageDirectory . "/testNormalC.txt";
        open my $normalFileHandleC, '>', $normalFileName or die "Couldn't open file testNormalC.txt, $!";

        if (!$normalFileHandleC) {
            print "Message Format C $THREE_TABS Failed, testNormalC.txt not opened\r\n";
            print $csvFileHandle "Message Format C,Failed\r\n";
            print $testFileHandle "Message Format C,Failed, testNormalC.txt not opened\r\n";
            $globalTest = 0;
        }
        else {

            #make sure we are in CONFIG mode
            for ($indexCount = 0; $indexCount< 4; $indexCount++) {
                $generalStatus  = SendConfigCommand($portTest,"1",0,$csvFileHandle,$testFileHandle);
                if ($generalStatus == 1) {
                    last;
                }
            }

            $dataValue = "C";
            TestOutputFormatCommand($portTest,$dataValue,$csvFileHandle,$testFileHandle, 1);
            $testString = $FORMAT_C_HEADER;
            ($stringCount, $imuPacket) = GetNormalTest($portTest,$normalFileHandleC, $testString);

            close ($normalFileHandleC);

            if ($stringCount == $NORMAL_FORMAT_C_SIZE ) {
                print "\r\nMessage Format C Packet Size = $stringCount $THREE_TABS Passed\r\n";
                print $csvFileHandle "Message Format C,Passed\r\n";
                print $testFileHandle "Message Format C Packet Size = $stringCount,Passed\r\n";
            } else {
                print "\r\nMessage Format C Packet Size = $stringCount $THREE_TABS Failed\r\n";
                print $csvFileHandle "Message Format C,Failed\r\n";
                print $testFileHandle "Message Format C Packet Size = $stringCount, Failed\r\n";
                $globalTest = 0;
            }

        } # end of else of if (!$normalFileHandleC)
    } # end of if ( (index($deviceName,'DSP') != -1)

    if ($globalTest == $SUCCESS) {
        print "\r\nMessage Format Test $THREE_TABS Passed\r\n";
        print $csvFileHandle "Message Format Test,Passed\r\n";
        print $testFileHandle "Message Format Test,Passed\r\n";
    } else {
        print "\r\nMessage Format Test $THREE_TABS Failed\r\n";
        print $csvFileHandle "Message Format Test,Failed\r\n";
        print $testFileHandle "Mmessage Format Test,Failed\r\n";
    }
	#make sure we are in CONFIG mode
    for ($indexCount = 0; $indexCount< 4; $indexCount++) {
        $generalStatus  = SendConfigCommand($portTest,"1",0,$csvFileHandle,$testFileHandle);
        if ($generalStatus == 1) {
			last;
			}
    }
    return $globalTest;

} # end of TestMsgFormat

############################################################################
#  TestCommandConfigurability
#
#  Description: test the command configurabilty - set to defaults with reset
#               config command called
#
#       Inputs: $portTest         - comport device is on
#               $powerPortTest    - comport the Power is connected to
#               $csvFileHandle    - file handle to write csv test results
#               $testFileHandle   - file handle to write txt test results
#
#
#      Returns: None
#
# Side Effects: Success or Failure - 0 or 1
#
#        Notes: None
#
############################################################################

sub TestCommandConfigurability
{
    my $portTest       = shift;
    my $csvFileHandle  = shift;
    my $testFileHandle  = shift;
    my $subSuccess  = $SUCCESS;
    my $testSuccess = $SUCCESS;
    my $tempUnitsGetResult = $SUCCESS;

    #SendConfigCommand($portTest,"1",0,$csvFileHandle,$testFileHandle);
	print "\r\nStart Comand Configurability Test\r\n";
	print $csvFileHandle "Start Comand Configurability Test\r\n";
	print $testFileHandle "Start Comand Configurability Test\r\n\r\n";
    # send the cfgreset command
    $subSuccess = TestCfgRstCommand($portTest,$csvFileHandle,$testFileHandle);
    if ($subSuccess == $FAILED) {
        $testSuccess = $FAILED;
    }

    # test the default settings for the individual commands
    $dataValue = "DELTA";
    $subSuccess = TestRotationFormatGet($portTest, $dataValue,$csvFileHandle,$testFileHandle);
    if ($subSuccess == 0) {
        $testSuccess = 0;
    }

    $dataValue = "RATE";
    $subSuccess = TestRotationFormatSet($portTest, $dataValue,$csvFileHandle,$testFileHandle);
    if ($subSuccess == 0) {
        $testSuccess = 0;
    }

    $dataValue = "RAD";
    $subSuccess = TestRotationUnitsGet($portTest, $dataValue,$csvFileHandle,$testFileHandle);
    if ($subSuccess == 0) {
        $testSuccess = 0;
    }

    $dataValue = "DEG";
    $subSuccess = TestRotationUnitsSet($portTest, $dataValue,$$csvFileHandle,$testFileHandle);
    if ($subSuccess == 0) {
        $testSuccess = 0;
    }

    $dataValue = "ACCEL";
    $subSuccess = TestLinearFormatGet($portTest, $dataValue,$csvFileHandle,$testFileHandle);
    if ($subSuccess == 0) {
        $testSuccess = 0;
    }

    $dataValue = "DELTA";
    $subSuccess = TestLinearFormatSet($portTest, $dataValue,$csvFileHandle,$testFileHandle);
    if ($subSuccess == 0) {
        $testSuccess = 0;
    }

    $dataValue = "METERS";
    $subSuccess = TestLinearUnitsGet($portTest, $dataValue,$csvFileHandle,$testFileHandle);
    if ($subSuccess == 0) {
        $testSuccess = 0;
    }

    $dataValue = "FEET";
    $subSuccess = TestLinearUnitsSet($portTest, $dataValue,$$csvFileHandle,$testFileHandle);
    if ($subSuccess == 0) {
        $testSuccess = 0;
    }

     # Only the 1750 allows different Accel Variants but will check that all other devices reject get command
    if (index($deviceName,'1750') == -1) {
        $subSuccess = TestAccelTypeGetCommand($portTest,$csvFileHandle,$testFileHandle);
        if ($subSuccess == 0) {
                $testSuccess = 0;
        }
    }

    # Only the 1750 allows different Accel Variants but will check that all other devices reject set command
    if (index($deviceName,'1750') == -1) {
        $dataValue = "30";
        $subSuccess = TestAccelTypeSetCommand($portTest, $dataValue,$csvFileHandle,$testFileHandle);
        if ($subSuccess == 0) {
                $testSuccess = 0;
        }
    }

    $dataValue = "C";
    ($subSuccess,$tempUnitsGetResult) = TestTempUnitsGet($portTest, $dataValue,$csvFileHandle,$testFileHandle);
    if ($subSuccess == $FAILED) {
        $testSuccess = $FAILED;
    }

    $dataValue = "F";
    $subSuccess = TestTempUnitsSet($portTest, $dataValue,$csvFileHandle,$testFileHandle);
    if ($subSuccess == $FAILED) {
        $testSuccess =$FAILED;
    }

    #######################
    #RestartCommand($portTest,$testFileHandle,$csvFileHandle,$testFileHandle);
    # my $promptTest = &promptUser("RESET the Device\r\n\r\n");

    #sleep 1;
    # make sure we are in CONFIG mode
    #for (my $indexCount = 0; $indexCount< 4; $indexCount++) {
    #    SendConfigCommand($portTest,"1",0,$csvFileHandle,$testFileHandle);
    #    sleep 1;
    #}

    #$dataValue = "RATE";
    #$subSuccess = TestRotationFormatGet($portTest, $dataValue,$csvFileHandle,$testFileHandle);
    #if ($subSuccess == 0) {
    #    $testSuccess = 0;
    #}

    #$dataValue = "DEG";
    #$subSuccess = TestRotationUnitsGet($portTest, $dataValue,$csvFileHandle,$testFileHandle);
    #if ($subSuccess == 0) {
    #    $testSuccess = 0;
    #}

    #$dataValue = "F";
    #($subSuccess,$tempUnitsGetResult) = TestTempUnitsGet($portTest, $dataValue,$csvFileHandle,$testFileHandle);
    #if ($subSuccess == $FAILED) {
    #    $testSuccess = $FAILED;
    #}

    if ($testSuccess == $SUCCESS) {
        print "Command Config Test $FIVE_TABS Passed\r\n\r\n";
        print $csvFileHandle "Command Config Test,Passed\r\n";
        print $testFileHandle "\r\nCommand Config Test, Passed\r\n\r\n";
    } else {
        print "Command Config Test $FIVE_TABS Failed\r\n\r\n";
        print $csvFileHandle "\r\nCommand Config Test,Failed\r\n\r\n";
        print $testFileHandle "Command Config Test, Failed\r\n";
    }
    return $testSuccess;

} # end of TestCommandConfigurability

############################################################################
#  TestBITFormat
#
#  Description: BIT Message Test
#               Test to insure the BIT test works and BIT results are in
#               the output; Test ?bit and ?bit,2
#
#       Inputs: $portTest         - comport device is on#
#               $csvFileHandle    - file handle to write csv test results
#               $testFileHandle    - file handle to write txt test results
#               $storageDirectory - location to store the BIT results file
#				0 or 1			   -Value to select if pass/fail results should be processed; 0 = don't process, 1 = process
#
#      Returns: Success or Failure - 0 or 1
#
# Side Effects: None
#
#        Notes: None
#
############################################################################

sub TestBITFormat
{
    my $portTest         = shift;
    my $csvFileHandle    = shift;
    my $testFileHandle    = shift;
    my $storageDirectory = shift;
	my $processPassFail = shift;

    my $indexCount    = 0;
    my $generalStatus = 1;
    my $result        = "";
    my $imuPacket;
    my $hexCount;
    my $formatBitHeader = $FORMAT_BIT_A_HEADER;

    my $stringOffset;
    my $location;
    my $location2;
    my $location3;
    my $length;

    print "TestBITFormat BIT Test \r\n";

    # set the data rate to 10 hZ as it is easier to work with
    $dataValue = "10";
    TestSetDR($portTest,$dataValue,0, $csvFileHandle,$testFileHandle);
	# we will first test the NORMAL mode BIT
    my $normalFileName = $storageDirectory . "testNormalBIT.txt";
    open my $normalFileHandleBIT, '>', $normalFileName or die "Couldn't open file testNormalBIT.txt, $!";

    if (!$normalFileHandleBIT) {
        print "Normal Mode BIT Test $FIVE_TABS Failed, The $normalFileHandleBIT.txt did not open\r\n";
        print $csvFileHandle "Normal Mode BIT Test,Failed\r\n";
        print $testFileHandle "Normal Mode BIT Test,Failed, The $normalFileHandleBIT.txt did not open\r\n";
    }
    else {

        # make sure we are in CONFIG mode
		for ($indexCount = 0; $indexCount< 4; $indexCount++) {
            $generalStatus = SendConfigCommand($portTest,"1",0,$csvFileHandle,$testFileHandle);
            if ($generalStatus == 1) {
                last;
            }
        }

        # only set the format if non 1750 or 60 as they don't support the "=outputfmt" command
        if ((index($deviceName,'1775') != -1) || (index($deviceName,'1760DSPU') != -1) || (index($deviceName,'IRS') != -1)) {
            my $dataValue = "A";
            TestOutputFormatCommand($portTest,$dataValue,$csvFileHandle,$testFileHandle,0);
        }

		#print "\r\nGoing into normal mode\r\n";
        my $commandStatus = "=config,0";
        $portTest->write($commandStatus."\n");
		sleep 5;

		my $indexCount = 0;
        while ($indexCount < 20) { # should only need one pass, but we don't want to loop forever

            $result = $portTest->input;

            select(undef, undef, undef, 0.50);

            my $resultLength = length($result);
            my $stringSize = 2 * $resultLength;
            print ($normalFileHandleBIT unpack("H$stringSize", $result), "\n");

            if ($indexCount == 4) {
                $commandStatus = "?bit";
                $portTest->write($commandStatus."\n");
            } elsif ($indexCount == 6) {

                $commandStatus = '?bit,2';
                $portTest->write($commandStatus."\n");
            }
            $indexCount++;

        } # end of while

        # make sure we are in CONFIG mode
        for ($indexCount = 0; $indexCount< 4; $indexCount++) {
            $generalStatus = SendConfigCommand($portTest,"1",0,$csvFileHandle);
            if ($generalStatus == 1) {
                last;
            }
        } # end of for

        close ($normalFileHandleBIT);
		#print "\r\nNow in Config Mode\r\n";
        my $normalFileName = $storageDirectory  . "testNormalBIT.txt";
        open my $normalFileBIT, '<', $normalFileName or die "Couldn't open file testNormalBIT.txt, $!";

        # now process the file for the bit results
        my @filearray = <$normalFileBIT>;
        #print "file array = @filearray\n";
        close ($normalFileBIT);

        # put the file results into a string
        my $hexString = join('',@filearray);

        # remove the /r and /n from the string
        $hexString =~ s/\r|\n//g;

        #print "Hex String = $hexString\r\n";
		#print $testFileHandle "Hex String = $hexString\r\n";
        # Process the ?bit result
        # Search result for header in the file
        $formatBitHeader = $FORMAT_BIT_A_HEADER;
        $location = index($hexString,$formatBitHeader);

        # move past the first header
        my $stringOffset = $location + 6;

        # get the location of the next header
        my $location2 = index($hexString,$FORMAT_A_HEADER,$stringOffset);

        # get the count of the packet
        my $hexCount = ($location2 - $location)/2 ;

        my $length = ($location2 - $location);

        $imuPacket = substr($hexString,$location, $length );
		print "Process the ?bit result\r\n";
		#print $testFileHandle "\r\nProcess the ?bit result\r\n";		
		if ($hexCount == $FORMAT_BIT_A_SIZE) {
			if ($processPassFail == 1) {
				print "BIT A format size = $hexCount, BIT A Format Test$THREE_TABS Passed\r\n\r\n";
				print $csvFileHandle "BIT A Format Test,Passed\r\n";
				print $testFileHandle "BIT A Format Test Passed Packet Size = $hexCount\r\n";
			}
            $imuPacket = substr($hexString,$location, $length );
        } else {
            if ($processPassFail == 1) {
				print "BIT A format size = $hexCount, Format A test$THREE_TABS Failed\r\n\r\n";
				print $csvFileHandle "BIT A Format Test,Failed\r\n";
				print $testFileHandle "BIT A Format Test Failed Packet Size = $hexCount\r\n";
			}
            $imuPacket = $FORMAT_INVALID_PACKET;
        }
		if ($processPassFail == 1) {
			if ( (index($imuPacket,$FORMAT_BIT_A_RESULT, 0) != -1) && ($hexCount == $FORMAT_BIT_A_SIZE) ) {
				print "BIT A BIT test $THREE_TABS Passed\r\n";
				print $csvFileHandle "BIT A BIT Test,Passed\r\n";
				print $testFileHandle "BIT A BIT Test Passed\r\n";
				print "Format Bit A = $FORMAT_BIT_A_RESULT\r\n";
				print $testFileHandle "Format Bit A = $FORMAT_BIT_A_RESULT\r\n";
				print "IMUPacket = $imuPacket\r\n";
				print $testFileHandle "IMUPacket = $imuPacket\r\n";
			} else {
				print "BIT A BIT test $THREE_TABS Failed imuPacket\r\n";
				print $csvFileHandle "BIT A BIT Test,Failed\r\n";
				print $testFileHandle "BIT A BIT Test Failed\r\n";
				print "Format Bit A = $FORMAT_BIT_A_RESULT\r\n";
				print $testFileHandle "Format Bit A = $FORMAT_BIT_A_RESULT\r\n";
				print "IMUPacket = $imuPacket\r\n";
				print $testFileHandle "IMUPacket = $imuPacket\r\n\r\n";
			}
		}

        # Process the ?bit,2 result
        # Search result for header in the file
        $formatBitHeader = $FORMAT_BIT_B_HEADER;
        $location = index($hexString,$formatBitHeader);
		
        # move past the first header
        $stringOffset = $location + 6;

        # get the location of the next header
        $location2 = index($hexString,$FORMAT_A_HEADER,$stringOffset);

        # get the count of the packet
        $hexCount = ($location2 - $location)/2 ;
        $length = ($location2 - $location);
		print "Process the ?bit2 result\r\n";
		#print $testFileHandle "\r\nProcess the ?bit2 result\r\n";
        if ($hexCount == $FORMAT_BIT_B_SIZE) {
			if ($processPassFail == 1) {
				print "BIT B format size = $hexCount, BIT B format test $THREE_TABS Passed\r\n\r\n";
				print $csvFileHandle "BIT B Format Test,Passed\r\n";
				print $testFileHandle "BIT B Format Test Passed Packet Size = $hexCount\r\n";
			}
			$imuPacket = substr($hexString,$location, $length );
							
        } else {
            if ($processPassFail == 1) {
				print "BIT B format size = $hexCount, BIT B Format test $THREE_TABS Failed\r\n\r\n";
				print $csvFileHandle "BIT B Format Test,Failed\r\n";
				print $testFileHandle "BIT B Format Test Failed Packet Size = $hexCount\r\n";
			}
        }
		if ($processPassFail == 1) {
			if ( (index($imuPacket,$FORMAT_BIT_B_RESULT, 0) != -1) && ($hexCount == $FORMAT_BIT_B_SIZE) ) {
				print "BIT B BIT test $THREE_TABS Passed\r\n";
				print $csvFileHandle "BIT B BIT Test,Passed\r\n";
				print $testFileHandle "BIT B BIT Test Passed\r\n";
				print "Format Bit B = $FORMAT_BIT_B_RESULT\r\n";
				print $testFileHandle "Format Bit B = $FORMAT_BIT_B_RESULT\r\n";
				print "IMUPacket = $imuPacket\r\n";
				print $testFileHandle "IMUPacket = $imuPacket\r\n\r\n";			
			}
			else {
				print "BIT B BIT test $THREE_TABS Failed imuPacket = $imuPacket\r\n\r\n";
				print $csvFileHandle "BIT B BIT Test, Failed\r\n";
				print $testFileHandle "BIT B BIT Test Failed\r\n";
				print "Format Bit B = $FORMAT_BIT_B_RESULT\r\n";
				print $testFileHandle "\r\nFormat Bit B = $FORMAT_BIT_B_RESULT\r\n";
				print "IMUPacket = $imuPacket\r\n";
				print $testFileHandle "IMUPacket = $imuPacket\r\n\r\n";			
			}
		}
    } # end of if (!$normalFileHandleBIT)

    return $imuPacket;

} # end of TestBITFormat

############################################################################
#  TestAXESCommand
#
#  Description: AXES Message Test
#
#       Inputs: $portTest         - comport device is on
#               $csvFileHandle    - file handle to write csv test results
#               $testFileHandle   - file handle to write txt test results
#
#
#      Returns: Success or Failure - 0 or 1
#
# Side Effects: None
#
#        Notes: TODO:
#
############################################################################
sub TestAXESCommand
{
    my $portTest = shift;
    my $csvFileHandle = shift;
    my $testFileHandle = shift;
    my $TrueAXESValue = " ";
    my $AXESValue = "AXES,+0.000000E+00,+0.000000E+00,+1.000000E+00,+1.000000E+00,+0.000000E+00,+0.000000E+00,+0.000000E+00,+1.000000E+00,+0.000000E+00";
   # perform a get of the axis command so we save the actual AXES setting
    my $commandStatus = "?AXES";
    $portTest->write($commandStatus."\n");
    select(undef, undef, undef, 0.25);  # sleep 1/4 second 250 milliseconds

    my $result = $portTest->input;
    print "Start AXES Command Test\r\n";
    print $testFileHandle "Start AXES Command Test\r\n\r\n";
    print "?AXES = $result\r\n";
    #print $testFileHandle "?AXES = $result\r\n";
    $TrueAXESValue = $result;
    #print "TrueAXES get result = $result\r\n";
    print $testFileHandle "?AXES = $result\r\n";
    $commandStatus = "=AXES,0,0,1,1,0,0,0,1,0";
    $portTest->write($commandStatus."\n");
    select(undef, undef, undef, 0.25);  # sleep 1/4 second 250 milliseconds
    $result = $portTest->input;
    print "$commandStatus = $result\r\n";
    print $testFileHandle "$commandStatus = $result\r\n";
    $commandStatus = "?AXES";
    $portTest->write($commandStatus."\n");
    select(undef, undef, undef, 0.25);  # sleep 1/4 second 250 milliseconds
    $result = $portTest->input;
    print "?AXES = $result\r\n";
    print $testFileHandle "?AXES = $result\r\n";
    #print "$AXESValue\r\n";
    if( $result eq "$AXESValue\r\n" ) {
        print "=AXES Test \t\t\tPassed\r\n\r\n";
        print $csvFileHandle "AXES Test,Passed\r\n";
        print $testFileHandle "=AXES Test, Passed $result\r\n";
    } else {
        print "=AXES Test \t\t\tFailed\r\n";
        print $csvFileHandle "AXES Test,Failed\r\n";
        print $testFileHandle "=AXES Test, Failed $result\r\n";
    }
   # perform a set of the axis command so we return the true AXES setting
    $commandStatus = "=$TrueAXESValue";
    #print "TrueAXESValue =$TrueAXESValue\r\n";
    $portTest->write($commandStatus."\n");
    select(undef, undef, undef, 0.25);  # sleep 1/4 second 250 milliseconds
    $result = $portTest->input;
    print "AXES set result = $result\r\n";
    #print $testFileHandle "AXES set result = $result\r\n";
    $commandStatus = "?AXES";
    $portTest->write($commandStatus."\n");
    select(undef, undef, undef, 0.25);  # sleep 1/4 second 250 milliseconds
    $result = $portTest->input;
    print "Return AXES To Original Value = $result\r\n";
    print $testFileHandle "Return AXES To Original Value = $result\r\n";
    print "End of AXES Command Test\r\n";
    print $testFileHandle "End of AXES Command Test\r\n\r\n";
} # end of TestAXESCommand

############################################################################
#  TestEchoCommand()
#
#  Description: Test echo commands
#
#       Inputs: $portTest             - comport device is on
#               $fileHandle           - file handle to write text test results
#               $PortPowerHandle      - comport power supply is connected to
#               $csvFileHandle        - file handle to write csv test results
#               $testFileHandle        - file handle to write txt test results
#
#      Returns: Success or Failure - 0 or 1
#
# Side Effects: None
#
#        Notes: None
#
############################################################################
sub TestEchoCommand
{

    my $portTest        = shift;
    my $csvFileHandle   = shift;
    my $testFileHandle   = shift;
    my $querySetType    = "";
    my $dataType        = "";
    my $expectedResult  = "";
    my $subSuccess      = 1;
    my $testCaseSuccess = 1;
    my $generalStatus   = 1;

    $querySetType = "=";
    $dataType = "NONE";
    $expectedResult = "0";
    $subSuccess = EchoCommand($portTest,$querySetType,$dataType,$expectedResult,$csvFileHandle,$testFileHandle);
    if ($subSuccess == 0) {
        $testCaseSuccess = 0;
    }


    $querySetType = "=";
    $dataType = "NONE";
    $expectedResult = "1";
    $subSuccess = EchoCommand($portTest,$querySetType,$dataType,$expectedResult,$csvFileHandle,$testFileHandle);
    if ($subSuccess == 0) {
        $testCaseSuccess = 0;
    }

    $querySetType = "=";
    $dataType = ",10";
    $expectedResult = "10";
    $subSuccess = EchoCommand($portTest,$querySetType,$dataType,$expectedResult,$csvFileHandle,$testFileHandle);
    if ($subSuccess == 0) {
        $testCaseSuccess = 0;
    }


    $querySetType = "=";
    $dataType = ",reset";
    $expectedResult = "0";
    $subSuccess = EchoCommand($portTest,$querySetType,$dataType,$expectedResult,$csvFileHandle,$testFileHandle);
    if ($subSuccess == 0) {
        $testCaseSuccess = 0;
    }

    if ($testCaseSuccess == 1) {
        print "Echo test $EIGHT_TABS Passed\r\n\r\n";
        print $csvFileHandle "Echo Test,Passed\r\n";
        print $testFileHandle "Echo Test Passed\r\n";
    } else {
        print "Echo test $EIGHT_TABS Failed\r\n\r\n";
        print $csvFileHandle "Echo Test,Failed\r\n";
        print $testFileHandle "Echo Test Failed\r\n";
    }

} # end of TestEchoCommand

############################################################################
#  TestFilterCommands()
#
#  Description: Test Filter Commands
#
#       Inputs: $portTest             - comport device is on
#               $comPortPowerHandle   - comport power is connected to
#               $csvFileHandle        - file handle to write csv test results
#               $testFileHandle       - file handle to write txt test results
#               $deviceName           - the device we are testing
#
#      Returns: None
#
# Side Effects: None
#
#        Notes: DSP1760 variants have no accels, so we will use the devicename
#               to prevent testing accels
#
############################################################################
sub TestFilterCommands
{
    my $portTest       = shift;
    my $csvFileHandle  = shift;
    my $testFileHandle = shift;
    my $deviceName     = shift;

    my $generalStatus  = 1;
    my $successTest    = 0;
    my $successTestAll = 1;

    my $dataRate = "1000";
    TestSetDR($portTest,$dataRate,1,$csvFileHandle,$testFileHandle);

    # test the default setting for filters are intact
    if ((index($deviceName,'DSP') == -1) && (index($deviceName,'IRS') == -1) && (index($deviceName,'DSPU') == -1)){ # DSP and IRST variants have no accels
        $successTest = TestFilterTypeGet($portTest, "a","cheby",$csvFileHandle,$testFileHandle);
        if ($successTest == 0) {
            $successTestAll = 0;
        }
    }

    $successTest = TestFilterTypeGet($portTest, "g","cheby",$csvFileHandle,$testFileHandle);
    if ($successTest == 0) {
        $successTestAll = 0;
    }

    # test the fc20 or the fc command - set the correct values for the filter type
    if ((index($deviceName,'DSP') == -1) && (index($deviceName,'IRS') == -1) && (index($deviceName,'DSPU') == -1)){ # DSP and IRST variants have no accels
        if ( (index($deviceName,'1750') != -1)  || (index($deviceName,'1725') != -1) ) {
            $successTest = TestFCCommand($portTest,"a","cheby",$csvFileHandle,$testFileHandle);
        }
		else {
            $successTest = TestFC20Command($portTest,"a","cheby",$csvFileHandle,$testFileHandle);
        }
        if ($successTest == 0) {
            $successTestAll = 0;
        }
    } #  end of if (index($deviceName,'DSP') == -1)

    if ( (index($deviceName,'1775') == -1) && (index($deviceName,'1760DSPU') == -1) && (index($deviceName,'IRS') == -1)) {
        $successTest = TestFCCommand($portTest,"g","cheby",$csvFileHandle,$testFileHandle);
        print "TestFilterCommands: testing $deviceName FC command\r\n";
    }
	else {
        $successTest = TestFC20Command($portTest,"g","cheby",$csvFileHandle,$testFileHandle);
        print "TestFilterCommands: testing $deviceName FC20 command\r\n";
    }


    if ($successTest == 0) {
        $successTestAll = 0;
    }

    # verify the filttype response is enabled (1)
    TestFilterEnableGet($portTest,"1",$csvFileHandle,$testFileHandle);
    if ($successTest == 0) {
        $successTestAll = 0;
    }

    # the test asks to run the testfilt command here, but we will do it last

    # set the filter type for the accels to butter and verify response
    if ((index($deviceName,'DSP') == -1) && (index($deviceName,'IRS') == -1) && (index($deviceName,'DSPU') == -1)){ # DSP and IRST variants have no accels
        TestFilterTypeSet($portTest,"a","butter",$csvFileHandle,$testFileHandle);
        if ($successTest == 0) {
            $successTestAll = 0;
        }
    }

    # Verify gyro type did not change
    $successTest = TestFilterTypeGet($portTest,"g","cheby",$csvFileHandle,$testFileHandle);
    if ($successTest == 0) {
        $successTestAll = 0;
    }

    # test the fc20 command set the correct values for the filter type; 1760 has no accels
    if ((index($deviceName,'DSP') == -1) && (index($deviceName,'IRS') == -1) && (index($deviceName,'DSPU') == -1)){ # DSP and IRST variants have no accels
        if ( (index($deviceName,'1750') != -1)  || (index($deviceName,'1725') != -1) ) {
            $successTest = TestFCCommand($portTest,"a","butter",$csvFileHandle,$testFileHandle);
        }
		else {
            $successTest = TestFC20Command($portTest,"a","butter",$csvFileHandle,$testFileHandle);
        }

        if ($successTest == 0) {
            $successTestAll = 0;
        }
    } # end of if (index($deviceName,'DSP') == -1)

    if ( (index($deviceName,'1775') == -1) && (index($deviceName,'1760DSPU') == -1) && (index($deviceName,'IRS') == -1)) {
        $successTest = TestFCCommand($portTest,"g","cheby",$csvFileHandle,$testFileHandle);
    }
	else {
        $successTest = TestFC20Command($portTest,"g","cheby",$csvFileHandle,$testFileHandle);
    }
    if ($successTest == 0) {
        $successTestAll = 0;
    }

    # set the gyro to butter
    $successTest = TestFilterTypeSet($portTest, "g","butter",$csvFileHandle,$testFileHandle);
    if ($successTest == 0) {
        $successTestAll = 0;
    }

    if ((index($deviceName,'DSP') == -1) && (index($deviceName,'IRS') == -1) && (index($deviceName,'DSPU') == -1)){ # DSP and IRST variants have no accels
        if ( (index($deviceName,'1750') != -1)  || (index($deviceName,'1725') != -1) ) {
            $successTest = TestFCCommand($portTest,"a","butter",$csvFileHandle,$testFileHandle);
        }
		else {
            $successTest = TestFC20Command($portTest,"a","butter",$csvFileHandle,$testFileHandle);
        }
        if ($successTest == 0) {
            $successTestAll = 0;
        }
    } # end of if (index($deviceName,'DSP') == -1)

    # perform a restart here using the restart command
    ###############################################

    # test that the previous settings for filters are intact
    if ((index($deviceName,'DSP') == -1) && (index($deviceName,'IRS') == -1) && (index($deviceName,'DSPU') == -1)){ # DSP and IRST variants have no accels
        $successTest = TestFilterTypeGet($portTest, "a","butter",$csvFileHandle,$testFileHandle);
        if ($successTest == 0) {
            $successTestAll = 0;
        }
    } # end of if (index($deviceName,'DSP') == -1)

    $successTest = TestFilterTypeGet($portTest, "g","butter",$csvFileHandle,$testFileHandle);
    if ($successTest == 0) {
        $successTestAll = 0;
    }

    # now test the filter coeffs
    if ((index($deviceName,'DSP') == -1) && (index($deviceName,'IRS') == -1) && (index($deviceName,'DSPU') == -1)){ # DSP and IRST variants have no accels
        if ( (index($deviceName,'1750') != -1)  || (index($deviceName,'1725') != -1) ) {
            $successTest = TestFCCommand($portTest,"a","butter",$csvFileHandle,$testFileHandle);
        }
		else {
            $successTest = TestFC20Command($portTest,"a","butter",$csvFileHandle,$testFileHandle);
        }
        if ($successTest == 0) {
            $successTestAll = 0;
        }
    } # end of if (index($deviceName,'DSP') == -1)

    if ( (index($deviceName,'1775') == -1) && (index($deviceName,'1760DSPU') == -1) && (index($deviceName,'IRS') == -1)) {
        $successTest = TestFCCommand($portTest,"g","butter",$csvFileHandle,$testFileHandle);
    }
	else {
        $successTest = TestFC20Command($portTest,"g","butter",$csvFileHandle,$testFileHandle);
    }
    if ($successTest == 0) {
        $successTestAll = 0;
    }

    # now set the custom filters
    my $sensorType = "a";
    if ((index($deviceName,'DSP') == -1) && (index($deviceName,'IRS') == -1) && (index($deviceName,'DSPU') == -1)){ # DSP and IRST variants have no accels
        if ( (index($deviceName,'1750') != -1)  || (index($deviceName,'1725') != -1) ) {
            $successTest = TestFCCustomCommand($portTest,$sensorType,$csvFileHandle,$testFileHandle);
        }
     	else {
            $successTest = TestFC20CustomCommand($portTest,$sensorType,$csvFileHandle,$testFileHandle);
        }
	    if ($successTest == 0) {
        $successTestAll = 0;
		}
    }

    $sensorType = "g";
    if ( (index($deviceName,'1775') == -1) && (index($deviceName,'1760DSPU') == -1)  && (index($deviceName,'IRS') == -1)){
        $successTest = TestFCCustomCommand($portTest,$sensorType,$csvFileHandle,$testFileHandle);
    }
	else {
        $successTest = TestFC20CustomCommand($portTest,$sensorType,$csvFileHandle,$testFileHandle);
    }
    if ($successTest == 0) {
        $successTestAll = 0;
    }

    # test the reset filtertype command
    if ((index($deviceName,'DSP') == -1) && (index($deviceName,'IRS') == -1) && (index($deviceName,'DSPU') == -1)){ # DSP and IRST variants have no accels
        if ( (index($deviceName,'1750') != -1)  || (index($deviceName,'1725') != -1) ) {
            $successTest = TestFCResetCommand($portTest,"a",$csvFileHandle,$testFileHandle);
        }
		else {
            $successTest = TestFC20ResetCommand($portTest,"a",$csvFileHandle,$testFileHandle);
        }
        if ($successTest == 0) {
            $successTestAll = 0;
        }
    } # end of if (index($deviceName,'1760') == -1)


    if ( (index($deviceName,'1775') == -1)  && (index($deviceName,'DSPU') == -1) && (index($deviceName,'IRS') == -1)) {
        $successTest = TestFCResetCommand($portTest,"g",$csvFileHandle,$testFileHandle);
    } else {
        $successTest = TestFC20ResetCommand($portTest,"g",$csvFileHandle,$testFileHandle);
    }
    if ($successTest == 0) {
        $successTestAll = 0;
    }

    if ((index($deviceName,'DSP') == -1) && (index($deviceName,'IRS') == -1) && (index($deviceName,'DSPU') == -1)){ # DSP and IRST variants have no accels
        $successTest = TestFilterTypeGet($portTest,"a","cheby",$csvFileHandle,$testFileHandle);
        if ($successTest == 0) {
            $successTestAll = 0;
        }
    }

    $successTest = TestFilterTypeGet($portTest,"g","cheby",$csvFileHandle,$testFileHandle);
    if ($successTest == 0) {
        $successTestAll = 0;
    }

    # perform a restart here with a power cycle
    ###############################################


    # enter config mode
    # make sure we are in CONFIG mode
    #for (my $indexCount = 0; $indexCount< 4; $indexCount++) {
    #    $generalStatus = SendConfigCommand($portTest,"1",0,$csvFileHandle,$testFileHandle);
    #    if ($generalStatus == 1) {
    #        last;
    #    }
    #} # end of for

    # verify accels are using cheby
    if ((index($deviceName,'DSP') == -1) && (index($deviceName,'IRS') == -1) && (index($deviceName,'DSPU') == -1)){ # DSP and IRST variants have no accels

        $successTest = TestFilterTypeGet($portTest,"a","cheby",$csvFileHandle,$testFileHandle);
        if ($successTest == 0) {
            $successTestAll = 0;
        }

        # set accel filter type to averager
        $successTest = TestFilterTypeSet($portTest,"a","ave",$csvFileHandle,$testFileHandle);
        if ($successTest == 0) {
            $successTestAll = 0;
        }
    }

    # verify gyros are using cheby
    $successTest = TestFilterTypeGet($portTest,"g","cheby",$csvFileHandle,$testFileHandle);
    if ($successTest == 0) {
        $successTestAll = 0;
    }

    # set gyros filter type to averager
    $successTest = TestFilterTypeSet($portTest,"g","ave",$csvFileHandle,$testFileHandle);
    if ($successTest == 0) {
        $successTestAll = 0;
    }

    # test that the filter is enabled
    # verify the filttype response is enabled (1)
    $successTest = TestFilterEnableGet($portTest,"1",$csvFileHandle,$testFileHandle);
    if ($successTest == 0) {
        $successTestAll = 0;
    }

    # send the cfgreset command
    $successTest = TestCfgRstCommand($portTest,$csvFileHandle,$testFileHandle);
    if ($successTest == 0) {
        $successTestAll = 0;
    }

    if ($successTestAll == 1) {
        print $csvFileHandle "Filter Test,Passed\r\n";
        print $testFileHandle "Filter Test Passed\r\n";
        print "Filter Test    Passed\r\n";
    } else {
        print $csvFileHandle "Filter Test,Failed\r\n";
        print $testFileHandle "Filter Test Failed\r\n";
        print "Filter Test Failed\r\n";
    }

} # end of TestFilterCommands

############################################################################
#  TestHelpMenuCommand
#
#  Description: Help Menu Test in DEBUG and CONFIG mode
#
#       Inputs: $portTest         - comport device
#               $csvFileHandle    - file handle to write csv test results
#               $testFileHandle    - file handle to write txt test results
#               $storageDirectory - directory to write the output help files to
#
#      Returns: None
#
# Side Effects: None
#
#        Notes: TODO; returns
#
############################################################################
sub TestHelpMenuCommand
{

    my $portTest           = shift;
    my $csvFileHandle      = shift;
    my $testFileHandle      = shift;
    my $storageDirectory   = shift;
    my $modeSetting        = shift;

    my $helpSuccessTest    = 0;
    my $helpSuccessTestAll = 1;
    my $generalStatus      = 1;
    my $indexCount         = 0;

    if ($modeSetting == $DEBUG_MODE) {
        # make sure we are in Debug mode
        for ($indexCount = 0; $indexCount< 4; $indexCount++) {

            $generalStatus = SendDebugCommand($port,"1",1,$csvFileHandle,$testFileHandle);

            if ($generalStatus == $SUCCESS) {
                last;
            }
        }

        my $debugFileName = $storageDirectory . "testHelpDebug.txt";
        print "\nMENU debugFileName  = $debugFileName\n";

        open my $debugFileHandle, '>', $debugFileName or die "Couldn't open file testHelpDebug.txt, $!";

        if (!$debugFileHandle) {
          print "The testHelpDebug.txt did not open - test Failed\r\n";
          print $csvFileHandle "Debug Mode Help Menu Command Test, Failed\r\n";
          print $testFileHandle "The Debug Mode Help Menu Command Test Failed The testHelpDebug.txt file did not open\r\n";
          $helpSuccessTest = $FAILED;
        } else {

            # make sure we are in Debug mode
            for ($indexCount = 0; $indexCount< 4; $indexCount++) {
                $generalStatus = SendDebugQueryCommand($portTest,1,$csvFileHandle,$testFileHandle);
                if ($generalStatus == $SUCCESS) {
                    last;
                }
            }

            # send the halt command
            TestHalt($portTest, $csvFileHandle,$testFileHandle,1);

            $helpSuccessTest = GetHelpMenuTest($portTest,$debugFileHandle);
            if ($helpSuccessTest == $FAILED) {
                $helpSuccessTestAll = $FAILED;
            }
            close($debugFileHandle);
        } # end of else of if (!$debugFileHandle)

    } elsif ($modeSetting == $CONFIG_MODE){


        my $configFileName = $storageDirectory . "testHelpConfig.txt";
        print "\nMENU configFileName  = $configFileName\n";
        open my $configFileHandle, '>', $configFileName or die "Couldn't open file testHelpConfig.txt, $!";

        if (!$configFileHandle) {
            print "The Config Mode Help Menu Command Test $SIX_TABS Failed, The testHelpConfig.txt did not open\r\n";
            print $csvFileHandle "Config Mode Help Menu Command Test, Failed\r\n";
            print $testFileHandle "The Config Mode Help Menu Command Test Failed The testHelpConfig.txt file did not open\r\n";
            $helpSuccessTest = $FAILED;
        } else {
            SendConfigCommand($portTest,"1",0,$csvFileHandle,$testFileHandle);
            $helpSuccessTest = GetHelpMenuTest($portTest, $configFileHandle);
            if ($helpSuccessTest == $FAILED) {
                $helpSuccessTestAll = $FAILED;
            }
            close($configFileHandle);
        }
    }

    if ($helpSuccessTestAll == $SUCCESS) {
        print "Help Menu Test,Passed\r\n";
        print $csvFileHandle "Help Menu Test,Passed\r\n";
        print $testFileHandle "Help Menu Test Passed\r\n";

    } else {
        print "Help Menu Test,Failed\r\n";
        print $csvFileHandle "Help Menu Test,Failed\r\n";
        print $testFileHandle "Help Menu Test Failed\r\n";
        $helpSuccessTestAll = $FAILED;
    }

    return $helpSuccessTestAll;

} # end of TestHelpMenuCommand



############################################################################
#  TestUpgradeHelpMenuCommand
#
#  Description: Help Menu Test in UPGRADE mode
#
#       Inputs: $portTest         - comport device
#               $csvFileHandle    - file handle to write csv test results
#               $testFileHandle    - file handle to write txt test results
#               $storageDirectory - directory to write the output help files to
#
#      Returns: None
#
# Side Effects: None
#
#        Notes: TODO; returns
#
############################################################################
sub TestUpgradeHelpMenuCommand
{

    my $portTest           = shift;
    my $csvFileHandle      = shift;
    my $testFileHandle      = shift;
    my $storageDirectory   = shift;

    my $helpSuccessTest    = 0;
    my $helpSuccessTestAll = 1;
    my $generalStatus      = 1;
    my $indexCount         = 0;

    # make sure we are in Upgrade mode
    for ($indexCount = 0; $indexCount< 4; $indexCount++) {
        $generalStatus = SendUpgradeCommand($port,"1",1,$csvFileHandle,$testFileHandle);
        if ($generalStatus == $SUCCESS) {
            last;
        }
    }

    my $upgradeFileName = $storageDirectory . "testHelpUpgrade.txt";
    print "\nMENU $upgradeFileName  = $upgradeFileName\n";

    open my $upgradeFileHandle, '>', $upgradeFileName or die "Couldn't open file testHelpUpgrade.txt, $!";

    if (!$upgradeFileHandle) {
      print "The Upgrade Mode Help Menu Test $SIX_TABS Failed, The testHelpUpgrade.txt did not open\r\n";
      print $csvFileHandle "Upgrade Mode Help Menu Test, Failed\r\n";
      print $testFileHandle "The Upgrade Mode Help Menu Test Failed The testHelpDebug.txt file did not open\r\n";
      $helpSuccessTest = $FAILED;
    } else {

        # make sure we are in Upgrade mode
        for ($indexCount = 0; $indexCount< 4; $indexCount++) {
            $generalStatus = SendDebugQueryCommand($portTest,1,$csvFileHandle,$testFileHandle);
            if ($generalStatus == $SUCCESS) {
                last;
            }
        }

        $helpSuccessTest = GetHelpMenuTest($portTest,$upgradeFileHandle);
        if ($helpSuccessTest == $FAILED) {
            $helpSuccessTestAll = $FAILED;
        }
        close($upgradeFileHandle);
    } # end of else of if (!$upgradeFileHandle)


    if ($helpSuccessTestAll == $SUCCESS) {
        print "Upgrade Help Menu Test,Passed\r\n";
        print $csvFileHandle "Upgrade Help Menu Test,Passed\r\n";
        print $testFileHandle "Upgrade Help Menu Test Passed\r\n";
    } else {
        print "Upgrade Help Menu Test,Failed\r\n";
        print $csvFileHandle "Upgrade Help Menu Test,Failed\r\n";
        print $testFileHandle "Upgrade Help Menu Test Failed\r\n";
        $helpSuccessTestAll = $FAILED;
    }

    return $helpSuccessTestAll;
} # end of TestHelpMenuCommand

############################################################################
#  TestRestartShutdown()
#
#  Description: test the restart command
#
#       Inputs: $portTest         - comport device
#               $csvFileHandle    - file handle to write csv test results
#               $testFileHandle    - file handle to write txt test results
#
#      Returns: None
#
# Side Effects: None
#
#        Notes: None
#
############################################################################

sub TestRestartShutdown
{
    my $portTest      = shift;
    my $csvFileHandle = shift;
    my $testFileHandle = shift;

    #make sure we are in a mode that will accept the command
    for (my $indexCount = 0; $indexCount < 4; $indexCount++) {
        SendConfigCommand($portTest,"1",0,$csvFileHandle,$testFileHandle);
    }

    RestartCommand($portTest);

    #reset the configuration

    $portTest->databits(8);
    $portTest->baudrate(921600);
    $portTest->parity("none");
    $portTest->stopbits(1);
    $portTest->handshake("none");
    $portTest->buffers(4096, 4096);

    $portTest->write_settings || undef $portTest;
    $portTest->save($comPortConfigFile);

    sleep 1;
    $portTest->restart($comPortConfigFile);

    sleep 2;

} # end of TestRestartShutdown()


############################################################################
#  TestConfigResetConfig()
#
#  Description: Test the cfg reset configuration command
#
#       Inputs: $portTest         - comport device is on
#               $csvFileHandle    - file handle to write csv test results
#               $testFileHandle    - file handle to write csv test results
#
#      Returns: Success or Failure - 0 or 1
#
# Side Effects: None
#
#        Notes: TODO: check ranges
#
############################################################################
sub TestConfigResetConfig
{
    my $portTest       = shift;
    my $csvFileHandle  = shift;
    my $testFileHandle = shift;
    my $ModeStatus     = shift;
    my $deviceName     = shift;

    my $dataValue   = "";
    my $subSuccess  = $SUCCESS;
    my $testSuccess = $SUCCESS;

    # send the cfgreset command
    $subSuccess = TestCfgRstCommand($portTest,$csvFileHandle,$testFileHandle);
    if ($subSuccess == $FAILED) {
        $testSuccess = $FAILED;
    }

    # test the default settings for the individual commands
    $dataValue = "DELTA";
    TestRotationFormatGet($portTest,$dataValue,$csvFileHandle,$testFileHandle);

    $dataValue = "RATE";
    TestRotationFormatSet($portTest,$dataValue,$csvFileHandle,$testFileHandle);

    $dataValue = "RAD";
    TestRotationUnitsGet($portTest,$dataValue,$csvFileHandle,$testFileHandle);

    $dataValue = "DEG";
    TestRotationUnitsSet($portTest,$dataValue, $csvFileHandle,$testFileHandle);

    $dataValue = "ACCEL";
    TestLinearFormatGet($portTest,$dataValue,$csvFileHandle,$testFileHandle);

    $dataValue = "DELTA";
    TestLinearFormatSet($portTest,$dataValue,$csvFileHandle,$testFileHandle);

    $dataValue = "METERS";
    TestLinearUnitsGet($portTest,$dataValue,$csvFileHandle,$testFileHandle);

    $dataValue = "FEET";
    TestLinearUnitsSet($portTest,$dataValue, $csvFileHandle,$testFileHandle);

    $dataValue = "C";
    TestTempUnitsGet($portTest,$dataValue,$csvFileHandle,$testFileHandle);

    $dataValue = "F";
    TestTempUnitsSet($portTest,$dataValue,$csvFileHandle,$testFileHandle);

    if ((index($deviceName,'1775') != -1)) {

        $dataValue = "C_100";
        TestTempUnitsSet($portTest,$dataValue,$csvFileHandle,$testFileHandle);

        $dataValue = "F_100";
        TestTempUnitsSet($portTest,$dataValue,$csvFileHandle,$testFileHandle);
    }

    # DSP1760 has no Accels, so don't run this test
    if ((index($deviceName,'DSP') == -1) && (index($deviceName,'DSPU') == -1) && (index($deviceName,'IRS') == -1)) {
        TestFilterTypeGet($portTest,"a","cheby",$csvFileHandle,$testFileHandle);
        TestFilterTypeSet($portTest,"a","butter",$csvFileHandle,$testFileHandle);
    }

    TestFilterTypeGet($portTest,"g","cheby",$csvFileHandle,$testFileHandle);
    TestFilterTypeSet($portTest,"g","butter",$csvFileHandle,$testFileHandle);

    # send the cfgreset command
    $subSuccess = TestCfgRstCommand($portTest,$csvFileHandle,$testFileHandle);
    if ($subSuccess == $FAILED) {
        $testSuccess = $FAILED;
    }

    # test that everything has been set to defaults
    $dataValue = "DELTA";
    TestRotationFormatGet($portTest,$dataValue,$csvFileHandle,$testFileHandle);

    $dataValue = "RAD";
    TestRotationUnitsGet($portTest,$dataValue,$csvFileHandle,$testFileHandle);


    $dataValue = "ACCEL";
    TestLinearFormatGet($portTest,$dataValue,$csvFileHandle,$testFileHandle);

    $dataValue = "METERS";
    TestLinearUnitsGet($portTest,$dataValue,$csvFileHandle,$testFileHandle);


    $dataValue = "C";
    my $tempUnits;
    ($subSuccess, $tempUnits) = TestTempUnitsGet($portTest,$dataValue,$csvFileHandle,$testFileHandle);
    if ($subSuccess == $FAILED) {
        $testSuccess = $FAILED;
    }

    # outputfmt command only supported by 1775
    if (index($deviceName,'1775') != -1) {
        # verify the default output format type is A
        $dataValue = "A";
        $subSuccess = TestOutputFormatGetCommand($portTest,$csvFileHandle,$testFileHandle,$dataValue);
        if ($subSuccess == $FAILED) {
            $testSuccess = $FAILED;
        }
    }

    # verify the filttype is cheby for the accels
    # check for DSP1760 variants as they have no accels
    if ((index($deviceName,'DSP') == -1) && (index($deviceName,'DSPU') == -1) && (index($deviceName,'IRS') == -1)) {
        $subSuccess = TestFilterTypeGet($portTest,"a","cheby",$csvFileHandle,$testFileHandle);
        if ($subSuccess == $FAILED) {
            $testSuccess = $FAILED;
        }
    }

    # verify the filttype is cheby for the gyros
    $subSuccess = TestFilterTypeGet($portTest,"g","cheby",$csvFileHandle,$testFileHandle);
    if ($subSuccess == $FAILED) {
        $testSuccess = $FAILED;
    }

    # verify the filttype response is enabled (1)
    $subSuccess = TestFilterEnableGet($portTest,"1",$csvFileHandle,$testFileHandle);
    if ($subSuccess == $FAILED) {
        $testSuccess = $FAILED;
    }

    # verify the startrup mode is NORMAL - Not supported in CONFIG mode
    if ($ModeStatus ne "CONFIG") {
        $dataValue = "NORMAL";
        $subSuccess = TestStartupModeGetCommand($portTest,$csvFileHandle,$testFileHandle,$dataValue);
        if ($subSuccess == $FAILED) {
            $testSuccess = $FAILED;
        }
    }

    return $testSuccess;

} # end of TestConfigResetConfig

############################################################################
#  TestSerialNumberCommand
#
#  Description: Test the Serial Number
#
#       Inputs: $portTest         - comport device is on
#               $logTestResults   - Whether to log the test result or not
#               $csvFileHandle    - file handle to write csv test results
#               $testFileHandle    - file handle to write txt test results
#
#      Returns: Success or Failure - 0 or 1
#
# Side Effects: None
#
#        Notes: TODO: check ranges
#
############################################################################
sub TestSerialNumberCommand
{
    my $portTest       = shift;
    my $logTestResults = shift;
    my $csvFileHandle  = shift;
    my $testFileHandle  = shift;
    my $serialNumber = 0;
    my @serialNumberArray;

    my $testSuccess = $SUCCESS;

    my $command = "?is";
    $portTest->write($command."\n");

    select(undef, undef, undef, 0.25);
    my $result = $portTest->input;

    if ($logTestResults == 1) {

        # remove the carriage return line feed;
        $result =~ s/\r|\n//g;

        if ((index($result,'IS') != -1)) {
            # now return the serial number for use in the file  name
            @serialNumberArray = split(/,/,$result);
            $serialNumber = $serialNumberArray[1];
            #print $testFileHandle "Serial Number= $serialNumber $SIX_TABS\r\n";
			print "\n?is Test $result $SIX_TABS Passed\n\n";
            print $csvFileHandle "?is Test Serial # = $serialNumber,Passed\r\n";
            print $testFileHandle "?is Test Serial # = $serialNumber Passed\r\n";
            $testSuccess = $SUCCESS;
        } else {
            print "\nSerial Number Test $SIX_TABS Failed\n";
            print $csvFileHandle "?is Test,Failed,\r\n";
            print $testFileHandle "?is Test Failed $SIX_TABS\r\n";
            $testSuccess = $FAILED;
        }
    } # end of if ($logTestResults == 1)

    return ($testSuccess, $serialNumber);

} # end of TestSerialNumberCommand


############################################################################
#  TestSystemConfigCommand
#
#  Description: Test the System Config command
#
#       Inputs: $portTest         - comport device is on
#
#      Returns: Success or Failure - 0 or 1
#
# Side Effects: None
#
#        Notes: This command is used to find the device type;
#               It is not part of the test results as it can only be run from
#               DEBUG mode.
#
############################################################################
sub TestSystemConfigCommand
{
    my $portTest = shift;

    my $sysConfigDeviceName = "1775IMU";
    my @sysConfigArray;

    my $command = "?sysconfig";
    $portTest->write($command."\n");

    select(undef, undef, undef, 0.25);
    my $result = $portTest->input;

    # remove the carriage return line feed;
    $result =~ s/\r|\n//g;

    if ((index($result,'SYSCONFIG') != -1)) {
        print "System Config $result \r\n\r\n";

        # now return the device name
        @sysConfigArray = split(/,/,$result);
        $sysConfigDeviceName = $sysConfigArray[1];

    } else {
        print "System Config Test $SIX_TABS Failed\r\n";
        $sysConfigDeviceName =  "UNKNOWN_DEVICE";
    }

    return $sysConfigDeviceName;

} # end of TestSystemConfigCommand


############################################################################
#  TestConfigTemperature
#
#  Description: Test the Get Temperature command ?temp in Config Mode
#
#       Inputs: $portTest         - comport device is on
#               $logTestResults   - Whether to log the test result or not
#               $csvFileHandle    - file handle to write csv test results
#               $testFileHandle    - file handle to write test file results
#
#      Returns: Success or Failure - 0 or 1
#
# Side Effects: None
#
#        Notes: Returns the form of TEMP,43 or TEMP,43.68 when using C_100, for example
#
############################################################################
sub TestConfigTemperature
{
    my $portTest = shift;
    my $logTestResults = shift;
    my $csvFileHandle  = shift;
    my $testFileHandle  = shift;

    my $testTempUnits;
    my $testTempValueSuccess = $SUCCESS;
    my $testTempUnitsSuccess = $SUCCESS;
    my $testTempCfgSuccess = $SUCCESS;

    my ($temperature, $farenheigt, $celsius);

    # get the units
    my $commandStatus = "?tempunits";
    $portTest->write($commandStatus."\n");
    select(undef, undef, undef, 0.25);  # sleep 1/4 second 250 milliseconds

    my $result = $portTest->input;
    print "tempunits result = $result";

    # remove the carriage return line feed;
    $result =~ s/\r|\n//g;

    my @temperatureUnitValues = split(',', $result);

    my $dataValue = $temperatureUnitValues[1];

    if ( ($dataValue eq "F") || ($dataValue eq "F_100") || ($dataValue eq "C") || ($dataValue eq "C_100") ){
        $testTempUnitsSuccess  = $SUCCESS;
    } else {
        $testTempUnitsSuccess  = $FAILED;
    }

    if ($testTempUnitsSuccess  == $SUCCESS  ) {

        my $command = "?temp";
        $portTest->write($command."\n");

        select(undef, undef, undef, 0.75);  # sleep 1/4 second 250 milliseconds
        my $result = $portTest->input;
        print "Config Mode temperature get result = $result";

        #print "temerature result = $result";

        # remove the carriage return line feed;
        $result =~ s/\r|\n//g;

        # convert to a value remove cr
        $temperature = chomp($result);
        #  TEMP,43 or TEMP,43.68 when using C_100, for example

        my @temperatureValues = split(',', $result);

        if ((index($result,'TEMP') != -1)) {

         my $arraySize = @temperatureValues;
            print "size of array: $arraySize.\n";

            if ($arraySize == $NUM_TEMP_VALUESCONFIG) {

                foreach my $tempVal (@temperatureValues) {
                    print "tempVal = $tempVal\n";

                    if ($tempVal eq "TEMP")  {
                        print "TEMP RECIEVED\r\n";
                    } elsif ($dataValue eq "C") {

                        if ( ($tempVal < $MIN_TEMP_C) || ($tempVal > $MAX_TEMP_C) ) {
                            printf ("Invalid Temperature C = %4.2f \r\n",$tempVal);
                            $testTempValueSuccess = $FAILED;
                            last;
                        } else {
                            printf ("temerature C = %4.2f \r\n",$tempVal) ;
                        }

                    } elsif ($dataValue eq "C_100") {

                        $tempVal = $tempVal / 100;

                        if ( ($tempVal < $MIN_TEMP_C) || ($tempVal > $MAX_TEMP_C) ) {
                            printf ("Invalid Temperature C = %4.2f \r\n",$tempVal);
                            $testTempValueSuccess = $FAILED;
                            last;
                        } else {
                            printf ("temerature C = %4.2f \r\n",$tempVal) ;
                        }

                    } elsif ($dataValue eq "F") {

                        if ( ($tempVal < $MIN_TEMP_F) || ($tempVal > $MAX_TEMP_F) )  {
                            printf ("Invalid Temperature F = %4.2f \r\n",$tempVal);
                            $testTempValueSuccess = $FAILED;
                            last;
                        } else {
                            printf ("temerature F = %4.2f \r\n",$tempVal);
                        }
                    } elsif ($dataValue eq "F_100") {

                        $tempVal = $tempVal / 100;

                        if ( ($tempVal < $MIN_TEMP_F) || ($tempVal > $MAX_TEMP_F) )  {
                            printf ("Invalid Temperature F = %4.2f \r\n",$tempVal);
                            $testTempValueSuccess = $FAILED;
                            last;
                        } else {
                            printf ("temerature F = %4.2f \r\n",$tempVal);
                        }
                    }
                } # end of foreach my $tempVal (@temperatureValues)

            } else {
                $testTempValueSuccess = $FAILED;
                print "Temperature test $result does not have correct number of values\r\n\r\n";
                print $testFileHandle "?temp command test result $result does not have correct number of values\r\n";

            } # end of if ($arraySize == $NUM_TEMP_VALUESCONFIG)

        } else {
            $testTempValueSuccess = $FAILED;
            print "Temperature test $result does not have TEMP in the string\r\n\r\n";
            print $testFileHandle " ?temp command test result $result does not have TEMP in the string\r\n";

        } # end of if ((index($result,'TEMP') != -1))


        # check if the TEMP keyword is there. We don't check the value here
        # but we will dump the value in the test
        if ( ($testTempUnitsSuccess  == $SUCCESS  ) && ($testTempValueSuccess == $SUCCESS) ) {
            print "TestConfigTemperature test $result $SIX_TABS Passed\r\n\r\n";
            print $csvFileHandle "?temp Test,Passed\r\n";
            print $testFileHandle "?temp Test Passed $result\r\n";
            $testTempCfgSuccess = $SUCCESS;

        } else {
            print "TestConfigTemperature test $result $SIX_TABS Failed\r\n";
            print $csvFileHandle "?temp Test,Failed,\r\n";
            print $testFileHandle "?temp Test Failed $result\r\n";
            $testTempCfgSuccess = $FAILED;
        }

    } #  end of if ($testTempUnitsSuccess  = $SUCCESS  )

    return $testTempCfgSuccess;

}  # end of TestConfigTemperature



############################################################################
#  TestTemperature
#
#  Description: Test the Get Temperature command ?temp in Debug Mode
#
#       Inputs: $portTest         - comport device is on
#               $logTestResults   - Whether to log the test result or not
#               $csvFileHandle    - file handle to write csv test results
#               $testFileHandle    - file handle to write csv test results
#
#      Returns: Success or Failure - 0 or 1
#
# Side Effects: None
#
#        Notes: Returns the form of TEMP,43.688,39.464,40.131,40.740
#
############################################################################
sub TestTemperature
{
    my $portTest = shift;
    my $logTestResults = shift;
    my $csvFileHandle  = shift;
    my $testFileHandle = shift;
    my $deviceName     = shift;

    my $testTempUnits;
    my $testTempUnitsSuccess = $SUCCESS;
    my $testTempValueSuccess = $SUCCESS;

    my ($farenheigt, $celsius);

   # get the units
    my $commandStatus = "?tempunits";
    $portTest->write($commandStatus."\n");
    select(undef, undef, undef, 0.25);  # sleep 1/4 second 250 milliseconds

    my $result = $portTest->input;
    print "tempunits result = $result";

    # remove the carriage return line feed;
    $result =~ s/\r|\n//g;

    my @temperatureUnitValues = split(',', $result);

    my $dataValue = $temperatureUnitValues[1];

    if ( ($dataValue eq "F") || ($dataValue eq "F_100") || ($dataValue eq "C") || ($dataValue eq "C_100") ){
        $testTempUnitsSuccess  = $SUCCESS;
    } else {
        $testTempUnitsSuccess  = $FAILED;
    }

    if ($testTempUnitsSuccess  == $SUCCESS  ) {

        my $command = "?temp";
        $portTest->write($command."\n");

        select(undef, undef, undef, 0.75);  # sleep 1/4 second 250 milliseconds
        my $result = $portTest->input;

        print "temerature result = $result";

        # remove the carriage return line feed;
        $result =~ s/\r|\n//g;

        # test for TEMP in string
        if ((index($result,'TEMP') != -1)) {

            my @temperatureValues = split(',', $result);

            my $arraySize = @temperatureValues;
             print "size of array: $arraySize.\n";



            if ((index($deviceName,'DSP') != -1) || (index($deviceName,'DSPU') != -1) || (index($deviceName,'IRS') != -1)) {
                if ( ($temperatureValues[1] < $MIN_TEMP_C) || ($temperatureValues[1] > $MAX_TEMP_C) ) {
                    printf "Invalid Temperature C = %4.3f \r\n",$temperatureValues[1];
                    $testTempValueSuccess = $FAILED;
                    last;
                } else {
                    printf "temerature C = %4.3f \r\n",$temperatureValues[1];
                }
            } else { # all other non-DSP variants

                if ($arraySize == $NUM_TEMP_VALUESDEBUG) {

                    foreach my $tempVal (@temperatureValues) {
                        # print "$tempVal\n";

                        if ($tempVal eq "TEMP")  {
                            print "TEMP RECIEVED\r\n";
                        } elsif ($dataValue eq "C")  {

                            if ( ($tempVal < $MIN_TEMP_C) || ($tempVal > $MAX_TEMP_C) ) {
                                printf "Invalid Temperature C = %4.3f \r\n",$tempVal ;
                                $testTempValueSuccess = $FAILED;
                                last;
                            } else {
                                printf "temerature C = %4.3f \r\n",$tempVal ;
                            }

                        } elsif ($dataValue eq "C_100")  {

                            if ( ($tempVal < $MIN_TEMP_C) || ($tempVal > $MAX_TEMP_C) ) {
                                printf "Invalid Temperature C = %4.3f \r\n",$tempVal ;
                                $testTempValueSuccess = $FAILED;
                                last;
                            }
                            printf "temerature C = %4.3f \r\n",$tempVal ;
                        } elsif ($dataValue eq "F")  {

                            if ( ($tempVal < $MIN_TEMP_F) || ($tempVal > $MAX_TEMP_F) )  {
                                printf "Invalid Temperature F = %4.3f \r\n",$tempVal ;
                                $testTempValueSuccess = $FAILED;
                                last;
                            } else {
                                printf "temerature F = %4.3f \r\n",$tempVal ;
                            }
                        } elsif ($dataValue eq "F_100")  {

                            if ( ($tempVal < $MIN_TEMP_F) || ($tempVal > $MAX_TEMP_F) )  {
                                printf "Invalid Temperature F = %4.3f \r\n",$tempVal ;
                                $testTempValueSuccess = $FAILED;
                                last;
                            } else {
                                printf "temerature F = %4.3f \r\n",$tempVal ;
                            }
                        }
                    } # end of foreach my $tempVal (@temperatureValues)

                } #  end of if (index($deviceName,'1760') != -1)
                else { # end of  if ($arraySize == 4)
                    $testTempValueSuccess = $FAILED;
                    print "Temperature test $result does not have correct number of values\r\n\r\n";
                    print $testFileHandle "?temp Test result $result does not have correct number of values\r\n";

                }
            }
        } else {
            $testTempValueSuccess = $FAILED;
            print "Temperature test $result does not have TEMP in the string\r\n\r\n";
            print $testFileHandle "?temp Test result $result does not have TEMP in the string\r\n";
        }

        # check if the TEMP keyword is there. We don't check the value here
        # but we will dump the value in the test
        if ( ($testTempUnitsSuccess  == $SUCCESS  ) && ($testTempValueSuccess == $SUCCESS) ) {
            print "Temerature test $result $SIX_TABS Passed\r\n\r\n";
            print $csvFileHandle "?temp Test,Passed\r\n";
            print $testFileHandle "?temp Test Passed $result\r\n";
        } else {
            print "Temerature test $result $SIX_TABS Failed\r\n";
            print $csvFileHandle "?temp Test,Failed,\r\n";
            print $testFileHandle "?temp Test Failed $result\r\n";
        }


    } #  end of if ($testTempUnitsSuccess  = $SUCCESS  )

}  # end of TestTemperature

############################################################################
#  TestVoltage
#
#  Description: Test the Get Voltage Command ?volt
#
#       Inputs: $portTest         - comport device is on
#               $logTestResults   - Whether to log the test result or not
#               $csvFileHandle    - file handle to write csv test results
#               $testFileHandle    - file handle to write txt test results
#
#      Returns: Success or Failure - 0 or 1
#
# Side Effects: None
#
#        Notes: returns the form of VOLT,1.191,3.294,4.949,14.520
#
############################################################################
sub TestVoltage
{
    my $portTest = shift;
    my $logTestResults = shift;
    my $csvFileHandle  = shift;
    my $testFileHandle  = shift;

    my $testVoltageValueSuccess = $SUCCESS;
    my $voltageString;

    my $command = "?volt";
    $portTest->write($command."\n");

    select(undef, undef, undef, 1.75);  # sleep 1/4 second 250 milliseconds
    my $result = $portTest->input;

    if ($logTestResults == 1) {
        print "Voltage result = $result";


        if ((index($result,'VOLT') != -1)) {

            # remove the carriage return line feed;
            $result =~ s/\r|\n//g;

            $voltageString = $result;

            my @voltageValues = split(',', $voltageString);

            my $arraySize = @voltageValues;
            print "size of array: $arraySize.\n";

            if ($arraySize == $NUM_VOLTAGE_VALUES) {

                if (($voltageValues[1] < $MIN_VOLTAGE_1V3 || $voltageValues[1] > $MAX_VOLTAGE_1V3) ) {
                    printf "Invalid Voltage F = %4.2f \r\n",$voltageValues[2];
                    $testVoltageValueSuccess = $FAILED;
                } else{
                    printf "1.3 Voltage = %4.2f \r\n",$voltageValues[1];
                }

                if ( ($voltageValues[2] < $MIN_VOLTAGE_3V3) || ($voltageValues[2] > $MAX_VOLTAGE_3V3) ) {
                    printf "Invalid Voltage F = %4.2f \r\n",$voltageValues[2];
                    $testVoltageValueSuccess = $FAILED;
                } else {
                    printf "3.3 Voltage = %4.2f \r\n",$voltageValues[2];
                }

                if ( ($voltageValues[3] < $MIN_VOLTAGE_5V0) || ($voltageValues[3] > $MAX_VOLTAGE_5V0) ) {
                    printf "Invalid Voltage F = %4.2f \r\n",$voltageValues[3];
                    $testVoltageValueSuccess = $FAILED;
                } else {
                    printf "5.0 Voltage = %4.2f \r\n",$voltageValues[3];
                }
            } else {
                $testVoltageValueSuccess = $FAILED;
                print "Voltage test $result does not have correct number of values\r\n\r\n";
                print $testFileHandle "?volt Test result $result does not have correct number of values\r\n";
            }

        } else {
            $testVoltageValueSuccess = $FAILED;
            print "Voltage test $result does not have VOLT in the string\r\n\r\n";
            print $testFileHandle "?volt Test result $result does not have VOLT in the string\r\n";
        }


        # check if the TEMP keyword is there. We don't check the value here
        # but we will dump the value in the test
        if (  ($testVoltageValueSuccess == $SUCCESS) ) {
            print "Voltage test $result $FIVE_TABS Passed\r\n\r\n";
            print $csvFileHandle "?volt Test,Passed\r\n";
            print $testFileHandle "?volt Test Passed $result\r\n";
        } else {
            print "Voltage test $result $FIVE_TABS Failed\r\n";
            print $csvFileHandle "?volt Test,Failed,\r\n";
            print $testFileHandle "?volt Test Failed $result\r\n";
        }
    } # end of if ($logTestResults == 1)
}  # end of TestVoltage

############################################################################
#  TestLogs
#
#  Description: Test the ?logs command - Gets the logs of any BIT result saved in Flash memory
#
#       Inputs: $portTest         - comport device is on
#               $csvFileHandle    - file handle to write csv test results
#               $testFileHandle    - file handle to write csv test results
#
#      Returns: Success or Failure - 0 or 1
#
# Side Effects: None
#
#        Notes: None
#
############################################################################
sub TestLogs
{
    my $portTest = shift;
    my $csvFileHandle  = shift;
    my $testFileHandle  = shift;

    my $command = "?logs";
    $portTest->write($command."\n");

    select(undef, undef, undef, 2.00);  # sleep 2 seconds
    my $result = $portTest->input;
    print "\r\nlogs result = $result\r\n";
    # remove the carriage return line feed;
    $result =~ s/\r|\n//g;

    # check if the Log keyword is there. We don't check the value here
    # but we will dump the value in the test
    if ((index($result,'Start of log entries!') != -1)) {
        print "?logs command test $SIX_TABS Passed\r\n\r\n";
        print $csvFileHandle "?logs Command Test,Passed\r\n";
        print $testFileHandle "?logs Command Test Passed $result\r\n";
    } else {
        print "?logs command test $SIX_TABS Failed\r\n";
        print $csvFileHandle "?logs Command Test,Failed\r\n";
        print $testFileHandle "?logs Command Test Failed $result\r\n";
    }

}  # end of TestLogs

############################################################################
#  TestClearLogs
#
#  Description: Test the =logs,clear command - Clears the logs of any BIT result saved in Flash memory
#
#       Inputs: $portTest         - comport device is on
#               $csvFileHandle    - file handle to write csv test results
#               $testFileHandle    - file handle to write txt test results
#
#      Returns: Success or Failure - 0 or 1
#
# Side Effects: None
#
#        Notes: None
#
############################################################################
sub TestClearLogs
{
    my $portTest = shift;
    my $csvFileHandle  = shift;
    my $testFileHandle  = shift;

    my $command = "=logs,clear";
    $portTest->write($command."\n");

    # sleep for 10 seconds as the logs may be large and we need to allow them to be cleared
    sleep 10;
    my $result = $portTest->input;
    print "\r\nlogs clear result = $result\r\n";
    # remove the carriage return line feed;
    $result =~ s/\r|\n//g;

    # check if the LOGS,CLEAR: keyword is there. We don't check the value here
    # but we will dump the value in the test
    if ((index($result,'LOGS,CLEAR:') != -1)) {
        print "=logs,clear command test $SIX_TABS Passed\r\n\r\n";
        print $csvFileHandle "logs clear Test,Passed\r\n";
        print $testFileHandle "=logs,clear Test Passed $result\r\n";
    } else {
        print "=logs,clear command test $SIX_TABS Failed\r\n";
        print $csvFileHandle "logs clear Test,Failed\r\n";
        print $testFileHandle "=logs,clear Test Failed $result\r\n";
    }

}  # end of TestClearLogs

############################################################################
#  TestGetMsync
#
#  Description: Test the Get MSYNC Value command ?msync
#
#       Inputs: $portTest         - comport device is on
#               $logTestResults   - Whether to log the test result or not
#               $csvFileHandle    - file handle to write csv test results
#               $testFileHandle    - file handle to write txt test results
#
#      Returns: Success or Failure - 0 or 1
#
# Side Effects: None
#
#        Notes: None
#
############################################################################
sub TestGetMsync
{
    my $portTest = shift;
    my $logTestResults = shift;
    my $csvFileHandle  = shift;
    my $testFileHandle  = shift;


    #for (my $indexCount = 0; $indexCount < 2; $indexCount++) {
    #    SendConfigCommand($portTest,"1",0,$csvFileHandle,$testFileHandle);
    #}

    my $command = "?msync";
    $portTest->write($command."\n");

    select(undef, undef, undef, 0.75);  # sleep 1/4 second 250 milliseconds
    my $result = $portTest->input;

    if ($logTestResults == 1) {
        #print "Msync result = $result";

        # remove the carriage return line feed;
        $result =~ s/\r|\n//g;

        # check if the MSYNC keyword is there. We don't check the value here
        # but we will dump the value in the test
        if ((index($result,'MSYNC') != -1)) {
            print "?msync command test $result $SIX_TABS Passed\r\n\r\n";
            print $csvFileHandle "?msync Test,Passed\r\n";
            print $testFileHandle "?msync Test Passed $result\r\n";
        } else {
            print "?msync command test $result $SIX_TABS Failed\r\n";
            print $csvFileHandle "?msync Test,Failed,\r\n";
            print $testFileHandle "?msync Test Failed $result\r\n";
        }
    } # end of if ($logTestResults == 1)

}  # end of TestGetMsync

############################################################################
#  TestSetMsync
#
#  Description: Test the Set MSYNC Value Commands =msync,ext =msync,imu
#
#       Inputs: $portTest         - comport device is on
#               $logTestResults   - Whether to log the test result or not
#               $csvFileHandle    - file handle to write csv test results
#               $testFileHandle    - file handle to write txt test results
#
#      Returns: Success or Failure - 0 or 1
#
# Side Effects: None
#
#        Notes: None
#
############################################################################
sub TestSetMsync
{
    my $portTest = shift;
    my $logTestResults = shift;
    my $csvFileHandle  = shift;
    my $testFileHandle  = shift;


    #for (my $indexCount = 0; $indexCount < 2; $indexCount++) {
    #    SendConfigCommand($portTest,"1",0,$csvFileHandle,$testFileHandle);
    #}

    my $command = "=msync,ext";
    $portTest->write($command."\n");

    select(undef, undef, undef, 0.75);  # sleep 1/4 second 250 milliseconds
    my $result = $portTest->input;

    if ($logTestResults == 1) {
        #print "Msync result = $result";

        # remove the carriage return line feed;
        $result =~ s/\r|\n//g;

        # check if the MSYNC keyword and value is valid
        #we will dump the value in the test
        if ((index($result,'MSYNC,EXT') != -1)) {
            print "=msync,ext command test $result $SIX_TABS Passed\r\n\r\n";
            print $csvFileHandle "msyncext Test,Passed\r\n";
            print $testFileHandle "=msync,ext Test Passed $result\r\n";
        } else {
            print "msync,ext command test $result $SIX_TABS Failed\r\n";
            print $csvFileHandle "msyncext Test,Failed,\r\n";
            print $testFileHandle "=msync,ext Test Failed $result\r\n";
        }
    } # end of if ($logTestResults == 1)

    $command = "=msync,imu";
    $portTest->write($command."\n");

    select(undef, undef, undef, 0.75);  # sleep 1/4 second 250 milliseconds
    $result = $portTest->input;

    if ($logTestResults == 1) {
        #print "Msync result = $result";

        # remove the carriage return line feed;
        $result =~ s/\r|\n//g;

        # check if the MSYNC keyword and value is valid
        #we will dump the value in the test
        if ((index($result,'MSYNC,IMU') != -1)) {
            print "=msync,imu command test $result $SIX_TABS Passed\r\n\r\n";
            print $csvFileHandle "msync Imu Test,Passed\r\n";
            print $testFileHandle "=msync,imu Test, Passed, $result\r\n";
        } else {
            print "=msync,imu command test $result $SIX_TABS Failed\r\n";
            print $csvFileHandle "msyncimu Test,Failed,\r\n";
            print $testFileHandle "=msync,imu Test Failed $result\r\n";
        }
    } # end of if ($logTestResults == 1)


}  # end of TestSetMsync

############################################################################
#  TestGetSysConfig
#
#  Description: Test the Get System Configuration Command ?sysconfig
#
#       Inputs: $portTest         - comport device is on
#               $logTestResults   - Whether to log the test result or not
#               $csvFileHandle    - file handle to write csv test results
#               $testFileHandle    - file handle to write txt test results
#
#      Returns: Success or Failure - 0 or 1
#
# Side Effects: None
#
#        Notes: None
#
############################################################################
sub TestGetSysConfig
{
    my $portTest = shift;
    my $logTestResults = shift;
    my $csvFileHandle  = shift;
    my $testFileHandle  = shift;


    #for (my $indexCount = 0; $indexCount < 2; $indexCount++) {
    #    SendConfigCommand($portTest,"1",0,$csvFileHandle,$testFileHandle);
    #}

    my $command = "?sysconfig";
    $portTest->write($command."\n");

    select(undef, undef, undef, 0.75);  # sleep 1/4 second 250 milliseconds
    my $result = $portTest->input;

    if ($logTestResults == 1) {
        #print "sysconfig result = $result";

        # remove the carriage return line feed;
        $result =~ s/\r|\n//g;

        # check if the SYSCONFIG keyword is there. We don't check the value here
        # but we will dump the value in the test
        if ((index($result,'SYSCONFIG') != -1)) {
            print "?sysconfig command test $result $SIX_TABS Passed\r\n\r\n";
            print $csvFileHandle "?sysconfig Test,Passed\r\n";
            print $testFileHandle "?sysconfig Test Passed $result\r\n";
        } else {
            print "?sysconfig command test $result $SIX_TABS Failed\r\n";
            print $csvFileHandle "?sysconfig Test,Failed,\r\n";
            print $testFileHandle "?sysconfig Test Failed $result\r\n";
        }
    } # end of if ($logTestResults == 1)

}  # end of TestGetSysConfig

############################################################################
#  TestSetSysConfig
#
#  Description: Test the Set System Configuration Command =sysconfig
#
#       Inputs: $portTest         - comport device is on
#               $logTestResults   - Whether to log the test result or not
#               $deviceName	  - Device type being tested
#               $csvFileHandle    - file handle to write csv test results
#               $testFileHandle    - file handle to write txt test results
#
#      Returns: Success or Failure - 0 or 1
#
# Side Effects: None
#
#        Notes: None
#
############################################################################
sub TestSetSysConfig
{
    my $portTest = shift;
    my $logTestResults = shift;
    my $deviceName = shift;
    my $csvFileHandle  = shift;
    my $testFileHandle  = shift;
    my $result = "";
    my $command = "";

    print "Device Type = $deviceName\r\n";
    $command = "=sysconfig,1725imu";
    $portTest->write($command."\n");
    select(undef, undef, undef, 1.50);  # sleep 1.5 seconds
    $result = $portTest->input;
    print "=sysconfig,1725imu command test $result\r\n\r\n";

    if ($logTestResults == 1) {
        #print "=sysconfig result = $result";

        # check if the SYSCONFIG keyword and value is valid
        #we will dump the value in the test
        $command = "?sysconfig";
        $portTest->write($command."\n");
        select(undef, undef, undef, 0.50);  # sleep 1.5 seconds
        $result = $portTest->input;
        # remove the carriage return line feed;
        $result =~ s/\r|\n//g;
        if ((index($result,'SYSCONFIG,1725IMU') != -1)) {

            print "=sysconfig,1725imu command test $result $SIX_TABS Passed\r\n\r\n";
            print $csvFileHandle "sysconfig1725imu Test,Passed\r\n";
            print $testFileHandle "=sysconfig,1725imu Test Passed $result\r\n";
        } else {
            print "=sysconfig,1725imu command test $result $SIX_TABS Failed\r\n";
            print $csvFileHandle "sysconfig1725imu Test,Failed,\r\n";
            print $testFileHandle "=sysconfig,1725imu Test Failed $result\r\n";
        }
    } # end of if ($logTestResults == 1)

    $command = "=sysconfig,1750imu";
    $portTest->write($command."\n");
    select(undef, undef, undef, 1.50);  # sleep 1.5 seconds
    $result = $portTest->input;
    print "=sysconfig,1750imu command test $result\r\n\r\n";

    if ($logTestResults == 1) {
        #print "=sysconfig result = $result";

        # check if the SYSCONFIG keyword and value is valid
        #we will dump the value in the test
        $command = "?sysconfig";
        $portTest->write($command."\n");
        select(undef, undef, undef, 0.50);  # sleep 1.5 seconds
        $result = $portTest->input;
        # remove the carriage return line feed;
        $result =~ s/\r|\n//g;
        if ((index($result,'SYSCONFIG,1750IMU') != -1)) {
            print "=sysconfig,1750imu command test $result $SIX_TABS Passed\r\n\r\n";
            print $csvFileHandle "sysconfig1750imu Test,Passed\r\n";
            print $testFileHandle "=sysconfig,1750imu Test Passed $result\r\n";
        } else {
            print "=sysconfig,1750imu command test $result $SIX_TABS Failed\r\n";
            print $csvFileHandle "sysconfig1750imu Test,Failed,\r\n";
            print $testFileHandle "=sysconfig,1750imu Test Failed $result\r\n";
        }
    } # end of if ($logTestResults == 1)

    $command = "=sysconfig,1760dsp1";
    $portTest->write($command."\n");
    select(undef, undef, undef, 1.50);  # sleep 1.5 seconds
    $result = $portTest->input;
    print "=sysconfig,1760dsp1 command test $result\r\n\r\n";

    if ($logTestResults == 1) {
        #print "=sysconfig result = $result";

        # check if the SYSCONFIG keyword and value is valid
        #we will dump the value in the test
        $command = "?sysconfig";
        $portTest->write($command."\n");
        select(undef, undef, undef, 0.50);  # sleep 1.5 seconds
        $result = $portTest->input;
        # remove the carriage return line feed;
        $result =~ s/\r|\n//g;
        if ((index($result,'SYSCONFIG,1760DSP1') != -1)) {
            print "=sysconfig,1760dsp1 command test $result $SIX_TABS Passed\r\n\r\n";
            print $csvFileHandle "sysconfig1760dsp1 Test,Passed\r\n";
            print $testFileHandle "=sysconfig,1760dsp1 Test Passed $result\r\n";
        } else {
            print "=sysconfig,1760dsp1 command test $result $SIX_TABS Failed\r\n";
            print $csvFileHandle "sysconfig1760dsp1 Test,Failed,\r\n";
            print $testFileHandle "=sysconfig,1760dsp1 Test Failed $result\r\n";
        }
    } # end of if ($logTestResults == 1)

    $command = "=sysconfig,1760dsp2";
    $portTest->write($command."\n");
    select(undef, undef, undef, 1.50);  # sleep 1.5 seconds
    $result = $portTest->input;
    print "=sysconfig,1760dsp2 command test $result\r\n\r\n";
	
    if ($logTestResults == 1) {
        #print "=sysconfig result = $result";

        # check if the SYSCONFIG keyword and value is valid
        #we will dump the value in the test
        $command = "?sysconfig";
        $portTest->write($command."\n");
        select(undef, undef, undef, 0.50);  # sleep 1.5 seconds
        $result = $portTest->input;
        # remove the carriage return line feed;
        $result =~ s/\r|\n//g;
        if ((index($result,'SYSCONFIG,1760DSP2') != -1)) {
            print "=sysconfig,1760dsp2 command test $result $SIX_TABS Passed\r\n\r\n";
            print $csvFileHandle "sysconfig1760dsp2 Test,Passed\r\n";
            print $testFileHandle "=sysconfig,1760dsp2 Test Passed $result\r\n";
        } else {
            print "=sysconfig,1760dsp2 command test $result $SIX_TABS Failed\r\n";
            print $csvFileHandle "sysconfig1760dsp2 Test,Failed,\r\n";
            print $testFileHandle "=sysconfig,1760dsp2 Test Failed $result\r\n";

        }
    } # end of if ($logTestResults == 1)

    $command = "=sysconfig,1760dsp3";
    $portTest->write($command."\n");
    select(undef, undef, undef, 1.50);  # sleep 1.5 seconds
    $result = $portTest->input;
    print "=sysconfig,1760dsp3 command test $result\r\n\r\n";

    if ($logTestResults == 1) {
        #print "=sysconfig result = $result";
        # check if the SYSCONFIG keyword and value is valid
        #we will dump the value in the test
        $command = "?sysconfig";
        $portTest->write($command."\n");
        select(undef, undef, undef, 0.50);  # sleep 1.5 seconds
        $result = $portTest->input;
        # remove the carriage return line feed;
        $result =~ s/\r|\n//g;
        if ((index($result,'SYSCONFIG,1760DSP3') != -1)) {
            print "=sysconfig,1760dsp3 command test $result $SIX_TABS Passed\r\n\r\n";
            print $csvFileHandle "sysconfig1760dsp3 Test,Passed\r\n";
            print $testFileHandle "=sysconfig,1760dsp3 Test Passed $result\r\n";
        } else {
            print "=sysconfig,1760dsp3 command test $result $SIX_TABS Failed\r\n";
            print $csvFileHandle "sysconfig1760dsp3 Test,Failed\r\n";
            print $testFileHandle "=sysconfig,1760dsp3 Test Failed $result\r\n";
        }
    } # end of if ($logTestResults == 1)

        
    $command = "=sysconfig,1775imu";
    $portTest->write($command."\n");
    select(undef, undef, undef, 1.50);  # sleep 1.5 seconds
    $result = $portTest->input;
    print "=sysconfig,1775imu command test $result\r\n\r\n";

    if ($logTestResults == 1) {
        #print "=sysconfig result = $result";
        # check if the SYSCONFIG keyword and value is valid
        #we will dump the value in the test
        $command = "?sysconfig";
        $portTest->write($command."\n");
        select(undef, undef, undef, 1.00);  # sleep 1.5 seconds
        $result = $portTest->input;
        # remove the carriage return line feed;
        $result =~ s/\r|\n//g;
        if ((index($result,'SYSCONFIG,1775IMU') != -1)) {

            print "=sysconfig,1775imu command test $result $SIX_TABS Passed\r\n\r\n";
            print $csvFileHandle "sysconfig1775imu Test,Passed\r\n";
            print $testFileHandle "=sysconfig,1775imu Test, Passed $result\r\n";
        } else {
            print "=sysconfig,1775imu command test $result $SIX_TABS Failed\r\n";
            print $csvFileHandle "sysconfig1775imu Test,Failed\r\n";
            print $testFileHandle "=sysconfig,1775imu Test Failed $result\r\n";
        }
    } # end of if ($logTestResults == 1)

    $command = "=sysconfig,irs3axis";
    $portTest->write($command."\n");
    select(undef, undef, undef, 1.50);  # sleep 1.5 seconds
    $result = $portTest->input;
    print "=sysconfig,irs3axis command test $result\r\n\r\n";

    if ($logTestResults == 1) {
        #print "=sysconfig result = $result";
        # check if the SYSCONFIG keyword and value is valid
        #we will dump the value in the test
        $command = "?sysconfig";
        $portTest->write($command."\n");
        select(undef, undef, undef, 1.00);  # sleep 1.5 seconds
        $result = $portTest->input;
        # remove the carriage return line feed;
        $result =~ s/\r|\n//g;
        if ((index($result,'SYSCONFIG,IRS3AXIS') != -1)) {
            print "=sysconfig,irs3axis command test $result $SIX_TABS Passed\r\n\r\n";
            print $csvFileHandle "sysconfigirs3axis Test,Passed\r\n";
            print $testFileHandle "=sysconfig,irs3axis Test Passed $result\r\n";
        } else {
            print "=sysconfig,irs3axis command test $result $SIX_TABS Failed\r\n";
            print $csvFileHandle "sysconfigirs3axis Test,Failed\r\n";
            print $testFileHandle "=sysconfig,irs3axis Test Failed $result\r\n";
        }
    } # end of if ($logTestResults == 1)
    $command = "=sysconfig,1725imu";
    $portTest->write($command."\n");
    select(undef, undef, undef, 1.50);  # sleep 1.5 seconds
    $result = $portTest->input;
    print "=sysconfig,1725imu command test $result\r\n\r\n";

    if ($logTestResults == 1) {
        #print "=sysconfig result = $result";
        # check if the SYSCONFIG keyword and value is valid
        #we will dump the value in the test
        $command = "?sysconfig";
        $portTest->write($command."\n");
        select(undef, undef, undef, 1.50);  # sleep 1.5 seconds
        $result = $portTest->input;
        # remove the carriage return line feed;
        $result =~ s/\r|\n//g;
        if ((index($result,'SYSCONFIG,1725IMU') != -1)) {

            print "=sysconfig,1725imu command test $result $SIX_TABS Passed\r\n\r\n";
            print $csvFileHandle "sysconfig1725imu Test,Passed\r\n";
            print $testFileHandle "=sysconfig,1725imu Test Passed $result\r\n";
        } else {
            print "=sysconfig,1725imu command test $result $SIX_TABS Failed\r\n";
            print $csvFileHandle "sysconfig1725imu Test,Failed\r\n";
            print $testFileHandle "=sysconfig,1725imu Test Failed $result\r\n";
        }
    } # end of if ($logTestResults == 1)

    $command = "=sysconfig,1750imu";
    $portTest->write($command."\n");
    select(undef, undef, undef, 1.50);  # sleep 1.5 seconds
    $result = $portTest->input;
    print "=sysconfig,1750imu command test $result\r\n\r\n";

    if ($logTestResults == 1) {
        #print "=sysconfig result = $result";
        # check if the SYSCONFIG keyword and value is valid
        #we will dump the value in the test
        $command = "?sysconfig";
        $portTest->write($command."\n");
        select(undef, undef, undef, 0.50);  # sleep 0.5 seconds
        $result = $portTest->input;
        # remove the carriage return line feed;
        $result =~ s/\r|\n//g;
        if ((index($result,'SYSCONFIG,1750IMU') != -1)) {
            print "=sysconfig,1750imu command test $result $SIX_TABS Passed\r\n\r\n";
            print $csvFileHandle "sysconfig1750imu Test,Passed\r\n";
            print $testFileHandle "=sysconfig,1750imu Test Passed $result\r\n";
        } else {
            print "=sysconfig,1750imu command test $result $SIX_TABS Failed\r\n";
            print $csvFileHandle "sysconfig1750imu Test,Failed\r\n";
            print $testFileHandle "=sysconfig,1750imu Test Failed $result\r\n";
        }
    } # end of if ($logTestResults == 1)

    $command = "=sysconfig,1760dsp1";
    $portTest->write($command."\n");
    select(undef, undef, undef, 1.50);  # sleep 1.5 seconds
    $result = $portTest->input;
    print "=sysconfig,1760dsp1 command test $result\r\n\r\n";

    if ($logTestResults == 1) {
        #print "=sysconfig result = $result";
        # check if the SYSCONFIG keyword and value is valid
        #we will dump the value in the test
        $command = "?sysconfig";
        $portTest->write($command."\n");
        select(undef, undef, undef, 0.50);  # sleep 0.5 seconds
        $result = $portTest->input;
        # remove the carriage return line feed;
        $result =~ s/\r|\n//g;
        if ((index($result,'SYSCONFIG,1760DSP1') != -1)) {
            print "=sysconfig,1760dsp1 command test $result $SIX_TABS Passed\r\n\r\n";
            print $csvFileHandle "sysconfig1760dsp1 Test,Passed\r\n";
            print $testFileHandle "=sysconfig,1760dsp1 Test Passed $result\r\n";
        } else {
            print "=sysconfig,1760dsp1 command test $result $SIX_TABS Failed\r\n";
            print $csvFileHandle "sysconfig1760dsp1 Test,Failed,\r\n";
            print $testFileHandle "=sysconfig,1760dsp1 Test Failed $result\r\n";
        }
    } # end of if ($logTestResults == 1)

    $command = "=sysconfig,1760dsp2";
    $portTest->write($command."\n");
    select(undef, undef, undef, 1.50);  # sleep 1.5 seconds
    $result = $portTest->input;
    print "=sysconfig,1760dsp2 command test $result\r\n\r\n";

    if ($logTestResults == 1) {
        #print "=sysconfig result = $result";
        # check if the SYSCONFIG keyword and value is valid
        #we will dump the value in the test
        $command = "?sysconfig";
        $portTest->write($command."\n");
        select(undef, undef, undef, 0.50);  # sleep 0.5 seconds
        $result = $portTest->input;
        # remove the carriage return line feed;
        $result =~ s/\r|\n//g;
        if ((index($result,'SYSCONFIG,1760DSP2') != -1)) {
            print "=sysconfig,1760dsp2 command test $result $SIX_TABS Passed\r\n\r\n";
            print $csvFileHandle "sysconfig1760dsp2 Test,Passed\r\n";
            print $testFileHandle "=sysconfig,1760dsp2 Test Passed $result\r\n";
        } else {
            print "=sysconfig,1760dsp2 command test $result $SIX_TABS Failed\r\n";
            print $csvFileHandle "sysconfig1760dsp2 Test,Failed\r\n";
            print $testFileHandle "=sysconfig,1760dsp2 Command Test Failed $result\r\n";
        }
    } # end of if ($logTestResults == 1)

    $command = "=sysconfig,1760dsp3";
    $portTest->write($command."\n");
    select(undef, undef, undef, 1.50);  # sleep 1.5 seconds
    $result = $portTest->input;
    print "=sysconfig,1760dsp3 command test $result\r\n\r\n";

    if ($logTestResults == 1) {
        #print "=sysconfig result = $result";

        # check if the SYSCONFIG keyword and value is valid
        #we will dump the value in the test
        $command = "?sysconfig";
        $portTest->write($command."\n");
        select(undef, undef, undef, 0.50);  # sleep 0.5 seconds
        $result = $portTest->input;
        # remove the carriage return line feed;
        $result =~ s/\r|\n//g;
        if ((index($result,'SYSCONFIG,1760DSP3') != -1)) {
            print "=sysconfig,1760dsp3 command test $result $SIX_TABS Passed\r\n\r\n";
            print $csvFileHandle "sysconfig1760dsp3 Test,Passed\r\n";
            print $testFileHandle "=sysconfig,1760dsp3 Test Passed $result\r\n";
        } else {
            print "=sysconfig,1760dsp3 command test $result $SIX_TABS Failed\r\n";
            print $csvFileHandle "sysconfig1760dsp3 Test,Failed,\r\n";
            print $testFileHandle "=sysconfig,1760dsp3 Test Failed $result\r\n";
        }
    } # end of if ($logTestResults == 1)
    
    $command = "=sysconfig,1760DSPU1";
    $portTest->write($command."\n");
    select(undef, undef, undef, 1.50);  # sleep 1.5 seconds
    $result = $portTest->input;
    print "=sysconfig,1760DSPU1 command test $result\r\n\r\n";

    if ($logTestResults == 1) {
        #print "=sysconfig result = $result";
        # check if the SYSCONFIG keyword and value is valid
        #we will dump the value in the test
        $command = "?sysconfig";
        $portTest->write($command."\n");
        select(undef, undef, undef, 0.50);  # sleep 0.5 seconds
        $result = $portTest->input;
        # remove the carriage return line feed;
        $result =~ s/\r|\n//g;
        if ((index($result,'SYSCONFIG,1760DSPU1') != -1)) {
            print "=sysconfig,1760DSPU1 command test $result $SIX_TABS Passed\r\n\r\n";
            print $csvFileHandle "sysconfig 1760DSPU1 Test,Passed\r\n";
            print $testFileHandle "=sysconfig,1760DSPU1 Test Passed $result\r\n";
        } else {
            print "=sysconfig,1760DSPU1 command test $result $SIX_TABS Failed\r\n";
            print $csvFileHandle "sysconfig 1760DSPU1 Test,Failed,\r\n";
            print $testFileHandle "=sysconfig,1760DSPU1 Test Failed $result\r\n";
        }
    } # end of if ($logTestResults == 1)

    $command = "=sysconfig,1760DSPU2";
    $portTest->write($command."\n");
    select(undef, undef, undef, 1.50);  # sleep 1.5 seconds
    $result = $portTest->input;
    print "=sysconfig,1760DSPU2 command test $result\r\n\r\n";
	
    if ($logTestResults == 1) {
        #print "=sysconfig result = $result";
        # check if the SYSCONFIG keyword and value is valid
        #we will dump the value in the test
        $command = "?sysconfig";
        $portTest->write($command."\n");
        select(undef, undef, undef, 0.50);  # sleep 0.5 seconds
        $result = $portTest->input;
        # remove the carriage return line feed;
        $result =~ s/\r|\n//g;
        if ((index($result,'SYSCONFIG,1760DSPU2') != -1)) {
            print "=sysconfig,1760DSPU2 command test $result $SIX_TABS Passed\r\n\r\n";
            print $csvFileHandle "sysconfig 1760DSPU2 Test,Passed\r\n";
            print $testFileHandle "=sysconfig,1760DSPU2 Test Passed $result\r\n";
        } else {
            print "=sysconfig,1760DSPU2 command test $result $SIX_TABS Failed\r\n";
            print $csvFileHandle "sysconfig 1760DSPU2 Test,Failed\r\n";
            print $testFileHandle "=sysconfig,1760DSPU2 Command Test Failed $result\r\n";
        }
    } # end of if ($logTestResults == 1)

    $command = "=sysconfig,1760DSPU3";
    $portTest->write($command."\n");
    select(undef, undef, undef, 1.50);  # sleep 1.5 seconds
    $result = $portTest->input;
    print "=sysconfig,1760DSPU3 command test $result\r\n\r\n";

    if ($logTestResults == 1) {
        #print "=sysconfig result = $result";
        # check if the SYSCONFIG keyword and value is valid
        #we will dump the value in the test
        $command = "?sysconfig";
        $portTest->write($command."\n");
        select(undef, undef, undef, 0.50);  # sleep 0.5 seconds
        $result = $portTest->input;
        # remove the carriage return line feed;
        $result =~ s/\r|\n//g;
        if ((index($result,'SYSCONFIG,1760DSPU3') != -1)) {
            print "=sysconfig,1760DSPU3 command test $result $SIX_TABS Passed\r\n\r\n";
            print $csvFileHandle "sysconfig 1760DSPU3 Test,Passed\r\n";
            print $testFileHandle "=sysconfig,1760DSPU3 Test Passed $result\r\n";
        } else {
            print "=sysconfig,1760DSPU3 command test $result $SIX_TABS Failed\r\n";
            print $csvFileHandle "sysconfig 1760DSPU3 Test,Failed,\r\n";
            print $testFileHandle "=sysconfig,1760DSPU3 Test Failed $result\r\n";
        }
    } # end of if ($logTestResults == 1)
    $command = "=sysconfig,$deviceName";
    $portTest->write($command."\n");
    select(undef, undef, undef, 1.50);  # sleep 1.5 seconds
    $portTest->write($command."\n");
    select(undef, undef, undef, 0.50);  # sleep 0.5 seconds
    $result = $portTest->input;
    # remove the carriage return line feed;
    $result =~ s/\r|\n//g;

    if ((index($result,"SYSCONFIG,$deviceName") != -1)) {
            print "sysconfig returned to original setting $deviceName\r\n\r\n";
            print $testFileHandle "sysconfig returned to original setting, $deviceName\r\n";
    }
    sleep 1;

}  # end of TestSetSysConfig

######################## Individual Commands Below ###################################

############################################################################
#  RestartCommand
#
#  Description: Restart the system
#
#       Inputs: $portTest         - comport device is on         #
#
#
#      Returns: Success or Failure - 0 or 1
#
# Side Effects: None
#
#        Notes: None
#
############################################################################
sub RestartCommand
{
    my $portTest      = shift;

    my $command = "=restart,hard";
    $portTest->write($command."\n");

} # end of RestartCommand

############################################################################
#  TestOutputFormatCommand
#
#  Description: Test the Set Output Format Command =output,X
#				where X = A or B or C
#
#       Inputs: $portTest         - comport device is on
#               $outFormat        - the output format to set - A,B,C
#               $csvFileHandle    - file handle to write csv test results
#               $testFileHandle    - file handle to write txt test results
#
#      Returns: Success or Failure - 0 or 1
#
# Side Effects: None
#
#        Notes: None
#
############################################################################
sub TestOutputFormatCommand
{
    my $portTest       = shift;
    my $outFormat      = shift;
    my $csvFileHandle  = shift;
    my $testFileHandle  = shift;
    my $logTestResults = shift;

    my $command = "=outputfmt,$outFormat";
    $portTest->write($command."\n");

    select(undef, undef, undef, 0.75);
    my $result = $portTest->input;

    if ($logTestResults == 1) {
        print "outputfmt result = $result";

        if( $result eq "OUTPUTFMT,$outFormat\r\n" ) {
            print "=outputfmt,$outFormat Test \t\t\t\tPassed\r\n\r\n";
            print $csvFileHandle "outputfmt $outFormat Test,Passed\r\n";
            print $testFileHandle "=outputfmt,$outFormat Test Passed $result\r\n";
        } else {
            print "=outputfmt,$outFormat Test \t\t\t\tFailed\r\n";
            print $csvFileHandle "outputfmt $outFormat Test,Failed\r\n";
            print $testFileHandle "=outputfmt,$outFormat Test Failed $result\r\n";
        }
    } # end of if ($logTestResults == 1)

} # end of TestOutputFormatCommand



############################################################################
#  TestOutputFormatGetCommand
#
#  Description: Test the Get Output Format command ?outputfmt
#
#       Inputs: $portTest         - comport device is on
#               $csvFileHandle    - file handle to write csv test results
#               $testFileHandle   - file handle to write txt test results
#               $outputFormat     - expected Output Format
#
#      Returns: Success or Failure - 0 or 1
#
# Side Effects: None
#
#        Notes: None
#
############################################################################
sub TestOutputFormatGetCommand
{
    my $portTest       = shift;
    my $csvFileHandle  = shift;
    my $testFileHandle = shift;
    my $outputFormat   = shift;

    my $testSuccess = $SUCCESS;

    my $command = "?outputfmt";
    $portTest->write($command."\n");

    select(undef, undef, undef, 0.75);
    my $result = $portTest->input;

    print "TestOutputFormatGetCommand command = $command\r\n";
    print "TestOutputFormatGetCommand result = $result\r\n";

    if( $result eq "OUTPUTFMT,$outputFormat\r\n" ) {
        print "?outputfmt Test \t\t\t\tPassed\r\n\r\n";
        print $csvFileHandle "?outputfmt Test,Passed\r\n";
        print $testFileHandle "?outputfmt Test Passed $result\r\n";
    } else {
        print "TestOutputFormatGetCommand test \t\t\t\tFailed\r\n";
        print $csvFileHandle "?outputfmt Test,Failed\r\n";
        print $testFileHandle "?outputfmt Test Failed $result\r\n";
        $testSuccess = $FAILED;
    }

    return $testSuccess;

} # end of TestOutputFormatGetCommand



############################################################################
#  TestStartupModeGetCommand
#
#  Description: Test the Get Startup Mode command ?startup
#
#       Inputs: $portTest         - comport device is on
#               $csvFileHandle    - file handle to write csv test results
#               $testFileHandle   - file handle to write txt test results
#               $startupMode      - expected startup mode
#
#      Returns: Success or Failure - 0 or 1
#
# Side Effects: None
#
#        Notes: None
#
############################################################################
sub TestStartupModeGetCommand
{
    my $portTest       = shift;
    my $csvFileHandle  = shift;
    my $testFileHandle = shift;
    my $startupMode    = shift;

    my $testSuccess = $SUCCESS;

    my $command = "?startup";
    $portTest->write($command."\n");

    select(undef, undef, undef, 0.75);
    my $result = $portTest->input;

    print "TestStartupModeGetCommand command = $command\r\n";
    print "TestStartupModeGetCommand result = $result\r\n";

    if( $result eq "STARTUP,$startupMode\r\n" ) {
        print "?startup Test \t\t\t\tPassed\r\n\r\n";
        print $csvFileHandle "?startup Test,Passed\r\n";
        print $testFileHandle "?startup Test Passed $result\r\n";
    } else {
        print "?startup Test \t\t\t\tFailed\r\n";
        print $csvFileHandle "?startup Test,Failed\r\n";
        print $testFileHandle "?startup Test Failed $result\r\n";
        $testSuccess = $FAILED;
    }

    return $testSuccess;

} # end of TestStartupModeGetCommand


############################################################################
#  TestCfgRstCommand
#
#  Description: Test the Configuration Rest Command =rstcfg
#
#       Inputs: $portTest         - comport device is on
#               $csvFileHandle    - file handle to write csv test results
#               $testFileHandle    - file handle to write txt test results
#
#      Returns: Success or Failure - 0 or 1
#
# Side Effects: None
#
#        Notes: None
#
############################################################################
sub TestCfgRstCommand
{
    my $portTest      = shift;
    my $csvFileHandle = shift;
    my $testFileHandle = shift;

    my $testSuccess = $SUCCESS;

    my $command = "=rstcfg";
    $portTest->write($command."\n");

    select(undef, undef, undef, 2.0);  # sleep 1/2 second 500 milliseconds

    #sleep 2;
    my $result = $portTest->input;
    print "rstcfg result = $result";

    if( $result eq "RSTCFG\r\n" ) {
        print "=rstcfg Test \t\t\t\tPassed\r\n\r\n";
        print $csvFileHandle "rstcfg Test,Passed\r\n";
        print $testFileHandle "=rstcfg Test Passed $result\r\n";

        $testSuccess = $SUCCESS;
    } else {
        print "=rstcfg Test \t\t\t\tFailed\r\n";
        print $csvFileHandle "rstcfg Test,Failed\r\n";
        print $testFileHandle "=rstcfg Test Failed $result\r\n";
        $testSuccess = $FAILED;
    }

    return $testSuccess;
} # end of TestCfgRstCommand

############################################################################
#  TestFilterEnableSet
#
#  Description: Test the Filter Enable Set Command =filten,X X = on or off
#
#       Inputs: $portTest         - comport device is on
#               $csvFileHandle    - file handle to write csv test results
#               $testFileHandle    - file handle to write txt test results
#
#      Returns: Success or Failure - 0 or 1
#
# Side Effects: None
#
#        Notes: None
#
############################################################################
sub TestFilterEnableSet
{
    my $portTest      = shift;
    my $csvFileHandle = shift;
    my $testFileHandle = shift;
	my $realValue;

    #Get the current value
	my $commandStatus = "?filten";
	$port->write($commandStatus."\n");
    select(undef, undef, undef, 0.25);  # sleep 1/4 second 250 milliseconds
	my $result = $portTest->input;
	$realValue = $result;
	#set the configuration
	if ($result eq "FILTEN,1\r\n") {
		$commandStatus = "=filten,0";
		print "command = $commandStatus\r\n";
		print $testFileHandle "command = $commandStatus\r\n";
		$port->write($commandStatus."\n");
		select(undef, undef, undef, 0.25);  # sleep 1/4 second 250 milliseconds
		$result = $portTest->input;

		if( $result eq "FILTEN,0\r\n" ) {
			print "=filten Test \t\t\tPassed\r\n\r\n";
			print $csvFileHandle "filten Test,Passed\r\n";
			print $testFileHandle "=filten Test Passed $result\r\n";
			#return 1;
		}
		else {
			print "=filten test \t\t\tFailed\r\n";
			print $csvFileHandle "filten Test,Failed\r\n";
			print $testFileHandle "=filten Test Failed $result\r\n";
			#return 0;
		}
	}
	else {
		$commandStatus = "=filten,1";
		print "command = $commandStatus\r\n";
		print $testFileHandle "command = $commandStatus\r\n";
	    $port->write($commandStatus."\n");
		select(undef, undef, undef, 0.25);  # sleep 1/4 second 250 milliseconds
		$result = $portTest->input;

		if( $result eq "FILTEN,1\r\n" ) {
			print "=filten Test \t\t\tPassed\r\n\r\n";
			print $csvFileHandle "filten Test,Passed\r\n";
			print $testFileHandle "=filten Test Passed $result\r\n";
			#return 1;
		} else {
			print "filten Test \t\t\tFailed\r\n";
			print $csvFileHandle "filten Test,Failed\r\n";
			print $testFileHandle "=filten Test Failed $result\r\n";
			#return 0;
		}
    }
	# Negative Test with invalid value
	$commandStatus = "=filten,2";
	print "command = $commandStatus\r\n";
	print $testFileHandle "command = $commandStatus\r\n";
	$port->write($commandStatus."\n");
	select(undef, undef, undef, 0.25);  # sleep 1/4 second 250 milliseconds
	$result = $portTest->input;

	if( $result eq "USAGE: =FILTEN,<0|1>\r\n" ) {
		print "=filten Negative Test \t\t\tPassed\r\n\r\n";
		print $csvFileHandle "filten Negative Test,Passed\r\n";
		print $testFileHandle "=filten Neg Test Passed $result\r\n";
		#return 1;
	} else {
		print "filten set test \t\t\tFailed\r\n";
		print $csvFileHandle "filten$dataValue Test,Failed\r\n";
		print $testFileHandle "=filten$dataValue Test Failed $result\r\n";
		#return 0;
	}
	#Return Filten setting to original
	$commandStatus = "=$realValue";
	$port->write($commandStatus."\n");
	select(undef, undef, undef, 0.25);  # sleep 1/4 second 250 milliseconds
	$result = $portTest->input;
	print "filten value returned to original value $result\r\n";
	print $testFileHandle "filten value returned to original value $result\r\n";
} # end of TestFilterEnableSet

############################################################################
#  TestFilterEnableGet
#
#  Description: Test the Filter Enable Get Command ?filten
#
#       Inputs: $portTest         - comport device is on
#               $dataValue        - The temp units to get
#               $csvFileHandle    - file handle to write csv test results
#               $testFileHandle    - file handle to write txt test results
#
#      Returns: Success or Failure - 0 or 1
#
# Side Effects: None
#
#        Notes: None
#
###########################################################################
sub TestFilterEnableGet
{
    my $portTest      = shift;
    my $dataValue     = shift;
    my $csvFileHandle = shift;
    my $testFileHandle = shift;
	my $commandStatus = "?filten";
    $portTest->write($commandStatus."\n");
    select(undef, undef, undef, 0.25);  # sleep 1/4 second 250 milliseconds

    my $result = $portTest->input;
    print "?filten = $result";
    #print "filten type   = $dataValue\r\n";
    #print $testFileHandle "?filten = $result";
    #print $testFileHandle "filten type   = $dataValue\r\n";
	if ($dataValue ne 2) {
		if ( $result eq "FILTEN,$dataValue\r\n" ) {
			print "?filten Test \t\t\tPassed\r\n\r\n";
			print $csvFileHandle "?filten Test,Passed\r\n";
			print $testFileHandle "?filten Test Passed $result\r\n";
			return 1;
		} else {
			print "?filten Test \t\t\tFailed\r\n";
			print $csvFileHandle "?filten Test,Failed\r\n";
			print $testFileHandle "?filten Test Failed $result\r\n";
			return 0;
		}
    }
	else {
		if ((index($result,"FILTEN") != -1)) {
			print "?filten Test \t\t\tPassed\r\n\r\n";
			print $csvFileHandle "?filten Test,Passed\r\n";
			print $testFileHandle "?filten Test Passed $result\r\n";
			return 1;
		} else {
			print "?filten Test \t\t\tFailed\r\n";
			print $csvFileHandle "?filten Test,Failed\r\n";
			print $testFileHandle "?filten Test Failed $result\r\n";
			return 0;
		}
	}
} # end of TestFilterEnableGet
############################################################################
#  TestTempUnitsGet
#
#  Description: Get the Temperature Units
#
#       Inputs: $portTest         - comport device is on
#               $dataValue        - The temp units to get
#               $csvFileHandle    - file handle to write csv test results
#               $testFileHandle    - file handle to write txt test results
#
#      Returns: Success or Failure - 0 or 1
#
# Side Effects: None
#
#        Notes: None
#
############################################################################
sub TestTempUnitsGet
{
    my $portTest      = shift;
    my $dataValue     = shift;
    my $csvFileHandle = shift;
    my $testFileHandle = shift;

    my $testSuccess = $SUCCESS;

    my $commandStatus = "?tempunits";
    $portTest->write($commandStatus."\n");
    select(undef, undef, undef, 0.25);  # sleep 1/4 second 250 milliseconds

    my $result = $portTest->input;
    print "?tempunits = $result";
    #print "tempunits type   = $dataValue\r\n";
    #print $testFileHandle "?tempunits = $result";
    #print $testFileHandle "tempunits type   = $dataValue\r\n";

    if( $result eq "TEMPUNITS,$dataValue\r\n" ) {
        print "?tempunits Test \t\t\tPassed\r\n\r\n";
        print $csvFileHandle "?tempunits Test,Passed\r\n";
        print $testFileHandle "?tempunits Test Passed $result\r\n";
        my $testSuccess = $SUCCESS;
    } else {
        print "?tempunits Test \t\t\tFailed\r\n";
        print $csvFileHandle "?tempunits Test,Failed\r\n";
        print $testFileHandle "?tempunits Test Failed $result ,\r\n";
        $testSuccess = $FAILED;
    }

    return ($testSuccess, $result);

} # end of TestTempUnitsGet

############################################################################
#  TestTempUnitsSet
#
#  Description: Set the Temperature Units
#
#       Inputs: $portTest         - comport device is on
#               $dataValue        - The temp units to set
#               $csvFileHandle    - file handle to write csv test results
#               $testFileHandle    - file handle to write csv test results
#
#      Returns: Success or Failure - 0 or 1
#
# Side Effects: None
#
#        Notes: None
#
############################################################################
sub TestTempUnitsSet
{
    my $portTest      = shift;
    my $dataValue     = shift;
    my $csvFileHandle = shift;
    my $testFileHandle = shift;

    my $testSuccess = $SUCCESS;

    #set the configuration
    my $commandStatus = "=tempunits,$dataValue";
    $portTest->write($commandStatus."\n");
    select(undef, undef, undef, 0.25);  # sleep 1/4 second 250 milliseconds

    my $result = $portTest->input;
    print "=tempunits,$dataValue = $result";
    #print "tempunits type   = $dataValue\r\n";
    #print $testFileHandle "=tempunits,$dataValue = $result";
    #print $testFileHandle "tempunits type   = $dataValue\r\n";

    if( $result eq "TEMPUNITS,$dataValue\r\n" ) {
        print "=tempunits,$dataValue Test \t\t\tPassed\r\n\r\n";
        print $csvFileHandle "tempunits $dataValue Test,Passed\r\n";
        print $testFileHandle "=tempunits $dataValue Test Passed, $result\r\n";
        $testSuccess = $SUCCESS;
    } else {
        print "=tempunits,$dataValue Test \t\t\tFailed\r\n";
        print $csvFileHandle "tempunits $dataValue Test,Failed\r\n";
        print $testFileHandle "=tempunits $dataValue Test Failed, $result\r\n";
        $testSuccess = $FAILED;
    }

    return $testSuccess;

} # end of TestTempUnitsSet

############################################################################
#  TestTemperatureGet
#
#  Description: Get the Temperature
#
#       Inputs: $portTest         - comport device is on
#               $csvFileHandle    - file handle to write csv test results
#               $testFileHandle    - file handle to write txt test results
#
#      Returns: Success or Failure - 0 or 1
#
# Side Effects: None
#
#        Notes: None
#
############################################################################
sub TestTemperatureGet
{
    my $portTest      = shift;
    my $csvFileHandle = shift;
    my $testFileHandle = shift;

    my $commandStatus = "?temp";
    $portTest->write($commandStatus."\n");
    select(undef, undef, undef, 0.25);  # sleep 1/4 second 250 milliseconds

    my $result = $portTest->input;
    print "?temp = $result";
    #print $testFileHandle "?temp = $result";

    if( $result eq "TEMP,$dataValue\r\n" ) {
        print "?temp Test \t\t\tPassed\r\n\r\n";
        print $csvFileHandle "?temp Test,Passed\r\n";
        print $testFileHandle "?temp Test Passed $result\r\n";
        return 1;
    } else {
        print "?temp Test \t\t\tFailed\r\n";
        print $csvFileHandle "?temp Test,Failed\r\n";
        print $testFileHandle "?temp Test Failed $result\r\n";
        return 0;
    }
} # end of TestTemperatureGet

############################################################################
#  TestRotationUnitsGet
#
#  Description: Get the rotational units type
#
#       Inputs: $portTest         - comport device is on
#               $rotUnitsType     - rotational units type
#               $csvFileHandle    - file handle to write csv test results
#               $testFileHandle    - file handle to write txt test results
#
#      Returns: Success or Failure - 0 or 1
#
# Side Effects: None
#
#        Notes: None
#
############################################################################
sub TestRotationUnitsGet
{
    my $portTest      = shift;
    my $rotUnitsType  = shift;
    my $csvFileHandle = shift;
    my $testFileHandle = shift;

    my $commandStatus = "?rotunits";
    $portTest->write($commandStatus."\n");
    select(undef, undef, undef, 0.25);  # sleep 1/4 second 250 milliseconds

    my $result = $portTest->input;
    print "?rotunits = $result";
    #print "rotunit get type   = $rotUnitsType\r\n";
    #print $testFileHandle "?rotunits = $result";
    #print $testFileHandle "rotunit get type   = $rotUnitsType\r\n";

    if( $result eq "ROTUNITS,$rotUnitsType\r\n" ) {
        print "?rotunits Test \t\t\tPassed\r\n\r\n";
        print $csvFileHandle "?rotunits Test,Passed\r\n";
        print $testFileHandle "?rotunits Test Passed $result\r\n";
        return 1;
    } else {
        print "?rotunits Test \t\t\tFailed\r\n";
        print $csvFileHandle "?rotunits Test,Failed\r\n";
        print $testFileHandle "?rotunits Test Failed $result\r\n";
        return 0;
    }
} # end of TestRotationUnitsGet

############################################################################
#  TestRotationUnitsSet
#
#  Description: Set the rotational units type
#
#       Inputs: $portTest         - comport device is on
#               $rotUnitsType     - rotational units type
#               $csvFileHandle    - file handle to write csv test results
#               $csvFileHandle    - file handle to write csv test results
#
#      Returns: Success or Failure - 0 or 1
#
# Side Effects: None
#
#        Notes: None
#
############################################################################
sub TestRotationUnitsSet
{
    my $portTest      = shift;
    my $rotUnitsType  = shift;
    my $csvFileHandle = shift;
    my $testFileHandle = shift;

    #set the configuration
    my $commandStatus = "=rotunits,$rotUnitsType";
    $portTest->write($commandStatus."\n");
    select(undef, undef, undef, 0.25);  # sleep 1/4 second 250 milliseconds

    my $result = $portTest->input;
    print "=rotunits,$rotUnitsType = $result";
    #print "rotunit set type   = $rotUnitsType\r\n";
    #print $testFileHandle "=rotunits,$rotUnitsType = $result";
    #print $testFileHandle "rotunit set type   = $rotUnitsType\r\n";

    if( $result eq "ROTUNITS,$rotUnitsType\r\n" ) {
        print "=rotunits,$rotUnitsType Test \t\t\tPassed\r\n\r\n";
        print $csvFileHandle "rotunits$rotUnitsType Test,Passed\r\n";
        print $testFileHandle "=rotunits,$rotUnitsType Test Passed $result\r\n";
        return 1;
    } else {
        print "rotunit set test \t\t\tFailed\r\n";
        print $csvFileHandle "=rotunits,$rotUnitsType Test,Failed\r\n";
        print $testFileHandle "=rotunits,$rotUnitsType Test Failed $result\r\n";
        return 0;
    }
} # end of TestRotationUnitsSet




############################################################################
#  TestLinearUnits
#
#  Description: Test Linear Units command
#
#       Inputs: $portTest         - comport device is on
#               $csvFileHandle    - file handle to write csv test results
#               $testFileHandle    - file handle to write txt test results
#
#      Returns: Success or Failure - 0 or 1
#
# Side Effects: None
#
#        Notes: TODO: add returns
#
############################################################################
sub TestLinearUnits
{
    my $portTest      = shift;
    my $csvFileHandle = shift;
    my $testFileHandle = shift;

    my $testSuccess = $SUCCESS;

    $dataValue ="METERS";
    $testSuccess = TestLinearUnitsSet($portTest,$dataValue,$csvFileHandle,$testFileHandle);

    if ($testSuccess == $SUCCESS) {
        $dataValue = "METERS";
        $testSuccess = TestLinearUnitsGet($portTest,$dataValue,$csvFileHandle,$testFileHandle);
    }

    if ($testSuccess == $SUCCESS){
        $dataValue = "FEET";
        $testSuccess = TestLinearUnitsSet($portTest,$dataValue,$csvFileHandle,$testFileHandle);
    }

    if ($testSuccess == $SUCCESS) {
        $dataValue = "FEET";
        $testSuccess = TestLinearUnitsGet($portTest,$dataValue,$csvFileHandle,$testFileHandle);
    }

    if ($testSuccess == $SUCCESS) {
        print "TestLinearUnits test \t\t\tPassed\r\n\r\n";
        print $csvFileHandle "TestLinearUnits test,Passed\r\n";
        print $testFileHandle "TestLinearUnits test, Passed\r\n";
    } else {
        print "TestLinearUnits test \t\t\tFailed\r\n";
        print $csvFileHandle "TestLinearUnits test,Failed\r\n";
        print $testFileHandle "TestLinearUnits test, Failed\r\n";
    }

    return $testSuccess;

} # end of TestLinearUnits


############################################################################
#  TestLinearUnitsGet
#
#  Description: Test the Get Linear Units Comand ?linunits
#
#       Inputs: $portTest         - comport device is on
#               $rotUnitsType     - rotational units type
#               $csvFileHandle    - file handle to write csv test results
#               $testFileHandle    - file handle to write csv test results
#
#      Returns: Success or Failure - 0 or 1
#
# Side Effects: None
#
#        Notes: None
#
############################################################################
sub TestLinearUnitsGet
{
    my $portTest      = shift;
    my $linUnitsType  = shift;
    my $csvFileHandle = shift;
    my $testFileHandle = shift;

    my $testSuccess = $SUCCESS;

    if ( (index($deviceName,'1725') != -1) || (index($deviceName,'1750') != -1) || (index($deviceName,'1775IMU') != -1)) {
        my $commandStatus = "?linunits";
        $portTest->write($commandStatus."\n");
        select(undef, undef, undef, 0.25);  # sleep 1/4 second 250 milliseconds

        my $result = $portTest->input;
        print "linunit get result = $result";
        print "linunit get type   = $linUnitsType\r\n";
        #print $testFileHandle "linunit get result = $result";
        #print $testFileHandle "linunit get type   = $linUnitsType\r\n";

        if( $result eq "LINUNITS,$linUnitsType\r\n" ) {
            print "?linunits Test \t\t\tPassed\r\n\r\n";
            print $csvFileHandle "?linunits Test,Passed\r\n";
            print $testFileHandle "?linunits Test Passed $result\r\n";
            $testSuccess = $SUCCESS;
        } else {
            print "?linunits Test \t\t\tFailed\r\n";
            print $csvFileHandle "?linunits Test,Failed\r\n";
            print $testFileHandle "?linunits Test Failed $result\r\n";
            $testSuccess = $FAILED;
        }
    }
    else{
         $testSuccess = $SUCCESS;
    }

    return $testSuccess;

} # end of TestLinearUnitsGet

############################################################################
#  TestLinearUnitsSet
#
#  Description: Test the Set Linear Units Command =linunits,X where X = meters or feet
#
#       Inputs: $portTest         - comport device is on
#               $linUnitsType     - rotational units type
#               $csvFileHandle    - file handle to write csv test results
#               $testFileHandle    - file handle to write csv test results
#
#      Returns: Success or Failure - 0 or 1
#
# Side Effects: None
#
#        Notes: None
#
############################################################################
sub TestLinearUnitsSet
{
    my $portTest      = shift;
    my $linUnitsType  = shift;
    my $csvFileHandle = shift;
    my $testFileHandle = shift;

    my $testSuccess = $SUCCESS;

    if ( (index($deviceName,'1725') != -1) || (index($deviceName,'1750') != -1) || (index($deviceName,'1775IMU') != -1)) {
        #set the configuration
        my $commandStatus = "=linunits,$linUnitsType";
        $portTest->write($commandStatus."\n");
        select(undef, undef, undef, 0.25);  # sleep 1/4 second 250 milliseconds

        my $result = $portTest->input;
        print "linunit set result = $result";
        print "linunit set type   = $linUnitsType\r\n";
        #print $testFileHandle "linunit set result = $result";
        #print $testFileHandle "linunit set type   = $linUnitsType\r\n";

        if( $result eq "LINUNITS,$linUnitsType\r\n" ) {
            print "=linunits Test \t\t\tPassed\r\n\r\n";
            print $csvFileHandle "linunits Test,Passed\r\n";
            print $testFileHandle "=linunits Test Passed $result\r\n";
            $testSuccess = $SUCCESS;
        } else {
            print "=linunits Test \t\t\tFailed\r\n";
            print $csvFileHandle "linunits Test,Failed\r\n";
            print $testFileHandle "=linunits Test Failed $result\r\n";
            $testSuccess = $FAILED;
        }
    }
    else{
         $testSuccess = $SUCCESS;
    }

    return $testSuccess;

} # end of TestLinearUnitsSet

############################################################################
#  SendConfigCommand
#
#  Description: Test the Set/Clear Config Mode Command =config,X where X is
#				1 Enter Config Mode or 0 Exit Config Mode
#
#       Inputs: $portTest         - comport device is on
#               $dataValue        - value to use in the command - 0 to Exit and 1 to Enter CONFIG mode
#               $logTestResults   - whether to log the test results or not
#               $csvFileHandle    - file handle to write csv test results
#               $testFileHandle    - file handle to write txt test results
#
#      Returns: Success or Failure - 0 or 1
#
# Side Effects: None
#
#        Notes: No return when using 0 in the command as it will enter NORMAL
#               mode and will not return a value
#
############################################################################
sub SendConfigCommand
{
    my $portTest       = shift;
    my $dataValue      = shift;
    my $logTestResults = shift;
    my $csvFileHandle  = shift;
    my $testFileHandle  = shift;

    my $testStatus = $SUCCESS;

    my $command = "=config,$dataValue";
	my $result = $portTest->input;
    $portTest->lookclear;
    $portTest->write($command."\n");
    select(undef, undef, undef, 0.50);  # sleep 1/4 second 250 milliseconds
    $result = $portTest->input;

    if ($logTestResults == 1) {
        print "Config result = $result";
        #print $testFileHandle "Config result = $result";
        my $substr = "CONFIG";
        if (index($result, $substr) != -1) {
            print "=config,$dataValue Test \t\t\tPassed\r\n\r\n";
            print $csvFileHandle "config$dataValue Test,Passed\r\n";
            print $testFileHandle "=config,$dataValue Test Passed $result\r\n";
            $testStatus = $SUCCESS;
        } else {
            print "=config,$dataValue Test \t\t\tFailed\r\n";
            print $csvFileHandle "config$dataValue Test,Failed\r\n";
            print $testFileHandle "=config,$dataValue Test, Failed $result\r\n";
            $testStatus = $FAILED;
        }
    } # end of if ($logTestResults eq 1)

    return $testStatus;
} # end of SendConfigCommand


############################################################################
#  SendUpgradeCommand
#
#  Description: Send the Debug command to enter or exit DEBUG mode
#
#       Inputs: $portTest         - comport device is on
#               $dataValue        - value to use in the command - 0 to Exit and 1 to Enter DEBUG mode
#               $logTestResults   - whether to log the test results or not
#               $csvFileHandle    - file handle to write csv test results
#               $testFileHandle    - file handle to write txt test results
#
#      Returns: Success or Failure - 0 or 1
#
# Side Effects: None
#
#        Notes: No return when using 0 in the command as it will enter NORMAL
#               mode and will not return a value
#
#
############################################################################
sub SendUpgradeCommand
{
    my $portTest       = shift;
    my $dataValue      = shift;
    my $logTestResults = shift;
    my $csvFileHandle  = shift;
    my $testFileHandle  = shift;

    my $testStatus = $SUCCESS;

    my $command = "=upgrade,$dataValue";

    #$portTest->lookclear;
    $portTest->write($command."\n");

    select(undef, undef, undef, 0.25);  # sleep 1/4 second 250 milliseconds
    my $result = $portTest->input;

    if ($logTestResults == 1) {
        print "Upgrade result = $result\r\n";
        print $testFileHandle "Upgrade result = $result\r\n";
        my $substr = "UPGRADE";
        my $invalidString = "INVALID"; # this can occur if we are in CONFIG mode
                                       # and we are trying to get into DEBUG mode

        if ((index($result, $invalidString) != -1)) {
            print "UPGRADE test \t\t\tFailed\r\n";
            print $csvFileHandle "UPGRADE Set,Failed\r\n";
            print $testFileHandle "UPGRADE Set, Failed, Invalid String\r\n";
            $testStatus = $FAILED;
        } else {

            if (index($result, $substr) != -1) {

                print "UPGRADE set test \t\t\tPassed\r\n\r\n";
                print $csvFileHandle "UPGRADE Set,Passed\r\n";
                print $testFileHandle "UPGRADE Set, Passed,,\r\n";
                $testStatus = $SUCCESS;
            } else {
                print "UPGRADE test \t\t\tFailed\r\n";
                print $csvFileHandle "UPGRADE Set,Failed\r\n";
                print $testFileHandle "UPGRADE Set, Failed\r\n";
                $testStatus = $FAILED;
            }
        }
    } # end of if ($logTestResults == 1)

    return $testStatus;
} # end of SendUpgradeCommand

############################################################################
#  SendDebugCommand
#
#  Description: Send the Debug command to enter or exit DEBUG mode
#
#       Inputs: $portTest         - comport device is on
#               $dataValue        - value to use in the command - 0 to Exit and 1 to Enter DEBUG mode
#               $logTestResults   - whether to log the test results or not
#               $csvFileHandle    - file handle to write csv test results
#               $testFileHandle    - file handle to write txt test results
#
#      Returns: Success or Failure - 0 or 1
#
# Side Effects: None
#
#        Notes: No return when using 0 in the command as it will enter NORMAL
#               mode and will not return a value
#
#
############################################################################
sub SendDebugCommand
{
    my $portTest       = shift;
    my $dataValue      = shift;
    my $logTestResults = shift;
    my $csvFileHandle  = shift;
    my $testFileHandle  = shift;

    my $testStatus = $SUCCESS;
    my $substr = "DEBUG";
    my $invalidString = "INVALID"; # this can occur if we are in CONFIG mode
                                   # and we are trying to get into DEBUG mode

    my $command = "=debug,$dataValue";

    $portTest->write($command."\r\n");

    select(undef, undef, undef, 0.75);  # sleep 1/2 second
    my $result = $portTest->input;
    print "Debug Result ";
    print "Debug result = $result\r\n";

    if ($logTestResults == 1) {
        # print "Debug result = $result\r\n";
        print $testFileHandle "Debug result = $result\r\n";
       if ((index($result, $invalidString) != -1)) {
            print "DEBUG test \t\t\tFailed\r\n";
            print $csvFileHandle "DEBUG Set,Failed\r\n";
            print $testFileHandle "DEBUG Set, Failed, Invalid String\r\n";
            $testStatus = $FAILED;
        } else {

            if (index($result, $substr) != -1) {

                print "DEBUG set test \t\t\tPassed\r\n\r\n";
                print $csvFileHandle "DEBUG Set,Passed\r\n";
                print $testFileHandle "DEBUG Set, Passed,,\r\n";
                $testStatus = $SUCCESS;

            } else {
                print "DEBUG test \t\t\tFailed\r\n";
                print $csvFileHandle "DEBUG Set,Failed\r\n";
                print $testFileHandle "DEBUG Set, Failed\r\n";
                $testStatus = $FAILED;
            }
        }
    } # end of if ($logTestResults == 1)

    return $testStatus;
} # end of SendDebugCommand

############################################################################
#  SendDebugQueryCommand
#
#  Description: Send the Debug query command
#
#       Inputs: $portTest         - comport device is on
#               $logTestResults   - whether to log the test results or not
#               $csvFileHandle    - file handle to write csv test results
#               $testFileHandle    - file handle to write txt test results
#
#      Returns: Success or Failure - 0 or 1
#
# Side Effects: None
#
#
#
############################################################################
sub SendDebugQueryCommand
{
    my $portTest       = shift;
    my $logTestResults = shift;
    my $csvFileHandle  = shift;
    my $testFileHandle = shift;
    my $testStatus = $SUCCESS;

    my $command = "?debug";

    $portTest->lookclear;
    $portTest->write($command."\n");
    select(undef, undef, undef, 0.25);  # sleep 1/4 second 250 milliseconds
    my $result = $portTest->input;

    if ($logTestResults == 1) {
        print "Debug result = $result\r\n";
        print $testFileHandle "Debug result = $result\r\n";
        my $substr = "DEBUG";
        if (index($result, $substr) != -1)  {
            print "DEBUG Query test \t\t\tPassed\r\n\r\n";
            print $csvFileHandle "DEBUG Query,Passed\r\n";
            print $testFileHandle "DEBUG Query, Passed\r\n";
            $testStatus = $SUCCESS;
        } else {
            print "DEBUG Query test \t\t\tFailed\r\n";
            print $csvFileHandle "DEBUG Query,Failed\r\n";
            print $testFileHandle "DEBUG Query, Failed\r\n";
            $testStatus = $FAILED;
        }
    } # end of if ($logTestResults == 1)

    return $testStatus;
} # end of SendDebugQueryCommand


############################################################################
#  TestHalt
#
#  Description: Test halt command
#
#       Inputs: $portTest         - comport device is ons
#               $csvFileHandle    - file handle to write csv test results
#               $testFileHandle    - file handle to write csv test results
#               $logTestResults   - Flag to log results
#
#      Returns: Success or Failure - 0 or 1
#
# Side Effects: None
#
#        Notes: Only available after debug command and in DEBUG mode
#
############################################################################
sub TestHalt
{
    my $portTest       = shift;
    my $csvFileHandle  = shift;
    my $testFileHandle  = shift;
    my $logTestResults = shift;
    my $haltStatus = "=halt";

    $portTest->write($haltStatus."\n");

    select(undef, undef, undef, 0.15);  # sleep 1/4 second 250 milliseconds
    my $result = $portTest->input;
    print "HALT result = $result";

    if ($logTestResults == 1) {
        print "HALT result = $result\r\n";
        print $testFileHandle "HALT result = $result";
        my $substr = "HALT";
        if (index($result, $substr) != -1) {
            print "HALT set test \t\t\tPassed\r\n\r\n";
            print $csvFileHandle "HALT SET test,Passed\r\n";
            print $testFileHandle "HALT SET test, Passed\r\n";
            return 1;
        } else {
            print "HALT test \t\t\tFailed\r\n";
            print $csvFileHandle "HALT SET test,Failed\r\n";
            print $testFileHandle "HALT SET test, Failed\r\n";
            return 0;
        }
    } # end of if ($logTestResults == 1)
} # end of TestHalt

############################################################################
#  TestVersion
#
#  Description: Test ws command - get version
#
#       Inputs: $portTest         - comport device is on
#               $csvFileHandle    - file handle to write csv test results
#               $testFileHandle    - file handle to write txt test results
#
#      Returns: Success or Failure - 0 or 1
#
# Side Effects: None
#
#        Notes: TODO: add returns
#
############################################################################
sub TestVersion
{
    my $portTest      = shift;
    my $csvFileHandle = shift;
    my $testFileHandle = shift;
    my $localImuVariant;

    my $deviceString;
    my $status = "?ws";

    $portTest->write($status."\n");
    select(undef, undef, undef, 0.25);  # sleep 1/4 second 250 milliseconds
    my $result = $portTest->input;
    print "$result\r\n";

    print $csvFileHandle "\r\n$result,\r\n";
    print $testFileHandle "\r\n$result,\r\n";

} # end of TestVersion

############################################################################
#  GetNormalTest
#
#  Description: capture the NORMAL mode binary data to a text file
#
#       Inputs: $portTest         - comport device is on
#               $dataFile         - data file to write results to
#               $testString       - The HEX string to search for in the data
#
#      Returns: Success or Failure - 0 or 1
#
# Side Effects: None
#
#        Notes: TODO: add returns
#
############################################################################
sub GetNormalTest
{
    my $portTest   = shift;
    my $dataFile   = shift;
    my $testString = shift;

    my $result;
    my $imuPacket;
    my @hexResult;

    my $count_in = 0;
    my $totalCount = 0;
    my $substr  ="WS: Report the software versions";

    print "Normal command Test started\r\n";

    my $commandStatus = "=config,0";
    $portTest->write($commandStatus."\n");
    #select(undef, undef, undef, 0.50);

    my $indexCount = 0;
    while ($indexCount < 10) { # should only need a few passes, but we don't want to loop forever
        $result = $portTest->input;
        #print "$result";
        my $resultLength = length($result);
        my $stringSize = 2 * $resultLength;
        @hexResult = unpack("H$stringSize", $result);
        #print "@hexResult";
        $indexCount++;

        $resultLength = length($result);
        $stringSize = 2 * $resultLength;
        print ($dataFile unpack("H$stringSize", $result), "\n");
        #print $dataFile,"\r\n";

        select(undef, undef, undef, 0.75);  # sleep 3/4 second
    } # end of while

    my $hexString = join('',@hexResult);

    # Search result for header in the file
    my $location = index($hexString,$testString);

    # move past the first header
    my $stringOffset = $location + 10;

    # get the location of the next header
    my $location2 = index($hexString,$testString,$stringOffset);

    # get count of how many bytes in the message between the headers
    my $hexCount = ($location2 - $location) / 2 ;

    my $length = ($location2 - $location);

    $imuPacket = substr($hexString,$location, $length );
	$commandStatus = "=config,1";
    $portTest->write($commandStatus."\n");
	$result = $portTest->input;
    return $hexCount, $imuPacket;
	sleep 2;

} # end of GetNormalTest

############################################################################
#  GetDebugTest
#
#  Description: capture the DEBUG mode data to a text file
#
#       Inputs: $portTest         - comport device is on
#               $csvFileHandle    - file handle to write csv test results
#               $testFileHandle    - file handle to write txt test results
#               $storageDirectory - Directory to write Debug data to
#
#      Returns: Success or Failure - 0 or 1
#
# Side Effects: None
#
#        Notes: TODO: add returns
#
############################################################################
sub GetDebugTest
{
    my $portTest       = shift;
    my $csvFileHandle  = shift;
    my $testFileHandle  = shift;
    my $storageDirectory   = shift;
    my $globalTest	= shift;
    my $dataFile = shift;
    my $command = shift;
    my $result = shift;
    my $DebugTestFileName = $storageDirectory . "/testdebug.txt";
    my $substr = "DEBUG,1";
    print "\nDebugTestFileName  = $DebugTestFileName\n";
    open my $DebugTestFileHandle, '>', $DebugTestFileName or die "Couldn't open file testdebug.txt, $!";
    $command = "=DR,5";
    $portTest->write($command."\n");
    select(undef, undef, undef, 0.50);  # sleep 1/4 second 250 milliseconds
    $result = $portTest->input;
    print "Debug result = $result\r\n";
    #$command = "=restart";
    #$portTest->write($command."\n");
    #select(undef, undef, undef, 2.00);  # sleep 1/2 second 500 milliseconds
    #$result = $portTest->input;
    #print "Debug result = $result\r\n";
    $command = "=config,0";
    $portTest->write($command."\n");
    select(undef, undef, undef, 0.50);  # sleep 1/4 second 250 milliseconds
    $result = $portTest->input;
    #print "Debug result = $result\r\n";
    $command = "=debug,1";
    #print "Debug result = $result\r\n";

    my $indexCount = 0;
    while ($indexCount < 10){ # should only need one pass, but we don't want to loop forever

        $portTest->write($command."\n");
        select(undef, undef, undef, 0.25);  # sleep 1/4 second 250 milliseconds
        $result = $portTest->input;
        #print $result;

        # test for the debug mode
        if (index ($result,$substr) != -1) {
            #print "successTest = 1";
            last;
        }
        $indexCount++;

        select(undef, undef, undef, 0.50);

    } # end of while
    #$command = "=debug,1";
    #$portTest->write($command."\n");
    #select(undef, undef, undef, 0.25);  # sleep 1/4 second 250 milliseconds
    #$result = $portTest->input;
    print $DebugTestFileHandle "$result\r\n\r\n";
    print "Result1 = $result\r\n";
    $command = "=start";
    $portTest->write($command."\n");
    select(undef, undef, undef, 0.25);  # sleep 1/4 second 250 milliseconds
    $result = $portTest->input;
    print "Result2 = $result\r\n";


    if (!$DebugTestFileHandle) {
        print "The testdebug.txt did not open - test Failed\r\n";
        print $csvFileHandle "Debug Mode Test,Failed\r\n";
        print $testFileHandle "Debug Mode Test, Failed, testdebug.txt not opened\r\n";
        $globalTest = 0;
    }
    $indexCount = 0;
        while ($indexCount < 5) { # should only need one pass, but we don't want to loop forever
            $result = $portTest->input;
            print $DebugTestFileHandle "$result\r\n\r\n";
            print "$result";
            $indexCount++;
            select(undef, undef, undef, 0.50);

        } # end of while
    close ($DebugTestFileHandle);
    $command = "=halt";
    $portTest->write($command."\n");
    select(undef, undef, undef, 0.25);  # sleep 1/4 second 250 milliseconds
    $result = $portTest->input;
    print "Debug result = $result\r\n";
    $command = "=dr,1000";
    $portTest->write($command."\n");
    select(undef, undef, undef, 0.50);  # sleep 1/4 second 250 milliseconds
    $result = $portTest->input;
    print "Debug result = $result\r\n";

} # end of GetDebugTest
############################################################################
#  GetHelpMenuTest
#
#  Description: Dump the help menu for DEBUG and CONFIG mode
#
#       Inputs: $portTest         - comport device is on
#               $dataFile         - file handle to write help menu to
#
#      Returns: Success or Failure - 0 or 1
#
# Side Effects: None
#
#        Notes: TODO: add returns
#
############################################################################

sub GetHelpMenuTest
{
    my $portTest = shift;
    my $dataFile = shift;
    my $result;

    my $count_in    = 0;
    my $totalCount  = 0;
    my $successTest = 0;
    my $substr      = "WS:";

    my $commandStatus = "?help";
    $portTest->write($commandStatus."\n");
    select(undef, undef, undef, 0.50);

    print "Help command Test started\n";

    my $indexCount = 0;
    while ($indexCount < 10) { # should only need one pass, but we don't want to loop forever

        $result = $portTest->input;
        print $dataFile "$result";
        #print "$result";

        # test for the ending string
        if (index($result, $substr) != -1) {
            $successTest = 1;
            last;
        }
        $indexCount++;

        select(undef, undef, undef, 0.50);

    } # end of while

    # now test the help command for a single command
    print "Testing Single help command\r\n\r\n";
    print $dataFile "\r\nTesting Single help command\r\n";
    $commandStatus = "?help,ws";
    $portTest->write($commandStatus."\n");
    select(undef, undef, undef, 0.50);  # sleep 1/4 second 250 milliseconds
    $result = $portTest->input;

    if (index($result, $substr) != -1)  {
        $successTest = 1;
    } else {
        $successTest = 0;
    }
    print "$result\r\n\r\n";
    print $dataFile "$result\r\n\r\n";

    return $successTest;

} # end of GetHelpMenuTest

############################################################################
#  TestFilter
#
#  Description: test the filtering using testfilt command
#
#       Inputs: $portTest         - comport device is on
#               $testFilterFileHandle   - file handle to write text test results
#
#      Returns: None
#
# Side Effects: None
#
#        Notes: This test does not return anything as it is the last test and
#               a visual inspection of the test results is necesssary anyway
#
############################################################################
sub TestFilter
{
    my $portTest = shift;
    my $testFilterFileHandle = shift;

    my $result     = "";
    my $count_in   = 0;
    my $totalCount = 0;
    my $substr     = "Gyro filter test complete";

    my $commandStatus = "=testfilt";
    $portTest->write($commandStatus."\n");
    select(undef, undef, undef, 0.50);

    print "testfilt command Test started\n";

    my $indexCount = 0;
    while (1) {

        $result = $portTest->input;
        print $testFilterFileHandle "$result";
        #print "$result";

        # test for the ending string
        if (index($result, $substr) != -1) {
            print "result contains $substr\n";
            last;
        }
        $indexCount++;

        select(undef, undef, undef, 0.50);
    } # end of while

    print "testfilt command Test completed\n";

} # end of TestFilter

############################################################################
#  GetSerialNumber
#
#  Description: Get the serial number of the device
#
#       Inputs: $portTest         - comport device is on
#               $csvFileHandle    - file handle to write csv test results
#               $testFileHandle    - file handle to write csv test results
#
#      Returns: Success or Failure - 0 or 1
#
# Side Effects: None
#
#        Notes: None
#
############################################################################
sub GetSerialNumber
{
    my $portTest      = shift;
    my $csvFileHandle = shift;
    my $testFileHandle = shift;
    my $commandStatus = "?is";

    $portTest->write($commandStatus."\n");
    select(undef, undef, undef, 0.25);  # sleep 1/4 second 250 milliseconds

    my $result = $portTest->input;
    print "serial number result = $result";
    print $testFileHandle "serial number result = $result";

    if ( $result ne "Error reading the serial number!\r\n" ) {
        print "Serial Number get test \t\t\tPassed\r\n\r\n";
        print $csvFileHandle "Serial Number,Passed\r\n";
        print $testFileHandle "Serial Number, Passed\r\n";
        return 1;
    } else {
        print "Serial Number get test \t\t\tFailed\r\n\r\n";
        print $csvFileHandle "Serial Number,Failed\r\n";
        print $testFileHandle "Serial Number, Failed\r\n";
        return 0;
    }

} # end of GetSerialNumber

############################################################################
#  TestSetDR
#
#  Description: Test Set Data Rate Command =dr,X Where X is one of 1, 5, 10, 25,
#				50, 100, 250, 500, 750, 1000, 3600, 5000
#
#       Inputs: $portTest         - comport device is on
#               $drValue          - data rate value
#               $logTestResults   - whether to log the test results or not
#               $csvFileHandle    - file handle to write csv test results
#               $testFileHandle    - file handle to write txt test results
#
#      Returns: Success or Failure - 0 or 1
#
# Side Effects: None
#
#        Notes: None
#
############################################################################
sub TestSetDR
{
    my $portTest       = shift;
    my $drValue        = shift;
    my $logTestResults = shift;
    my $csvFileHandle  = shift;
    my $testFileHandle  = shift;

    #set the configuration
    my $commandStatus = "=dr,$drValue";
    $portTest->write($commandStatus."\n");
    select(undef, undef, undef, 0.50);

    my $result = $portTest->input;
    #print "\r\ndr result = $result\r\n";
    #print "dr value   = $drValue\r\n";

    if ($logTestResults == 1) {
        print "\r\ndr result = $result\r\n";
		if( $result eq "DR,$drValue\r\n" ) {
            print "=dr,$drValue Test \t\t\tPassed\r\n\r\n";
            print $csvFileHandle "dr$drValue Test,Passed\r\n";
            print $testFileHandle "=dr,$drValue Test Passed $result\r\n";
            return 1;
        } else {
            print "=dr,$drValue Test \t\t\tFailed\r\n\r\n";
            print $csvFileHandle "dr$drValue Test,Failed\r\n";
            print $testFileHandle "=dr,$drValue Test Failed $result\r\n";
            return 0;
        }
    } # end of if ($logTestResults == 1)

} # end of TestSetDR

############################################################################
#  TestRotationFormatSet
#
#  Description: Test the Set Rotational Format Command =rotfmt,X Where X is Rate or Delta
#
#       Inputs: $portTest         - comport device is on
#               $rotFmtType       - rotational format type
#               $csvFileHandle    - file handle to write csv test results
#               $testFileHandle    - file handle to write txt test results
#
#      Returns: Success or Failure - 0 or 1
#
# Side Effects: None
#
#        Notes: None
#
############################################################################
sub TestRotationFormatSet
{
    my $portTest      = shift;
    my $rotFmtType    = shift;
    my $csvFileHandle = shift;
    my $testFileHandle = shift;

    #set the configuration
    my $commandStatus = "=rotfmt,$rotFmtType";
    $portTest->write($commandStatus."\n");
    select(undef, undef, undef, 0.25);  # sleep 1/4 second 250 milliseconds

    my $result = $portTest->input;
    print "rotfmt result = $result";
    print "rotfmt type   = $rotFmtType\r\n";
    #print $testFileHandle "rotfmt result = $result";
    #print $testFileHandle "rotfmt type   = $rotFmtType\r\n";

    if( $result eq "ROTFMT,$rotFmtType\r\n" ) {
        print "=rotfmt,$rotFmtType Test \t\t\tPassed\r\n\r\n";
        print $csvFileHandle "rotfmt$rotFmtType Test,Passed\r\n";
        print $testFileHandle "=rotfmt,$rotFmtType Test Passed $result\r\n";
        return 1;
    } else {
        print "=rotfmt,$rotFmtType Test \t\t\tFailed\r\n";
        print $csvFileHandle "rotfmt$rotFmtType Test,Failed\r\n";
        print $testFileHandle "=rotfmt,$rotFmtType Test Failed $result\r\n";
        return 0;
    }

} # end of TestRotationFormatSet

############################################################################
#  TestRotationFormatGet
#
#  Description: Test the Get Rotational Format Command ?rotfmt
#
#       Inputs: $portTest         - comport device is on
#               $rotFmtType       - rotational format type
#               $csvFileHandle    - file handle to write csv test results
#               $testFileHandle    - file handle to write txt test results
#
#      Returns: Success or Failure - 0 or 1
#
# Side Effects: None
#
#        Notes: None
#
############################################################################
sub TestRotationFormatGet
{
    my $portTest      = shift;
    my $rotFmtType    = shift;
    my $csvFileHandle = shift;
    my $testFileHandle = shift;

    my $commandStatus = "?rotfmt";
    $portTest->write($commandStatus."\n");
    select(undef, undef, undef, 0.25);  # sleep 1/4 second 250 milliseconds

    my $result = $portTest->input;
    print "rotfmt get result = $result";
    #print $testFileHandle "rotfmt get result = $result";

    if( $result eq "ROTFMT,$rotFmtType\r\n" ) {
        print "?rotfmt Test \t\t\tPassed\r\n\r\n";
        print $csvFileHandle "?rotfmt Test,Passed\r\n";
        print $testFileHandle "?rotfmt Test Passed $result\r\n";
        return 1;
    } else {
        print "?rotfmt Test \t\t\tFailed\r\n";
        print $csvFileHandle "?rotfmt Test,Failed\r\n";
        print $testFileHandle "?rotfmt Test Failed $result\r\n";
        return 0;
    }
} # TestRotationFormatGet

############################################################################
#  TestLinearFormat
#
#  Description: Test Linear Format commands
#
#       Inputs: $portTest         - comport device is on
#               $csvFileHandle    - file handle to write csv test results
#               $testFileHandle    - file handle to write txt test results
#
#      Returns: Success or Failure - 0 or 1
#
# Side Effects: None
#
#        Notes: TODO: add returns
#
############################################################################
sub TestLinearFormat
{
    my $portTest      = shift;
    my $csvFileHandle = shift;
    my $testFileHandle = shift;
    my $testSuccess = $SUCCESS;

    $dataValue = "DELTA";
    $testSuccess = TestLinearFormatSet($portTest,$dataValue,$csvFileHandle,$testFileHandle);

    if ($testSuccess == $SUCCESS) {
        $dataValue = "DELTA";
        $testSuccess = TestLinearFormatGet($portTest,$dataValue,$csvFileHandle,$testFileHandle);
    }

    if ($testSuccess == $SUCCESS){
        $dataValue = "ACCEL";
        $testSuccess = TestLinearFormatSet($portTest,$dataValue,$csvFileHandle,$testFileHandle);
    }

    if ($testSuccess == $SUCCESS) {
        $dataValue = "ACCEL";
        $testSuccess = TestLinearFormatGet($portTest,$dataValue,$csvFileHandle,$testFileHandle);
    }

    if ($testSuccess == $SUCCESS) {
        print "TestLinearFormat test \t\t\tPassed\r\n\r\n";
        print $csvFileHandle "TestLinearFormat test,Passed\r\n";
        print $testFileHandle "TestLinearFormat test, Passed\r\n";
    } else {
        print "TestLinearFormat test \t\t\tFailed\r\n";
        print $csvFileHandle "TestLinearFormat test,Failed\r\n";
        print $testFileHandle "TestLinearFormat test, Failed\r\n";
    }

    return $testSuccess;

} # end of TestLinearFormat

############################################################################
#  TestLinearFormatSet
#
#  Description: Test the Set Linear Format Comand =linfmt,X Where X is delta or accel
#
#       Inputs: $portTest         - comport device is on
#               $linFmtType       - linear format type
#               $csvFileHandle    - file handle to write csv test results
#               $testFileHandle    - file handle to write txt test results
#
#      Returns: Success or Failure - 0 or 1
#
# Side Effects: None
#
#        Notes: None
#
############################################################################
sub TestLinearFormatSet
{
    my $portTest      = shift;
    my $linFmtType    = shift;
    my $csvFileHandle = shift;
    my $testFileHandle = shift;
    my $testSuccess = $SUCCESS;

    if ( (index($deviceName,'1725') != -1) || (index($deviceName,'1750') != -1) || (index($deviceName,'1775IMU') != -1)) {
        #set the configuration
        my $commandStatus = "=linfmt,$linFmtType";
        $portTest->write($commandStatus."\n");
        select(undef, undef, undef, 0.25);  # sleep 1/4 second 250 milliseconds

        my $result = $portTest->input;
        print "linfmt result = $result";
        print "linfmt type   = $linFmtType\r\n";
        #print $testFileHandle "linfmt result = $result";
        #print $testFileHandle "linfmt type   = $linFmtType\r\n";

        if( $result eq "LINFMT,$linFmtType\r\n" ) {
            print "=linfmt,$linFmtType Test \t\t\tPassed\r\n\r\n";
            print $csvFileHandle "linfmt$linFmtType Test,Passed\r\n";
            print $testFileHandle "=linfmt,$linFmtType Test Passed $result\r\n";
            $testSuccess = $SUCCESS;
        } else {
            print "=linfmt,$linFmtType Test \t\t\tFailed\r\n";
            print $csvFileHandle "linfmt$linFmtType Test,Failed\r\n";
            print $testFileHandle "=linfmt,$linFmtType Test Failed $result\r\n";
            $testSuccess = $FAILED;
        }
    }
    else{
        $testSuccess = $SUCCESS;
    }

    return $testSuccess;

} # end of TestLinearFormatSet

############################################################################
#  TestLinearFormatGet
#
#  Description: Test the Get Linear Format Comand ?linfmt
#
#       Inputs: $portTest         - comport device is on
#               $linFmtType       - Linear format type
#               $csvFileHandle    - file handle to write csv test results
#               $testFileHandle    - file handle to write txt test results
#
#      Returns: Success or Failure - 0 or 1
#
# Side Effects: None
#
#        Notes: None
#
############################################################################
sub TestLinearFormatGet
{
    my $portTest      = shift;
    my $linFmtType    = shift;
    my $csvFileHandle = shift;
    my $testFileHandle = shift;
    my $testSuccess = $SUCCESS;

    if ( (index($deviceName,'1725') != -1) || (index($deviceName,'1750') != -1) || (index($deviceName,'1775IMU') != -1)) {
        my $commandStatus = "?linfmt";
        $portTest->write($commandStatus."\n");
        select(undef, undef, undef, 0.25);  # sleep 1/4 second 250 milliseconds

        my $result = $portTest->input;
        print "linfmt get result = $result";
        #print $testFileHandle "linfmt get result = $result";

        if( $result eq "LINFMT,$linFmtType\r\n" ) {
            print "?linfmt Test \t\t\tPassed\r\n\r\n";
            print $csvFileHandle "?linfmt Test,Passed\r\n";
            print $testFileHandle "?linfmt Test, Passed $result\r\n";
            $testSuccess = $SUCCESS;
        } else {
            print "?linfmt Test \t\t\tFailed\r\n";
            print $csvFileHandle "?linfmt Test,Failed\r\n";
            print $testFileHandle "?linfmt Test Failed $result\r\n";
            $testSuccess = $FAILED;
        }
    }
    else{
         $testSuccess = $SUCCESS;
    }

    return $testSuccess;

} # TestLinearFormatGet


############################################################################
#  TestAccelTypeNegativeTestSet
#
#  Description: Test the Set Acceleromtere type for a invalid value (20g) for 1750 IMU
#
#       Inputs: $portTest         - comport device is on
#
#               $csvFileHandle    - file handle to write csv test results
#               $testFileHandle   - file handle to write csv test results
#               $accelType        - accel type
#
#      Returns: Success or Failure - 0 or 1
#
# Side Effects: None
#
#        Notes: None
#
############################################################################
sub TestAccelTypeNegativeTestSet
{
    my $portTest      = shift;
    my $csvFileHandle = shift;
    my $testFileHandle = shift;
    my $CurAccelType;
    my $accelType = 20;
    my $testStatus = $SUCCESS;
    my $commandStatus;
    my $result;
    my @dataArray;

    print "Start 1750IMU AccelTypeSet Neg Test\r\n";
    print $testFileHandle "\r\nStart 1750IMU AccelTypeSet Neg Test\r\n";
    $commandStatus = "?acceltype";
    $portTest->write($commandStatus."\n");
    select(undef, undef, undef, 0.25);  # sleep 1/4 second 250 milliseconds
    $result = $portTest->input;
    @dataArray = split(",",$result);
    $CurAccelType = $dataArray[1];
    if (!$CurAccelType) {
        $CurAccelType = "Not Available";
    }
    print "1750IMU AccelTypeSet Neg Test current Acceltype = $CurAccelType\r\n";

    #set the configuration
    print "1750IMU AccelTypeSet Neg Test new Acceltype = $accelType\r\n";

    $commandStatus = "=acceltype,$accelType";
    $portTest->write($commandStatus."\n");
    select(undef, undef, undef, 0.50);
    $result = $portTest->input;
    print "1750IMU AccelTypeSet Neg Test result = $result\r\n";

    if ( (index($result,"ERROR,Incorrect") != -1)) {
        #print "1750IMU AccelTypeSet Neg Test acceltype = $result\r\n";

        print "=acceltype,$accelType 1750IMU Neg Test \t\t\tPassed\r\n\r\n";
        print $csvFileHandle "acceltype$accelType 1750IMU Neg Test,Passed\r\n";
        print $testFileHandle "=acceltype,$accelType 1750IMU Neg Test, Passed $result\r\n";
        $testStatus = $SUCCESS;
    } else{
	#print "1750IMU AccelTypeSet Neg Test acceltype = $result\r\n";

	print "=acceltype,$accelType 1750IMU Neg Test \t\t\tFailed\r\n";
        print $csvFileHandle "acceltype$accelType 1750IMU Neg Test,Failed\r\n";
        print $testFileHandle "=acceltype,$accelType 1750IMU Neg Test, Failed\r\n";
		$commandStatus = "=acceltype,$CurAccelType";
		$portTest->write($commandStatus."\n");
        $testStatus = $FAILED;
    }

    return $testStatus;

} # end of TestAccelTypeNegativeTestSet

############################################################################
#  1750IMU TestAccelTypeSet
#
#  Description: Test the Set Acceleromtere Command =accel,X Where X is (2g, 10g, 30g) for 1750 IMU
#
#       Inputs: $portTest         - comport device is on
#               $accelType       - linear format type
#               $csvFileHandle    - file handle to write csv test results
#               $testFileHandle    - file handle to write csv test results
#
#      Returns: Success or Failure - 0 or 1
#
# Side Effects: None
#
#        Notes: None
#
############################################################################
sub TestAccelTypeSet
{
    my $portTest      = shift;
    my $accelType    = shift;
    my $csvFileHandle = shift;
    my $testFileHandle = shift;
    my $CurAccelType;
	my @dataArray;
    my $testStatus = $SUCCESS;

    print "Start 1750IMU AccelTypeSet Test\r\n";
    print $testFileHandle "\r\nStart 1750IMU AccelTypeSet Test\r\n";
    #Get current AccelType
    my $commandStatus = "?acceltype";
    $portTest->write($commandStatus."\n");
    select(undef, undef, undef, 0.25);  # sleep 1/4 second 250 milliseconds
    my $result = $portTest->input;
    @dataArray = split(",",$result);
    $CurAccelType = $dataArray[1];
    if (!$CurAccelType) {
        $CurAccelType = "Not Available";
        #print "1750IMU AccelTypeSet Test ?acceltype Result = $result\r\n";
        #print "1750IMU AccelTypeSet Test \t\t\tFailed\r\n";
        print $csvFileHandle "1750IMU ?acceltype Test,Failed\r\n";
        #print $testFileHandle "1750IMU AccelTypeSet Test ?acceltype Result, $result\r\n";
        print $testFileHandle "1750IMU ?acceltype Test, Failed $result\r\n";
        $testStatus = $FAILED;
    }
	print "1750IMU AccelTypeSet Testing current Acceltype = $CurAccelType\r\n";
	#print $testFileHandle "1750IMU AccelTypeSet Testing current Acceltype = $CurAccelType";
	print "1750IMU AccelTypeSet Setting Acceltype = $accelType\r\n";
	#print $testFileHandle "1750IMU AccelTypeSet Setting Acceltype = $accelType\r\n";
    #set the configuration
    $commandStatus = "=acceltype,$accelType";
    $portTest->write($commandStatus."\n");
    select(undef, undef, undef, 0.50);
    $result = $portTest->input;
    print "1750IMU AccelTypeSet result = $result\r\n";
    if ( (index($result,"$accelType") != -1)) {
        #print "1750IMU AccelTypeSet acceltype = $accelType\r\n";
        print "1750IMU =acceltype,$accelType Test \t\t\tPassed\r\n\r\n";
        print $csvFileHandle "1750IMU =acceltype$accelType Test $accelType,Passed\r\n";
        #print $testFileHandle "1750IMU AccelTypeSet acceltype result = $accelType\r\n";
        print $testFileHandle "1750IMU =acceltype,$accelType Test Passed $result\r\n";
        $commandStatus = "=acceltype,$CurAccelType";
        $portTest->write($commandStatus."\n");
        select(undef, undef, undef, 0.50);
        $result = $portTest->input;
        print "Set AccelType back to $result\r\n";
        print $testFileHandle "1750IMU AccelTypeSet Test, Set AccelType back to $result\r\n";
        $testStatus = $SUCCESS;
    } else {
        print "1750IMU AccelTypeSet test \t\t\tFailed\r\n";
        print $csvFileHandle "1750IMU AccelTypeSet Test,Failed\r\n";
        print $testFileHandle "1750IMU AccelTypeSet acceltype result = $accelType\r\n";
        print $testFileHandle "1750IMU AccelTypeSet Test $accelType, Failed\r\n";
        $testStatus = $FAILED;
    }

    return $testStatus;

} # end of TestAccelTypeSet

############################################################################
#  TestAccelTypeSetCommand
#
#  Description: Test the Accelerometer Set Command =acceltype for non 1750IMU Systems
#
#       Inputs: $portTest         - comport device is on
#               $accelType       - linear format type
#               $csvFileHandle    - file handle to write csv test results
#               $testFileHandle    - file handle to write csv test results
#
#      Returns: Success or Failure - 0 or 1
#
# Side Effects: None
#
#        Notes: None
#
############################################################################
sub TestAccelTypeSetCommand
{
    my $portTest      = shift;
    my $accelType    = shift;
    my $csvFileHandle = shift;
    my $testFileHandle = shift;
    my $testStatus = $SUCCESS;
	my $CurAccelType;

	my $commandStatus = "=acceltype,$accelType";
    $portTest->write($commandStatus."\n");
    select(undef, undef, undef, 0.50);
    my $result = $portTest->input;

    if ( (index($result, 'INVALID') != -1)) {
		print "Non 1750IMU =acceltype,$accelType Test \t\t\tPassed\r\n\r\n";
		print $csvFileHandle "Non 1750IMU =acceltype$accelType Test,Passed\r\n";
		#print $testFileHandle "\r\nAccelTypeSet Command Test, $result";
		print $testFileHandle "Non 1750IMU =acceltype,$accelType Test Passed $result\r\n";
		$testStatus = $SUCCESS;
	} else{
		print "Non 1750IMU =acceltype,$accelType Test \t\t\tFailed\r\n";
		print $csvFileHandle "Non 1750IMU =acceltype$accelType Test,Failed\r\n";
		#print $testFileHandle "\r\nAccelTypeSet Command Test, $result";
		print $testFileHandle "Non 1750IMU =acceltype,$accelType Test Failed\r\n";
		$commandStatus = "=acceltype,$CurAccelType";
		$portTest->write($commandStatus."\n");
		$testStatus = $FAILED;
	}

    return $testStatus;

} # end of TestAccelTypeSetCommand

############################################################################
#  TestAccelTypeGetCommand
#
#  Description: Test the Accel Type Get command ?accel for non 1750 IMU Systems
#
#       Inputs: $portTest         - comport device is on
#               $csvFileHandle    - file handle to write csv test results
#               $testFileHandle    - file handle to write txt test results
#
#      Returns: Success or Failure - 0 or 1
#
# Side Effects: None
#
#        Notes: None
#
############################################################################
sub TestAccelTypeGetCommand
{
    my $portTest      = shift;
    my $csvFileHandle = shift;
    my $testFileHandle = shift;

    my $commandStatus = "?acceltype";
    $portTest->write($commandStatus."\n");
    select(undef, undef, undef, 0.25);  # sleep 1/4 second 250 milliseconds
	my $result = $portTest->input;
	print "\r\nTestAccelTypeGet Comand result = $result\r\n";

	if ( (index($result,'INVALID') != -1)) {
		print "?acceltype Test \t\t\tPassed\r\n\r\n";
		print $csvFileHandle "?acceltype Test,Passed\r\n";
		#print $testFileHandle "\r\nAccelTypeGet Commmand Test, $result";
		print $testFileHandle "?acceltype Test, Passed\r\n";
		return 1;
	} else {
		print "?acceltype Test \t\t\tFailed\r\n";
		print $csvFileHandle "?acceltype Test,Failed\r\n";
		#print $testFileHandle "\r\nAccelTypeGet Comand Test, $result";
		print $testFileHandle "?acceltype Test, Failed\r\n";
		return 0;
	}


} # TestAccelTypeGetCommand

############################################################################
#  TestAccelTypeGet
#
#  Description: Test the Accelerometer type (2g, 10g, 30g) for 1750 IMU
#
#       Inputs: $portTest         - comport device is on
#               $csvFileHandle    - file handle to write csv test results
#               $testFileHandle    - file handle to write txt test results
#
#      Returns: Success or Failure - 0 or 1
#
# Side Effects: None
#
#        Notes: None
#
############################################################################
sub TestAccelTypeGet
{
    my $portTest      = shift;
    my $csvFileHandle = shift;
    my $testFileHandle = shift;

    if (index($deviceName,'1750') != -1) {
        my $commandStatus = "?acceltype";
        $portTest->write($commandStatus."\n");
        select(undef, undef, undef, 0.25);  # sleep 1/4 second 250 milliseconds
        my $result = $portTest->input;
        print "TestAccelTypeGet result = $result";
		#print $testFileHandle "TestAccelTypeGet result = $result";
		my $CurAccelType = $result;
		if ( ($result eq "ACCELTYPE,2\r\n" ) || ($result eq "ACCELTYPE,10\r\n" ) || ($result eq "ACCELTYPE,30\r\n" )) {
			print "1750IMU ?acceltype Test \t\t\tPassed, acceltype = $result\r\n\r\n";
			print $csvFileHandle "1750IMU ?acceltype Test,Passed\r\n";
			print $testFileHandle "1750IMU ?acceltype Test Passed $result\r\n";
			return 1;
		} else {
			print "1750 IMU ?acceltype Test \t\t\tFailed, acceltype = $result\r\n";
			print $csvFileHandle "1750IMU ?acceltype Test,Failed\r\n";
			print $testFileHandle "1750IMU ?acceltype Test Failed $result\r\n";
			return 0;
		}
    }

    return 1;

} # TestAccelTypeGet


############################################################################
#  TestFC20CustomCommand
#
#  Description: Fc20 command - used to set the custom filter coefficients
#
#       Inputs: $portTest         - comport device is on
#               $fcSensorType     - Sensor type to reset - accel(a) or gyro (g)
#               $csvFileHandle    - file handle to write csv test results
#               $testFileHandle    - file handle to write test test results
#
#      Returns: Success or Failure - 0 or 1
#
# Side Effects: None
#
#        Notes: TODO:
#
############################################################################
sub TestFC20CustomCommand
{
    my $portTest      = shift;
    my $fcSensorType  = shift;
    my $csvFileHandle = shift;
    my $testFileHandle = shift;
    my $commandStatus = "";

    my $subSuccess    = 1;  # we will report the status for consistency,

    if ($fcSensorType eq "a") {
        $commandStatus = "$FC20_A_CUSTOM_COMMAND";
    } else {
        $commandStatus = "$FC20_G_CUSTOM_COMMAND";
    }

    $portTest->write($commandStatus."\n");
    select(undef, undef, undef, 0.50);  # sleep 1/4 second 250 milliseconds

    my $result = $portTest->input;
    print "fc20 get result = $result";
    print $testFileHandle "fc20 get result = $result";

    # test for Accels cheby
    if ($fcSensorType eq "a") {
        print "fc20 accel custom test \t\t\tPassed\r\n\r\n";
        print $csvFileHandle "fc20 accel custom test,Passed\r\n";
        print $testFileHandle "fc20 accel custom test, Passed\r\n";
        $subSuccess  = 1;
    } else { # check the gyros
        print "fc20 gyro custom test \t\t\tPassed\r\n\r\n";
        print $csvFileHandle "fc20 gyro custom test,Passed\r\n";
        print $testFileHandle "fc20 gyro custom test, Passed\r\n";
        $subSuccess  = 1;
    }
    return $subSuccess;

} # end of TestFC20CustomCommand

############################################################################
#  TestFC20Command
#
#  Description: Fc20 command - used to get the filter coefficients
#
#       Inputs: $portTest         - comport device is on
#               $fcSensorType     - Sensor type to reset - accel(a) or gyro (g)
#               $fcFilterType     - cheby, butterworth, or average filter types
#               $csvFileHandle    - file handle to write csv test results
#               $testFileHandle    - file handle to write csv test results
#
#      Returns: Success or Failure - 0 or 1
#
# Side Effects: None
#
#        Notes: None
#
############################################################################
sub TestFC20Command
{
    my $portTest      = shift;
    my $fcSensorType  = shift;
    my $fcFilterType  = shift;
    my $csvFileHandle = shift;
    my $testFileHandle = shift;


    my $subSuccess    = 1;

    my $commandStatus = "?fc20,$fcSensorType";
    $portTest->write($commandStatus."\n");
    select(undef, undef, undef, 0.25);  # sleep 1/4 second 250 milliseconds

    my $result = $portTest->input;
    print "fc20 get result = $result";
    print "fc20 $commandStatus,$fcFilterType\r\n";
    print $testFileHandle "fc20 get result = $result";
    print $testFileHandle "fc20 $commandStatus,$fcFilterType\r\n";

    # test for Accels cheby
    if ($fcSensorType eq "a") {

        if ($fcFilterType eq "cheby") {
            if ( $result eq $FC20_A_CHEBY ) {
                print "fc20 accel cheby test \t\t\tPassed\r\n\r\n";
                print $csvFileHandle "fc20 accel cheby Test,Passed\r\n";
                print $testFileHandle "fc20 accel cheby Test, Passed\r\n";
            } else {
                print "fc20 accel cheby test \t\t\tFailed\r\n";
                print $csvFileHandle "fc20 accel cheby Test,Failed\r\n";
                print $testFileHandle "fc20 accel cheby Test, Failed\r\n";
                $subSuccess = 0;
            }
        } elsif ($fcFilterType eq "butter")  { # end of if ($fcFilterType eq "cheby")
            if( $result eq $FC20_A_BUTTER ) {
                print "fc20 accel butter test \t\t\tPassed\r\n\r\n";
                print $csvFileHandle "fc20 accel butter Test,Passed\r\n";
                print $testFileHandle "fc20 accel butter Test, Passed\r\n";
            } else {
                print "fc20 accel butter test \t\t\tFailed\r\n";
                print $csvFileHandle "fc20 accel butter Test,Failed\r\n";
                print $testFileHandle "fc20 accel butter Test, Failed\r\n";
                $subSuccess = 0;
            }
        } else {
            print "fc20 accel test \t\t\tFailed\r\n";
            print $csvFileHandle "fc20 accel Test,Failed\r\n";
            print $testFileHandle "fc20 accel Test, Failed\r\n";
            $subSuccess = 0;
      }
    # check the gyros
    } else {
        if ($fcFilterType eq "cheby") {
            if( $result eq $FC20_G_CHEBY ) {
                print "fc20 gyro cheby test \t\t\tPassed\r\n\r\n";
                print $csvFileHandle "fc20 Gyro Cheby Test,Passed\r\n";
                print $testFileHandle "fc20 Gyro Cheby Test, Passed\r\n";
            } else {
                print "fc20 gyro cheby test \t\t\tFailed\r\n";
                print $csvFileHandle "fc20 Gyro Cheby Test,Failed\r\n";
                print $testFileHandle "fc20 Gyro Cheby Test, Failed\r\n";
                $subSuccess = 0;
            }
        } elsif ($fcFilterType eq "butter")  {# end of if ($fcFilterType eq "cheby")
            if( $result eq $FC20_G_BUTTER ) {
                print "fc20 gyro butter test \t\t\tPassed\r\n\r\n";
                print $csvFileHandle "fc20 Gyro Butter Test,Passed\r\n";
                print $testFileHandle "fc20 Gyro Butter Test, Passed\r\n";
            } else {
                print "fc20 gyro butter test \t\t\tFailed\r\n";
                print $csvFileHandle "fc20 Gyro Butter Test,Failed\r\n";
                print $testFileHandle "fc20 Gyro Butter Test, Failed\r\n";
                $subSuccess = 0;
            }
        } else {
            print "fc20 gyro test \t\t\tFailed\r\n";
            print $csvFileHandle "fc20 gyro Test,Failed\r\n";
            print $testFileHandle "fc20 gyro Test, Failed\r\n";
            $subSuccess = 0;
        } # end of else of if ($fcFilterType eq "cheby")

    } # end of else of if ($fcSensorType eq "a")

    return $subSuccess;

} # end of TestFC20Command


############################################################################
#  TestFC20ResetCommand
#
#  Description: Fc20 command using reset as a parameter
#
#       Inputs: $portTest         - comport device is on
#               $fcSensorType     - Sensor type to reset - accel(a) or gyro (g)
#               $csvFileHandle    - file handle to write csv test results
#               $testFileHandle    - file handle to write test test results
#
#      Returns: Success or Failure - 0 or 1
#
# Side Effects: None
#
#        Notes: None
#
############################################################################
sub TestFC20ResetCommand
{
    my $portTest      = shift;
    my $fcSensorType  = shift;
    my $csvFileHandle = shift;
    my $testFileHandle = shift;
    my $subSuccess    = 1;

    my $commandStatus = "=fc20,$fcSensorType,reset";
    $portTest->write($commandStatus."\n");
    select(undef, undef, undef, 0.75);  # sleep 1/4 second 250 milliseconds

    my $result = $portTest->input;
    print "\r\nfc20 reset get result = $result";
    print "\r\nfc20 reset $commandStatus\r\n";
    print $testFileHandle "\r\nfc20 reset get result = $result";
    print $testFileHandle "\r\nfc20 reset $commandStatus\r\n";

    # test for Accels cheby
    if ($fcSensorType eq "a") {
        if ( $result eq $FC20_A_CHEBY ) {
            print "fc20 accel reset test \t\t\tPassed\r\n\r\n";
            print $csvFileHandle "fc20 accel reset Test,Passed\r\n";
            print $testFileHandle "fc20 accel reset Test, Passed\r\n";
        } else {
            print "fc20 accel reset test \t\t\tFailed\r\n";
            print $csvFileHandle "fc20 reset butter Test,Failed\r\n";
            print $testFileHandle "fc20 reset butter Test, Failed\r\n";
            $subSuccess = 0;
        }
    # check the gyros
    } else {
        if ( $result eq $FC20_G_CHEBY ) {
            print "fc20 gyro reset test \t\t\tPassed\r\n\r\n";
            print $csvFileHandle "fc20 gyro reset Test,Passed\r\n";
            print $testFileHandle "fc20 gyro reset Test, Passed\r\n";
        } else {
            print "fc20 gyro reset test \t\t\tFailed\r\n";
            print $csvFileHandle "fc20 gyro reset Test,Failed\r\n";
            print $testFileHandle "fc20 gyro reset Test, Failed\r\n";
            $subSuccess = 0;
        }
    }
    return $subSuccess;
} # end of TestFC20ResetCommand

############################################################################
#  TestFiltTypeSequence
#
#  Description: Test filttype command
#
#       Inputs: $portTest         - comport device is on
#               $csvFileHandle    - file handle to write csv test results
#               $testFileHandle   - file handle to write txt test results
#               $deviceName       - the device name running the test on
#
#      Returns: Success or Failure - 0 or 1
#
# Side Effects: None
#
#        Notes: None
#
############################################################################
sub TestFiltTypeSequence
{
    my $portTest       = shift;
    my $csvFileHandle  = shift;
    my $testFileHandle = shift;
    my $deviceName     = shift;

    my $subSuccess    = 1;

    # filttype a butter
    my $command = "=filttype,a,butter";
    $portTest->write($command."\n");

    select(undef, undef, undef, 0.25);  # sleep 1/4 second 250 milliseconds
    my $result = $portTest->input;
    print "?Filttype result = $result";
    print $testFileHandle "?Filttype result = $result";

    if( $result eq "FILTTYPE,A,BUTTER\r\n" ) {
        print "filttype,a,butter test \t\t\tPassed\r\n\r\n";
        print $csvFileHandle "filttype accel butter,Passed\r\n";
        print $testFileHandle "filttype accel butter, Passed\r\n";
    } else {
        print "filttype,a,butter test \t\t\tFailed\r\n";
        print $csvFileHandle "filttype accel butter,Failed\r\n";
        print $testFileHandle "filttype accel butter, Failed\r\n";
        $subSuccess = 0;
    }

    # filttype a cheby
    $command = "=filttype,a,cheby";
    $portTest->write($command."\n");
    select(undef, undef, undef, 0.25);  # sleep 1/4 second 250 milliseconds
    $result = $portTest->input;
    print "?Filttype result = $result";
    print $testFileHandle "?Filttype result = $result";
    if( $result eq "FILTTYPE,A,CHEBY\r\n" ) {
        print "filttype,a,cheby test \t\t\tPassed\r\n\r\n";
        print $csvFileHandle "filttype accel cheby,Passed\r\n";
        print $testFileHandle "filttype accel cheby, Passed\r\n";
    } else {
        print "filttype,a,cheby test \t\t\tFailed\r\n";
        print $csvFileHandle "filttype accel cheby,Failed\r\n";
        print $testFileHandle "filttype accel cheby, Failed\r\n";
        $subSuccess = 0;
    }

    # filttype g butter
    $command = "=filttype,g,butter";
    $portTest->write($command."\n");
    select(undef, undef, undef, 0.25);  # sleep 1/4 second 250 milliseconds
    $result = $portTest->input;
    print "?Filttype result = $result";
    print $testFileHandle "?Filttype result = $result";
    if( $result eq "FILTTYPE,G,BUTTER\r\n" ) {
        print "filttype,g,butter test \t\t\tPassed\r\n\r\n";
        print $csvFileHandle "filttype gyro butter,Passed\r\n";
        print $testFileHandle "filttype gyro butter, Passed\r\n";
    } else {
        print "filttype,g,butter test \t\t\tFailed\r\n";
        print $csvFileHandle "filttype gyro butter,Failed\r\n";
        print $testFileHandle "filttype gyro butter, Failed\r\n";
        $subSuccess = 0;
    }

    # filttype g cheby
    $command = "=filttype,g,cheby";
    $portTest->write($command."\n");
    select(undef, undef, undef, 0.25);  # sleep 1/4 second 250 milliseconds
    $result = $portTest->input;
    print "?Filttype result = $result";
    print $testFileHandle "?Filttype result = $result";
    if( $result eq "FILTTYPE,G,CHEBY\r\n" ) {
        print "filttype,g,cheby test \t\t\tPassed\r\n\r\n";
        print $csvFileHandle "filttype gyro cheby,Passed\r\n";
        print $testFileHandle "filttype gyro cheby, Passed\r\n";
    } else {
        print "filttype,g,cheby test \t\t\tFailed\r\n";
        print $csvFileHandle "filttype gyro cheby,Failed\r\n";
        print $testFileHandle "filttype gyro cheby, Failed\r\n";
        $subSuccess = 0;
    }

    if ((index($deviceName,'1775') != -1) || (index($deviceName,'DSPU') != -1)){
        TestFtNegativeTest1775($portTest,$csvFileHandle,$testFileHandle);
    } else {
        TestFiltTypeNegativeTest($portTest,$csvFileHandle,$testFileHandle,$deviceName);
    }

    return $subSuccess;
} # end of TestFiltTypeSequence

############################################################################
#  TestFilterTypeSet
#
#  Description: Test Filter Type Set
#
#       Inputs: $portTest         - comport device is on
#               $sensorType       - the sensor we wish to set
#               $filtertype       - the filter type we wish to set
#               $csvFileHandle    - file handle to write csv test results
#               $testFileHandle    - file handle to write txt test results
#
#      Returns: Success or Failure - 0 or 1
#
# Side Effects: None
#
#        Notes: None
#
############################################################################
sub TestFilterTypeSet
{
    my $portTest      = shift;
    my $sensorType    = shift;
    my $filterType    = shift;
    my $csvFileHandle = shift;
    my $testFileHandle = shift;
    my $sensorTypeUpperCase = uc$sensorType;
    my $filterTypeUpperCase = uc$filterType;

    #set the configuration
    my $commandStatus = "=filttype,$sensorType,$filterType";
    $portTest->write($commandStatus."\n");
    select(undef, undef, undef, 0.25);  # sleep 1/4 second 250 milliseconds

    my $result = $portTest->input;
	$result =~ s/\r|\n//g;
    print "filttype result = $result\r\n";
    print "filttype command = $commandStatus\r\n";
    print $testFileHandle "filttype result = $result";
    print $testFileHandle "filttype command  = $commandStatus\r\n";
	if (index($result,"FILTTYPE,$sensorTypeUpperCase,$filterTypeUpperCase") != -1) {
        print "filttype set test \t\t\tPassed\r\n\r\n";
        print $testFileHandle "Filttype Set $sensorType $filterType, Passed\r\n";
		$filterType =~ s/,/_/g;
		print $csvFileHandle "Filttype Set $sensorType $filterType,Passed\r\n";
        return 1;
    } else {
        print "filttype set test \t\t\tFailed\r\n";
        print $testFileHandle "Filttype Set $sensorType $filterType, Failed\r\n";
		$filterType =~ s/,/_/g;
		print $csvFileHandle "Filttype Set $sensorType $filterType,Failed\r\n";
        return 0;
    }
} # end of TestFilterTypeSet

############################################################################
#  TestFilterTypeGet
#
#  Description: Test Filter Type Get
#
#       Inputs: $portTest         - comport device is on
#               $sensorType       - the sensor we wish to query,
#               $filterType       - the filter type we wish to query
#               $csvFileHandle    - file handle to write csv test results
#               $testFileHandle    - file handle to write txt test results
#
#      Returns: Success or Failure - 0 or 1
#
# Side Effects: None
#
#        Notes: None
#
############################################################################
sub TestFilterTypeGet
{
    my $portTest      = shift;
    my $sensorType    = shift;
    my $filterType    = shift;
    my $csvFileHandle = shift;
    my $testFileHandle = shift;
    my $sensorTypeUpperCase = uc$sensorType;
    my $filterTypeUpperCase = uc$filterType;

    #get the configuration
    my $commandStatus = "?filttype,$sensorType";
    $portTest->write($commandStatus."\n");
    select(undef, undef, undef, 0.25);  # sleep 1/4 second 250 milliseconds

    my $result = $portTest->input;
    print "filttype result = $result";
    print "filttype command  = $commandStatus\r\n";
    print $testFileHandle "filttype result = $result";
    print $testFileHandle "filttype command  = $commandStatus\r\n";

    if (index($result,"FILTTYPE,$sensorTypeUpperCase,$filterTypeUpperCase") != -1) {
        print "filttype get test \t\t\tPassed\r\n\r\n";
        print $csvFileHandle "Filttype Get $sensorType $filterType,Passed\r\n";
        print $testFileHandle "Filttype Get $sensorType $filterType, Passed\r\n";
        return $SUCCESS;
    } else {
        print "filttype get test \t\t\tFailed\r\n";
        print $csvFileHandle "Filttype Get $sensorType $filterType,Failed\r\n";
        print $testFileHandle "Filttype Get $sensorType $filterType, Failed\r\n";
        return $FAILED;
    }

} # end of TestFilterTypeGet

############################################################################
#  EchoCommand
#
#  Description: Process Echo command
#
#       Inputs: $portTest         - comport device is on
#               $querySetType     - Whether we are quering or setting a value
#               $dataType         - The data that is being sent in a set command
#               $expectedResult   - The expected result from the command
#               $csvFileHandle    - file handle to write csv test results
#               $testFileHandle    - file handle to write txt test results
#
#      Returns: Success or Failure - 0 or 1
#
# Side Effects: None
#
#        Notes: None
#
############################################################################
sub EchoCommand
{
    my $portTest       = shift;
    my $querySetType   = shift;
    my $dataType       = shift;
    my $expectedResult = shift;
    my $csvFileHandle  = shift;
    my $testFileHandle  = shift;
    my $echoString = "echo";
    my $commandStatus;

    #set the configuration
    if ($dataType eq "NONE") {
        $commandStatus = $querySetType . $echoString;
    } else {
        $commandStatus = $querySetType . $echoString . $dataType;
    }

    $portTest->write($commandStatus."\n");
    select(undef, undef, undef, 0.25);  # sleep 1/4 second 250 milliseconds

    my $result = $portTest->input;
    print "echo result $result";
    print "echo command $commandStatus\r\n";
    print $testFileHandle "echo result $result";
    print $testFileHandle "echo command $commandStatus\r\n";

    if ($result eq "ECHO,$expectedResult\r\n") {
        print "ECHO get test \t\t\tPassed\r\n\r\n";
        print $csvFileHandle "Echo Get Test,Passed\r\n";
        print $testFileHandle "Echo Get Test, Passed\r\n";
        return 1;
    } else {
        print "ECHO get test \t\t\tFailed\r\n";
        print $csvFileHandle "Echo Get Test,Failed\r\n";
        print $testFileHandle "Echo Get Test, Failed\r\n";
        return 0;
    }
} # end of EchoCommand

############################################################################
#  StartupSetCommand
#
#  Description: Startup Set command - Sets the mode to startup the device in
#
#       Inputs: $portTest         - comport device is on
#               $csvFileHandle    - file handle to write csv test results
#               $testFileHandle    - file handle to write txt test results
#
#      Returns: Success or Failure - 0 or 1
#
# Side Effects: None
#
#        Notes: Not presently used in production, but used for testing the tester:)
#
############################################################################
sub StartupSetCommand
{
    my $portTest       = shift;
    my $fileHandle     = shift;
    my $csvFileHandle  = shift;
    my $testFileHandle  = shift;
    my $commandStatus = "=startup,debug";

    $portTest->write($commandStatus."\n");
    select(undef, undef, undef, 0.25);  # sleep 1/4 second 250 milliseconds

    my $result = $portTest->input;
    print "startup result = $result";
    print "startup command  = $commandStatus\r\n";
    print $testFileHandle "startup result = $result";
    print $testFileHandle "startup command  = $commandStatus\r\n";

    if( $result eq "STARTUP,DEBUG\r\n" ) {
        print "STARTUP get test \t\t\tPassed\r\n\r\n";
        print $csvFileHandle "STARTUP Get Test,Passed\r\n";
        print $testFileHandle "STARTUP Get Test, Passed\r\n";
        return 1;
    } else {
        print "STARTUP get test \t\t\tFailed\r\n";
        print $fileHandle "STARTUP get test \t\t\tFailed\r\n";
        print $csvFileHandle "STARTUP Get Test,Failed\r\n";
        print $testFileHandle "STARTUP Get Test, Failed\r\n";
        return 0;
    }
} # end of StartupSetCommand


################### 1750 - 1760 Filter Support ###################################
################### NOTE: DSP1760 and IRS variants have no accels ########################

##################################################################################
#  TestFCCustomCommand
#
#  Description: Fc command - used to set the custom filter coefficients
#
#       Inputs: $portTest         - comport device is on
#               $fcSensorType     - Sensor type to reset - accel(a) or gyro (g)
#               $csvFileHandle    - file handle to write csv test results
#               $testFileHandle    - file handle to write txt test results
#
#      Returns: Success or Failure - 0 or 1
#
# Side Effects: None
#
#        Notes: TODO:
#
############################################################################
sub TestFCCustomCommand
{
    my $portTest      = shift;
    my $fcSensorType  = shift;
    my $csvFileHandle = shift;
    my $testFileHandle = shift;
    my $commandStatus;

    my $subSuccess    = 1;  # we will report the status for consistency,

    if ($fcSensorType eq "a") {
        $commandStatus = "$FC_A_CUSTOM_COMMAND";
    } else {
        $commandStatus = "$FC_G_CUSTOM_COMMAND";
    }

    $portTest->write($commandStatus."\n");
    select(undef, undef, undef, 0.50);  # sleep 1/4 second 250 milliseconds

    my $result = $portTest->input;
    print "fc get result = $result";
    print $testFileHandle "fc get result = $result";

    # test for Accels cheby
    if ($fcSensorType eq "a") {
        print "fc accel custom test \t\t\tPassed\r\n\r\n";
        print $csvFileHandle "fc Accel custom test,Passed\r\n";
        print $testFileHandle "fc Accel custom test, Passed\r\n";
        $subSuccess  = 1;
    } else { # check the gyros
        print "fc gyro custom test \t\t\tPassed\r\n\r\n";
        print $csvFileHandle "fc Gyro custom test,Passed\r\n";
        print $testFileHandle "fc Gyro custom test, Passed\r\n";
        $subSuccess  = 1;
    }
    return $subSuccess;

} # end of TestFCCustomCommand

############################################################################
#  TestFCCommand
#
#  Description: Fc command - used to get the filter coefficients
#
#       Inputs: $portTest         - comport device is on
#               $fcSensorType     - Sensor type to reset - accel(a) or gyro (g)
#               $fcFilterType     - cheby, butterworth, or average filter types
#               $csvFileHandle    - file handle to write csv test results
#               $testFileHandle    - file handle to write txt test results
#
#      Returns: Success or Failure - 0 or 1
#
# Side Effects: None
#
#        Notes: None
#
############################################################################
sub TestFCCommand
{
    my $portTest      = shift;
    my $fcSensorType  = shift;
    my $fcFilterType  = shift;
    my $csvFileHandle = shift;
    my $testFileHandle = shift;
    my $subSuccess    = 1;

    print "fc command for the 1750 or 1725 or 1760 called \r\n";

    my $commandStatus = "?dr";
    $portTest->write($commandStatus."\n");
    select(undef, undef, undef, 0.25);  # sleep 1/4 second 250 milliseconds

    my $result = $portTest->input;
    print "fc dr result = $result";
    print "fc dr $commandStatus\r\n\r\n";

    $commandStatus = "?fc,$fcSensorType";
    $portTest->write($commandStatus."\n");
    select(undef, undef, undef, 0.25);  # sleep 1/4 second 250 milliseconds

    $result = $portTest->input;
    print "fc get result = $result";
    print "fc $commandStatus,$fcFilterType\r\n";
    print $testFileHandle "fc get result = $result";
    print $testFileHandle "fc $commandStatus,$fcFilterType\r\n";

    # test for Accels cheby
    if ($fcSensorType eq "a") {

        if ($fcFilterType eq "cheby") {
            if ( $result eq $FC_A_CHEBY ) {
                print "fc accel cheby test \t\t\tPassed\r\n\r\n";
                print $csvFileHandle "fc accel cheby Test,Passed\r\n";
                print $testFileHandle "fc accel cheby Test, Passed\r\n";
            } else {
                print "fc accel cheby test \t\t\tFailed\r\n";
                print $csvFileHandle "fc accel cheby Test,Failed\r\n";
                print $testFileHandle "fc accel cheby Test, Failed\r\n";
                $subSuccess = 0;
            }
        } elsif ($fcFilterType eq "butter")  { # end of if ($fcFilterType eq "cheby")
            if( $result eq $FC_A_BUTTER ) {
                print "fc accel butter test \t\t\tPassed\r\n\r\n";
                print $csvFileHandle "fc accel butter Test,Passed\r\n";
                print $testFileHandle "fc accel butter Test, Passed\r\n";
            } else {
                print "fc accel butter test \t\t\tFailed\r\n";
                print $csvFileHandle "fc accel butter Test,Failed\r\n";
                print $testFileHandle "fc accel butter Test, Failed\r\n";
                $subSuccess = 0;
            }
        } else {
            print "fc accel test \t\t\tFailed\r\n";
            print $csvFileHandle "fc accel Test,Failed\r\n";
            print $testFileHandle "fc accel Test, Failed\r\n";
            $subSuccess = 0;
      }
    # check the gyros
    } else {
        if ($fcFilterType eq "cheby") {
            if( $result eq $FC_G_CHEBY ) {
                print "fc gyro cheby test \t\t\tPassed\r\n\r\n";
                print $csvFileHandle "fc Gyro Cheby Test,Passed\r\n";
                print $testFileHandle "fc Gyro Cheby Test, Passed\r\n";
            } else {
                print "fc gyro cheby test \t\t\tFailed\r\n";
                print $csvFileHandle "fc Gyro Cheby Test, Failed\r\n";
                print $testFileHandle "fc Gyro Cheby Test,Failed\r\n";
                $subSuccess = 0;
            }
        } elsif ($fcFilterType eq "butter")  {# end of if ($fcFilterType eq "cheby")
            if( $result eq $FC_G_BUTTER ) {
                print "fc gyro butter test \t\t\tPassed\r\n\r\n";
                print $csvFileHandle "fc Gyro Butter Test,Passed\r\n";
                print $testFileHandle "fc Gyro Butter Test, Passed\r\n";
            } else {
                print "fc gyro butter test \t\t\tFailed\r\n";
                print $csvFileHandle "fc Gyro Butter Test,Failed\r\n";
                print $testFileHandle "fc Gyro Butter Test, Failed\r\n";
                $subSuccess = 0;
            }
        } else {
            print "fc gyro test \t\t\tFailed\r\n";
            print $csvFileHandle "fc gyro Test,Failed\r\n";
            print $testFileHandle "fc gyro Test, Failed\r\n";
            $subSuccess = 0;
        } # end of else of if ($fcFilterType eq "cheby")

    } # end of else of if ($fcSensorType eq "a")

    return $subSuccess;

} # end of TestFCCommand

############################################################################
#  TestFCResetCommand
#
#  Description: Fc command using reset as a parameter
#
#       Inputs: $portTest         - comport device is on
#               $fcSensorType     - Sensor type to reset - accel(a) or gyro (g)
#               $csvFileHandle    - file handle to write csv test results
#               $testFileHandle    - file handle to write csv test results
#
#      Returns: Success or Failure - 0 or 1
#
# Side Effects: None
#
#        Notes: None
#
############################################################################
sub TestFCResetCommand
{
    my $portTest      = shift;
    my $fcSensorType  = shift;
    my $csvFileHandle = shift;
    my $testFileHandle = shift;
    my $subSuccess    = 1;

    my $commandStatus = "=fc,$fcSensorType,reset";
    $portTest->write($commandStatus."\n");
    select(undef, undef, undef, 0.75);  # sleep 1/4 second 250 milliseconds

    my $result = $portTest->input;
    print "\r\nfc reset get result = $result";
    print "\r\nfc reset $commandStatus\r\n";
    print $testFileHandle "fc reset get result = $result";
    print $testFileHandle "fc reset $commandStatus\r\n";

    # test for Accels cheby
    if ($fcSensorType eq "a") {
        if ( $result eq $FC_A_CHEBY ) {
            print "fc accel reset test \t\t\tPassed\r\n\r\n";
            print $csvFileHandle "fc accel reset Test,Passed\r\n";
            print $testFileHandle "fc accel reset Test, Passed\r\n";
        } else {
            print "fc accel reset test \t\t\tFailed\r\n";
            print $csvFileHandle "fc reset butter Test,Failed\r\n";
            print $testFileHandle "fc reset butter Test, Failed\r\n";
            $subSuccess = 0;
        }
    # check the gyros
    } else {
        if ( $result eq $FC_G_CHEBY ) {
            print "fc gyro reset test \t\t\tPassed\r\n\r\n";
            print $csvFileHandle "fc gyro reset Test,Passed\r\n";
            print $testFileHandle "fc gyro reset Test, Passed\r\n";
        } else {
            print "fc gyro reset test \t\t\tFailed\r\n";
            print $csvFileHandle "fc gyro reset Test,Failed\r\n";
            print $testFileHandle "fc gyro reset Test, Failed\r\n";
            $subSuccess = 0;
        }
    }
    return $subSuccess;
} # end of TestFCResetCommand


############################################################################
#  TestSelfTestCommand
#
#  Description: Test Self Test Command
#
#       Inputs: $portTest         - comport device is on
#               $csvFileHandle    - file handle to write csv test results
#               $testFileHandle    - file handle to write txt test results
#
#      Returns: Success or Failure - 1 or 0
#
# Side Effects: None
#
#        Notes: None
#
############################################################################
sub TestSelfTestCommand
{
    my $portTest      = shift;
    my $csvFileHandle = shift;
    my $testFileHandle = shift;

    my $testStatus   = $SUCCESS;

    #set the configuration
    my $commandStatus = "?selftest";
    $portTest->write($commandStatus."\n");

    sleep 10;

    my $result = $portTest->input;
    print "TestSelfTestCommand result = $result";
    print "TestSelfTestCommand command  = $commandStatus\r\n";
    print $testFileHandle "TestSelfTestCommand result = $result";
    print $testFileHandle "TestSelfTestCommand command  = $commandStatus\r\n";

    sleep 5;
    $portTest->purge_rx;

    if ( (index($result,'BIT will take some time') != -1)) {
        if ((index($result,'SELFTEST failed')  != -1)) {
            print "TestSelfTestCommand get test \t\t\tFailed\r\n";
            print $csvFileHandle "TestSelfTestCommand,Failed\r\n";
            print $testFileHandle "TestSelfTestCommand, Failed\r\n";
            $testStatus   = $FAILED;
        } else {

            print "TestSelfTestCommand \t\t\tPassed\r\n\r\n";
            print $csvFileHandle "TestSelfTestCommand,Passed\r\n";
            print $testFileHandle "TestSelfTestCommand, Passed\r\n";
            $testStatus   = $SUCCESS;
        }
    } else {
        print "TestSelfTestCommand get test \t\t\tFailed\r\n";
        print $csvFileHandle "TestSelfTestCommand,Failed\r\n";
        print $testFileHandle "TestSelfTestCommand, Failed\r\n";
        $testStatus   = $FAILED;
    }
    return $testStatus;
} # end of TestSelfTestCommand


############################################################################
#  TestBaudGetCommand
#
#  Description: Test Baud Get Command
#
#       Inputs: $portTest         - comport device is on
#               $csvFileHandle    - file handle to write csv test results
#               $testFileHandle    - file handle to write txt test results
#
#      Returns: Success or Failure - 1 or 0
#
# Side Effects: None
#
#        Notes: None
#
############################################################################
sub TestBaudGetCommand
{
    my $portTest      = shift;
    my $csvFileHandle = shift;
    my $testFileHandle = shift;

    my $testStatus   = $SUCCESS;

    # get the baud
    my $commandStatus = "?baud";
    $portTest->write($commandStatus."\n");

    sleep 1;

    my $result = $portTest->input;
    print "TestBaudGetCommand result = $result";
    print "TestBaudGetCommand command  = $commandStatus\r\n";
    print $testFileHandle "TestBaudGetCommand result = $result";
    print $testFileHandle "TestBaudGetCommand command  = $commandStatus\r\n";

    if ( (index($result,'BAUD') != -1)) {
        print "TestBaudGetCommand \t\t\tPassed\r\n\r\n";
        print $csvFileHandle "TestBaudGetCommand,Passed\r\n";
        print $testFileHandle "TestBaudGetCommand, Passed\r\n";
        $testStatus   = $SUCCESS;
    } else {
        print "TestBaudGetCommand \t\t\tFailed\r\n";
        print $csvFileHandle "TestBaudGetCommand,Failed\r\n";
        print $testFileHandle "TestBaudGetCommand, Failed\r\n";
        $testStatus   = $FAILED;
    }
    return $testStatus;
} # end of TestBaudGetCommand



############################################################################
#  TestBaudSetCommand
#
#  Description: Test Baud Set Command
#
#       Inputs: $portTest         - comport device is on
#               $csvFileHandle    - file handle to write csv test results
#               $testFileHandle    - file handle to write txt test results
#
#      Returns: Success or Failure - 1 or 0
#
# Side Effects: None
#
#        Notes: None
#
############################################################################
sub TestBaudSetCommand
{
    my $portTest      = shift;
    my $csvFileHandle = shift;
    my $testFileHandle = shift;
    my $baudValue = 115200; # shift;

    my $testStatus   = $SUCCESS;

    #set the configuration
    my $commandStatus = "=baud,$baudValue";
    $portTest->write($commandStatus."\n");

    $portTest->databits(8);
    $portTest->baudrate($baudValue);
    $portTest->parity("none");
    $portTest->stopbits(1);
    $portTest->handshake("none");
    $portTest->buffers(4096, 4096);

    $portTest->write_settings || undef $port;
    $portTest->save($comPortConfigFile);

    sleep 1;
    $portTest->restart($comPortConfigFile);

    sleep 2;

    $testStatus = TestBaudGetCommand($port,$testCsvFileHandle,$testFileHandle);

    if ($testStatus == $SUCCESS) {
        print "TestBaudSetCommand \t\t\tPassed\r\n\r\n";
        print $csvFileHandle "TestBaudSetCommand,Passed\r\n";
        print $testFileHandle "TestBaudSetCommand, Passed\r\n";
        $testStatus   = $SUCCESS;
    } else {
        print "TestBaudSetCommand \t\t\tFailed\r\n";
        print $csvFileHandle "TestBaudSetCommand,Failed\r\n";
        print $testFileHandle "TestBaudSetCommand, Failed\r\n";
        $testStatus   = $FAILED;
    }

    # start a negative test by using an incorrect baud
    #set the configuration
    $commandStatus = "=baud,0";
    $portTest->write($commandStatus."\n");

    sleep 1;

    my $result = $portTest->input;
    print "TestBaudSetCommand negative test result = $result";
    print "TestBaudSetCommand command  = $commandStatus\r\n";
    print $testFileHandle "TestBaudSetCommand Baud = 0 negative test  result = $result";
    print $testFileHandle "TestBaudSetCommand command negative test = $commandStatus\r\n";

    if ( (index($result,'INVALID BAUD') != -1)) {
        print "TestBaudSetCommand negative test\t\t\tPassed\r\n\r\n";
        print $csvFileHandle "TestBaudSetCommand Baud = 0 Negative Test,Passed\r\n";
        print $testFileHandle "TestBaudSetCommand Baud = 0 Negative Test, Passed\r\n";
        $testStatus   = $SUCCESS;
    } else {
        print "TestBaudSetCommand \t\t\tFailed\r\n";
        print $csvFileHandle "TestBaudSetCommand Baud = 0 Negative Test,Failed\r\n";
        print $testFileHandle "TestBaudSetCommand Baud = 0 Negative Test, Failed\r\n";
        $testStatus   = $FAILED;
    }


    if ( ($deviceName ne "1775IMU") && ($deviceName ne "1760DSPU1") && ($deviceName ne "1760DSPU2") && ($deviceName ne "1760DSPU3") )  {
        # start a negative test by using an 4147200 baud for a non-1775
        #set the configuration
        $commandStatus = "=baud,4147200";
        $portTest->write($commandStatus."\n");

        sleep 1;

        my $result = $portTest->input;
        print "TestBaudSetCommand negative test result = $result";
        print "TestBaudSetCommand command  = $commandStatus\r\n";
        print $testFileHandle "TestBaudSetCommand Baud = 4147200 Non Device Baud negative test  result = $result";
        print $testFileHandle "TestBaudSetCommand command  negative test = $commandStatus\r\n";

        if ( (index($result,'INVALID BAUD') != -1)) {
            print "TestBaudSetCommand negative test\t\t\tPassed\r\n\r\n";
            print $csvFileHandle "TestBaudSetCommand Baud = 4147200 Non Device Baud Negative Test,Passed\r\n";
            print $testFileHandle "TestBaudSetCommand Baud = 4147200 Non Device Baud Negative Test, Passed\r\n";
            $testStatus   = $SUCCESS;
        } else {
            print "TestBaudSetCommand \t\t\tFailed\r\n";
            print $csvFileHandle "TestBaudSetCommand Baud = 4147200 Non Device Baud Negative Test,Failed\r\n";
            print $testFileHandle "TestBaudSetCommand Baud = 4147200 Non Device Baud Negative Test, Failed\r\n";
            $testStatus   = $FAILED;
        }
    }


    # restore the configuration
    sleep 3;
    print "TestBaudSetCommand restore 921600 baud\r\n";
    $baudValue = 921600;
    $commandStatus = "=baud,921600";
    $portTest->write($commandStatus."\n");

    $portTest->databits(8);
    $portTest->baudrate(921600);
    $portTest->parity("none");
    $portTest->stopbits(1);
    $portTest->handshake("none");
    $portTest->buffers(4096, 4096);

    $portTest->write_settings || undef $port;
    $portTest->save($comPortConfigFile);

    sleep 2;
    $portTest->restart($comPortConfigFile);

    sleep 3;

    $testStatus = TestBaudGetCommand($port,$testCsvFileHandle,$testFileHandle);

    return $testStatus;
} # end of TestBaudSetCommand


############################################################################
#  TestMagOffsetCommand
#
#  Description: Test Baud Command
#
#       Inputs: $portTest         - comport device is on
#               $csvFileHandle    - file handle to write csv test results
#               $testFileHandle    - file handle to write txt test results
#
#      Returns: Success or Failure - 1 or 0
#
# Side Effects: None
#
#        Notes: None
#
############################################################################
sub TestMagOffsetCommand
{
    my $portTest       = shift;
    my $csvFileHandle  = shift;
    my $testFileHandle = shift;
    my $modeStatus     = shift;


    my $testStatus   = $SUCCESS;
    my $magOffsetString;
    my @origMagOffsetValues;
    my @magOffsetValues;
    my $arraySize;
    my $generalStatus;
    my $indexCount;

    # query the mag offset values and save them off to reload later
    my $commandStatus = "?magoffset,icb";
    $portTest->write($commandStatus."\n");
    sleep 1;
    my $result = $portTest->input;
    print "TestMagOffsetCommand result = $result modeStatus = $modeStatus\r\n";
    print "TestMagOffsetCommand command  = $commandStatus\r\n";
    print $testFileHandle "TestMagOffsetCommand result = $result";
    print $testFileHandle "TestMagOffsetCommand command  = $commandStatus\r\n";

    if ((index($result,'MAG OFFSET') != -1)) {

        # remove the carriage return line feed;
        $result =~ s/\r|\n//g;
        @origMagOffsetValues = split(' ', $result);

        $arraySize = @origMagOffsetValues;
        print "size of array: $arraySize.\n";
    } else {
        $testStatus   = $FAILED;
    }

    # now set new canned values
    $commandStatus = "=magoffset,icb,0.1,0.2,0.3";
    $portTest->write($commandStatus."\n");
     sleep 1;
    $result = $portTest->input;
    print "write canned magoffset result = $result.\r\n";

    print "RESETTING Device in Mag Offset\n";
    print $testFileHandle "TestMagOffsetCommand, RESETTING Device\r\n";

    # read them back and verify correctness
    $commandStatus = "?magoffset,icb";
    $portTest->write($commandStatus."\n");
    sleep 1;
    $result = $portTest->input;
    print "read canned magoffset result = $result.\r\n";

    if ((index($result,'MAG OFFSET') != -1)) {
        # remove the carriage return line feed;
        $result =~ s/\r|\n//g;
        @magOffsetValues = split(' ', $result);

        $arraySize = @magOffsetValues;
        print "size of array: $arraySize.\n";

        # check the cannned values for validity
        if (($magOffsetValues[4] != 1.0) || ($magOffsetValues[5] != 2.0) || ($magOffsetValues[6] != 3.0) ) {
            $testStatus   = $FAILED;
        }
    } else {
        $testStatus   = $FAILED;
    }

    # restore the originals
    $commandStatus = "=magoffset,icb," . $origMagOffsetValues[4] . "," . $origMagOffsetValues[5] . "," . $origMagOffsetValues[6];
    $portTest->write($commandStatus."\n");
    sleep 1;
    $result = $portTest->input;
    print "write original magoffset result = $result.\r\n";

    if ((index($result,'MAG OFFSET') != -1)) {
        print "read original magoffset result = $result.\r\n";

        # remove the carriage return line feed;
        $result =~ s/\r|\n//g;
        @magOffsetValues = split(' ', $result);

        $arraySize = @magOffsetValues;
        print "size of array: $arraySize.\n";
    }

    if ( (index($result,'MAG OFFSET ICB') != -1)) {
        print "TestMagOffsetCommand \t\t\tPassed $result\r\n\r\n";
        print $csvFileHandle "TestMagOffsetCommand,Passed\r\n";
        print $testFileHandle "TestMagOffsetCommand, Passed, $result\r\n\r\n";
        $testStatus   = $SUCCESS;
    } else {
        print "TestMagOffsetCommand \t\t\tFailed\r\n";
        print $csvFileHandle "TestMagOffsetCommand,Failed\r\n";
        print $testFileHandle "TestMagOffsetCommand, Failed\r\n\r\n";
        $testStatus   = $FAILED;
    }
    return $testStatus;
} # end of TestMagOffsetCommand


############################################################################
#  TestDataRateSetCommand
#
#  Description: Test Data Rate Set Command
#
#       Inputs: $portTest         - comport device is on
#               $csvFileHandle    - file handle to write csv test results
#               $testFileHandle    - file handle to write txt test results
#
#      Returns: Success or Failure - 1 or 0
#
# Side Effects: None
#
#        Notes: None
#
############################################################################
sub TestDataRateSetCommand
{
    my $portTest      = shift;
    my $csvFileHandle = shift;
    my $testFileHandle = shift;
	my $counter = 0;
	my $data = 0;
    my $testStatus   = $SUCCESS;

    # set the data rate
    my $commandStatus = "=dr,0";
    $portTest->write($commandStatus."\n");

    sleep 1;

    my $result = $portTest->input;
	$result =~ s/\r|\n//g;
    print "TestDataRateSetCommand command  = $commandStatus\r\n";
    print "TestDataRateSetCommand result = $result";
    print $testFileHandle "TestDataRateSetCommand command  = $commandStatus\r\n";
    print $testFileHandle "TestDataRateSetCommand result = $result\r\n\r\n";

    if ( (index($result,'INVALID,DR') != -1)) {
        print "TestDataRateSetCommand \t\t\tPassed\r\n\r\n";
		print $csvFileHandle "TestDataRateSetCommand,Passed\r\n";
        print $testFileHandle "TestDataRateSetCommand, Passed, $commandStatus, $result \r\n\r\n";
        $testStatus   = $SUCCESS;
    } else {
        print "TestDataRateSetCommand \t\t\tFailed\r\n";
		print $csvFileHandle "TestDataRateSetCommand,Failed\r\n";
        print $testFileHandle "TestDataRateSetCommand, Failed, $commandStatus, $result\r\n\r\n";
        $testStatus   = $FAILED;
    }

    # set the data rate
    $commandStatus = "=dr,6000";
    $portTest->write($commandStatus."\n");
    sleep 1;

    $result = $portTest->input;
	$result =~ s/\r|\n//g;
    print "TestDataRateSetCommand command  = $commandStatus\r\n";
    print "TestDataRateSetCommand result = $result";
    print $testFileHandle "TestDataRateSetCommand command  = $commandStatus\r\n";
    print $testFileHandle "TestDataRateSetCommand result = $result\r\n\r\n";

    if ( (index($result,'INVALID,DR') != -1)) {
        print "TestDataRateSetCommand \t\t\tPassed\r\n\r\n";
        print $csvFileHandle "TestDataRateSetCommand,Passed\r\n";
        print $testFileHandle "TestDataRateSetCommand, Passed, $commandStatus, $result\r\n\r\n";
        $testStatus   = $SUCCESS;
    } else {
        print "TestDataRateSetCommand \t\t\tFailed\r\n";
        print $csvFileHandle "TestDataRateSetCommand,Failed\r\n";
        print $testFileHandle "TestDataRateSetCommand, Failed, $commandStatus, $result\r\n\r\n";
        $testStatus   = $FAILED;
    }
	
	# set the data rate
	for ($counter = 0; $counter < 9; $counter++) { 
		if ($counter == 0) {
			$data = 1
		}
		if ($counter == 1) {
			$data = 5
		}
		if ($counter == 2) {
			$data = 10
		}
		if ($counter == 3) {
			$data = 25
		}
		if ($counter == 4) {
			$data = 50
		}
		if ($counter == 5) {
			$data = 100
		}
		if ($counter == 6) {
			$data = 250
		}
		if ($counter == 7) {
			$data = 500
		}
		if ($counter == 8) {
			$data = 1000
		}
		$commandStatus = "=dr,$data";
		$portTest->write($commandStatus."\n");
		sleep (1);
		$result = $portTest->input;
		$result =~ s/\r|\n//g;
		print "TestDataRateSetCommand command  = $commandStatus\r\n";
		print "TestDataRateSetCommand result = $result";
		print $testFileHandle "TestDataRateSetCommand command  = $commandStatus\r\n";
		print $testFileHandle "TestDataRateSetCommand result = $result\r\n\r\n";

		if ( (index($result,'INVALID,DR') != -1)) {
			print "TestDataRateSetCommand \t\t\tFailed\r\n\r\n";
			print $csvFileHandle "TestDataRateSetCommand,Failed\r\n";
			print $testFileHandle "TestDataRateSetCommand, Failed, $commandStatus, $result\r\n\r\n";
			$testStatus   = $FAILED;
		} else {
			print "TestDataRateSetCommand \t\t\tPassed\r\n";
			print $csvFileHandle "TestDataRateSetCommand,Passed\r\n";
			print $testFileHandle "TestDataRateSetCommand, Passed, $commandStatus, $result\r\n\r\n";
			$testStatus   = $SUCCESS;
		}
		sleep (2);
	}
	# set the data rate
    $commandStatus = "=dr,3600";
    $portTest->write($commandStatus."\n");
	sleep (1);
	$result = $portTest->input;
    print "TestDataRateSetCommand command  = $commandStatus\r\n";
    print "TestDataRateSetCommand result = $result";
    print $testFileHandle "TestDataRateSetCommand command  = $commandStatus\r\n";
    print $testFileHandle "TestDataRateSetCommand result = $result\r\n\r\n";
	if ((index($deviceName,'1775') != -1) || (index($deviceName,'IRS') != -1) || (index($deviceName,'DSPU') != -1))  {
	
        if ( (index($result,'INVALID,DR') != -1)) {
			print "TestDataRateSetCommand \t\t\tFailed\r\n";
            print $csvFileHandle "TestDataRateSetCommand,Failed\r\n";
            print $testFileHandle "TestDataRateSetCommand, Failed,$commandStatus, $result\r\n\r\n";
            $testStatus   = $FAILED;
            
        }
		else {
			print "TestDataRateSetCommand \t\t\tPassed\r\n\r\n";
            print $csvFileHandle "TestDataRateSetCommand,Passed\r\n";
            print $testFileHandle "TestDataRateSetCommand, Passed, $commandStatus, $result\r\n\r\n";
            $testStatus   = $SUCCESS;            
        }
	}
	elsif (index($result,'INVALID,DR') != -1) {
            print "TestDataRateSetCommand \t\t\tPassed\r\n\r\n";
            print $csvFileHandle "TestDataRateSetCommand,Passed\r\n";
            print $testFileHandle "TestDataRateSetCommand, Passed, $commandStatus, $result\r\n\r\n";
            $testStatus   = $SUCCESS;
    }
	else {
            print "TestDataRateSetCommand \t\t\tFailed\r\n";
            print $csvFileHandle "TestDataRateSetCommand,Failed\r\n";
            print $testFileHandle "TestDataRateSetCommand, Failed,$commandStatus, $result\r\n\r\n";
            $testStatus   = $FAILED;
    }

    # set the data rate
    $commandStatus = "=dr,5000";
    $portTest->write($commandStatus."\n");
    sleep (1);
    $result = $portTest->input;
    print "TestDataRateSetCommand command  = $commandStatus\r\n";
    print "TestDataRateSetCommand result = $result";
    print $testFileHandle "TestDataRateSetCommand command  = $commandStatus\r\n";
    print $testFileHandle "TestDataRateSetCommand result = $result\r\n\r\n";
	if ((index($deviceName,'1775') != -1) || (index($deviceName,'IRS') != -1) || (index($deviceName,'DSPU') != -1))  {
	
        if ( (index($result,'INVALID,DR') != -1)) {
			print "TestDataRateSetCommand \t\t\tFailed\r\n";
            print $csvFileHandle "TestDataRateSetCommand,Failed\r\n";
            print $testFileHandle "TestDataRateSetCommand, Failed,$commandStatus, $result\r\n\r\n";
            $testStatus   = $FAILED;
            
        }
		else {
			print "TestDataRateSetCommand \t\t\tPassed\r\n\r\n";
            print $csvFileHandle "TestDataRateSetCommand,Passed\r\n";
            print $testFileHandle "TestDataRateSetCommand, Passed, $commandStatus, $result\r\n\r\n";
            $testStatus   = $SUCCESS;            
        }
	}
	elsif (index($result,'INVALID,DR') != -1) {
            print "TestDataRateSetCommand \t\t\tPassed\r\n\r\n";
            print $csvFileHandle "TestDataRateSetCommand,Passed\r\n";
            print $testFileHandle "TestDataRateSetCommand, Passed, $commandStatus, $result\r\n\r\n";
            $testStatus   = $SUCCESS;
    }
	else {
            print "TestDataRateSetCommand \t\t\tFailed\r\n";
            print $csvFileHandle "TestDataRateSetCommand,Failed\r\n";
            print $testFileHandle "TestDataRateSetCommand, Failed,$commandStatus, $result\r\n\r\n";
            $testStatus   = $FAILED;
    }

    # set data rate back to 1000 for filter commands
    # set the data rate
    $commandStatus = "=dr,1000";
    $portTest->write($commandStatus."\n");
    sleep (1);

    $result = $portTest->input;
    print "TestDataRateSetCommand command  = $commandStatus\r\n";
    print "TestDataRateSetCommand result = $result";
    print $testFileHandle "TestDataRateSetCommand command  = $commandStatus\r\n";
    print $testFileHandle "TestDataRateSetCommand result = $result\r\n\r\n";

    if ( (index($result,'DR,1000') != -1)) {
        print "TestDataRateSetCommand \t\t\tPassed\r\n\r\n";
        print $csvFileHandle "TestDataRateSetCommand,Passed\r\n";
        print $testFileHandle "TestDataRateSetCommand, Passed, $commandStatus, $result\r\n\r\n";
        $testStatus   = $SUCCESS;
    } else {
        print "TestDataRateSetCommand \t\t\tFailed\r\n";
        print $csvFileHandle "TestDataRateSetCommand,Failed\r\n";
        print $testFileHandle "TestDataRateSetCommand, Failed, $commandStatus, $result\r\n\r\n";
        $testStatus   = $FAILED;
    }


    return $testStatus;

} # end of TestDataRateSetCommand

############################################################################
#  TestDataRateGetCommand
#
#  Description: Test Data Rate Get Command
#
#       Inputs: $portTest         - comport device is on
#               $csvFileHandle    - file handle to write csv test results
#               $testFileHandle    - file handle to write txt test results
#
#      Returns: Success or Failure - 1 or 0
#
# Side Effects: None
#
#        Notes: None
#
############################################################################
sub TestDataRateGetCommand
{
    my $portTest      = shift;
    my $csvFileHandle = shift;
    my $testFileHandle = shift;

    my $testStatus   = $SUCCESS;

    # get the baud
    my $commandStatus = "?dr";
    $portTest->write($commandStatus."\n");

    sleep 1;

    my $result = $portTest->input;
    print "TestDataRateGetCommand result = $result";
    print "TestDataRateGetCommand command  = $commandStatus\r\n";
    print $testFileHandle "TestDataRateGetCommand result = $result";
    print $testFileHandle "TestDataRateGetCommand command  = $commandStatus\r\n";

    if ( (index($result,'DR') != -1)) {
        print "TestDataRateGetCommand \t\t\tPassed\r\n\r\n";
        print $csvFileHandle "TestDataRateGetCommand,Passed\r\n";
        print $testFileHandle "TestDataRateGetCommand, Passed\r\n";
        $testStatus   = $SUCCESS;
    } else {
        print "TestDataRateGetCommand \t\t\tFailed\r\n";
        print $csvFileHandle "TestDataRateGetCommand,Failed\r\n";
        print $testFileHandle "TestDataRateGetCommand, Failed\r\n";
        $testStatus   = $FAILED;
    }
    return $testStatus;
} # end of TestDataRateGetCommand

############################################################################
#  TestFtNegativeTest1775
#
#  Description: Test Filter Type negative testing
#
#       Inputs: $portTest         - comport device is on
#               $sensorType       - the sensor we wish to set
#               $filtertype       - the filter type we wish to set
#               $csvFileHandle    - file handle to write csv test results
#               $testFileHandle    - file handle to write txt test results
#
#      Returns: Success or Failure - 0 or 1
#
# Side Effects: None
#
#        Notes: =FILTTYPE,<A|G>,BUTTER,N,FCUTOFF,<100,1000,10000>	(where N is filterOrder, and FCUTOFF is cutoffFrequency)
#               =FILTTYPE,<A|G>,CHEBY,N,GSTOP,FSTOP,<100,1000,10000>	(where N is filterOrder, GSTOP is stopbandGain, FSTOP is stopbandFrequency)
#               =FILTTYPE,G,BUTTER,3,1062.5
#
############################################################################
sub TestFtNegativeTest1775
{
    my $portTest      = shift;
    my $csvFileHandle = shift;
    my $testFileHandle = shift;

    my $testStatus = $SUCCESS;

    print "TestFilter Types Negative Testing Started\r\n";
	print $csvFileHandle "TestFilter Types Negative Testing Started\r\n";
	print $testFileHandle "TestFilter Types Negative Testing Started\r\n";
    # set a configuration for butterworth with a negative filter order
    my $commandStatus = "=FILTTYPE,G,BUTTER,-10,1062.5";
    $portTest->write($commandStatus."\n");
    select(undef, undef, undef, 0.25);  # sleep 1/4 second 250 milliseconds

    my $result = $portTest->input;
    print "TestFtNegativeTest command = $commandStatus\r\n";
    print "TestFtNegativeTest result $result";
    #print $testFileHandle "TestFtNegativeTest command = $commandStatus\r\n";
    #print $testFileHandle "TestFtNegativeTest result = $result";

    if ( (index($result,'USAGE: =FILTTYPE') != -1)) {
        print "TestFtNegativeTest set test \t\t\tPassed\r\n\r\n";
        print $csvFileHandle "TestFilter Neg FO Test =FILTTYPE G BUTTER -10 1062.5, Passed\r\n";
        print $testFileHandle "TestFilter Neg FO Test Passed $commandStatus\r\n\r\n";
        $testStatus = $SUCCESS;
    } else {
        print "TestFtNegativeTest set test \t\t\tFailed\r\n\r\n";
        print $csvFileHandle "TestFilter Neg FO Test =FILTTYPE G BUTTER -10 1062.5,Failed\r\n";
        print $testFileHandle "TestFilter Neg FO Test Failed $commandStatus\r\n\r\n";
        $testStatus = $FAILED;
    }

    # set a configuration for butterworth with a invalid filter order
    $commandStatus = "=FILTTYPE,G,BUTTER,9,1062.5";
    $portTest->write($commandStatus."\n");
    select(undef, undef, undef, 0.25);  # sleep 1/4 second 250 milliseconds

    $result = $portTest->input;
    print "TestFtNegativeTest command = $commandStatus\r\n";
    print "TestFtNegativeTest result $result";
    #print $testFileHandle "TestFtNegativeTest command = $commandStatus\r\n";
    #print $testFileHandle "TestFtNegativeTest result = $result";

    if ( (index($result,'USAGE: =FILTTYPE') != -1)) {
        print "TestFtNegativeTest set test \t\t\tPassed\r\n\r\n";
        print $csvFileHandle "TestFilter Invaid FO Test =FILTTYPE G BUTTER 9 1062.5, Passed\r\n";
        print $testFileHandle "TestFilter Invaid FO Test Passed $commandStatus\r\n\r\n";
        $testStatus = $SUCCESS;
    } else {
        print "TestFtNegativeTest set test \t\t\tFailed\r\n\r\n";
        print $csvFileHandle "TestFilter Invaid FO Test =FILTTYPE G BUTTER 9 1062.5,Failed\r\n";
        print $testFileHandle "TestFilter Invaid FO Test Failed $commandStatus\r\n\r\n";
        $testStatus = $FAILED;
    }

    # set a configuration for butterworth with a zero filter order
    $commandStatus = "=FILTTYPE,G,BUTTER,0,1062.5";
    $portTest->write($commandStatus."\n");
    select(undef, undef, undef, 0.25);  # sleep 1/4 second 250 milliseconds

    $result = $portTest->input;
    print "TestFtNegativeTest command = $commandStatus\r\n";
    print "TestFtNegativeTest result $result";
    #print $testFileHandle "TestFtNegativeTest command = $commandStatus\r\n";
    #print $testFileHandle "TestFtNegativeTest result = $result";

    if ( (index($result,'USAGE: =FILTTYPE') != -1)) {
        print "TestFtNegativeTest set test \t\t\tPassed\r\n\r\n";
        print $csvFileHandle "TestFilter 0 FO Test =FILTTYPE G BUTTER 0 1062.5, Passed\r\n";
        print $testFileHandle "TestFilter 0 FO Test Passed $commandStatus\r\n\r\n";
        $testStatus = $SUCCESS;
    } else {
        print "TestFtNegativeTest set test \t\t\tFailed\r\n\r\n";
        print $csvFileHandle "TestFilter 0 FO Test =FILTTYPE G BUTTER 0 1062.5,Failed\r\n";
        print $testFileHandle "TestFilter 0 FO Test Failed $commandStatus\r\n\r\n";
        $testStatus = $FAILED;
    }


    # set a configuration for butterworth with a negative frequency
    $commandStatus = "=FILTTYPE,G,BUTTER,3,-1000";
    $portTest->write($commandStatus."\n");
    select(undef, undef, undef, 0.25);  # sleep 1/4 second 250 milliseconds

    $result = $portTest->input;
    print "TestFtNegativeTest command = $commandStatus\r\n";
    print "TestFtNegativeTest result = $result";
    #print $testFileHandle "TestFtNegativeTest command = $commandStatus\r\n";
    #print $testFileHandle "TestFtNegativeTest result = $result";

    if ( (index($result,'USAGE: =FILTTYPE') != -1)) {
        print "TestFtNegativeTest set test \t\t\tPassed\r\n\r\n";
        print $csvFileHandle "TestFilter Neg Freq Test =FILTTYPE G BUTTER 3 -1000, Passed\r\n";
        print $testFileHandle "TestFilter Neg Freq Test Passed $commandStatus\r\n\r\n";
        $testStatus = $SUCCESS;
    } else {
        print "TestFtNegativeTest set test \t\t\tFailed\r\n";
        print $csvFileHandle "TestFilter Neg Freq Test =FILTTYPE G BUTTER 3 -1000,Failed\r\n";
        print $testFileHandle "TestFilter Neg Freq Test Failed $commandStatus\r\n\r\n";
        $testStatus = $FAILED;
    }

    # set a configuration for cheby with a negative filter order
    $commandStatus = "=FILTTYPE,G,CHEBY,-10,.6,1000";
    $portTest->write($commandStatus."\n");
    select(undef, undef, undef, 0.25);  # sleep 1/4 second 250 milliseconds

    $result = $portTest->input;
    print "TestFtNegativeTest command = $commandStatus\r\n";
    print "TestFtNegativeTest result = $result";
    #print $testFileHandle "TestFtNegativeTest command = $commandStatus\r\n";
    #print $testFileHandle "TestFtNegativeTest result = $result";

    if ( (index($result,'USAGE: =FILTTYPE') != -1)) {
        print "TestFtNegativeTest set test \t\t\tPassed\r\n\r\n";
        print $csvFileHandle "TestFilter Neg FO Test =FILTTYPE G CHEBY -10 .6 1000, Passed\r\n";
        print $testFileHandle "TestFilter Neg FO Test Passed $commandStatus\r\n\r\n";
        $testStatus = $SUCCESS;
    } else {
        print "TestFtNegativeTest set test \t\t\tFailed\r\n";
        print $csvFileHandle "TestFilter Neg FO Test =FILTTYPE G CHEBY -10 .6 1000,Failed\r\n";
        print $testFileHandle "TestFilter Neg FO Test Failed $commandStatus\r\n\r\n";
        $testStatus = $FAILED;
    }

    # set a configuration for cheby with a invalid filter order
    $commandStatus = "=FILTTYPE,G,CHEBY,9,.6,1000";
    $portTest->write($commandStatus."\n");
    select(undef, undef, undef, 0.25);  # sleep 1/4 second 250 milliseconds


    $result = $portTest->input;
    print "TestFtNegativeTest command = $commandStatus\r\n";
    print "TestFtNegativeTest result = $result";
    #print $testFileHandle "TestFtNegativeTest command = $commandStatus\r\n";
    #print $testFileHandle "TestFtNegativeTest result = $result";

    if ( (index($result,'USAGE: =FILTTYPE') != -1)) {
        print "TestFtNegativeTest set test \t\t\tPassed\r\n\r\n";
        print $csvFileHandle "TestFilter Invalid FO =FILTTYPE G CHEBY 9 .6 1000,Passed\r\n";
        print $testFileHandle "TestFilter Invalid FO Passed $commandStatus\r\n\r\n";
        $testStatus = $SUCCESS;
    } else {
        print "TestFtNegativeTest set test \t\t\tFailed\r\n";
        print $csvFileHandle "TestFilter Invalid FO =FILTTYPE G CHEBY 9 .6 1000,Failed\r\n";
        print $testFileHandle "TestFilter Invalid FO Failed $commandStatus\r\n\r\n";
        $testStatus = $FAILED;
    }

    # set a configuration for cheby with a zero filter order
    $commandStatus = "=FILTTYPE,G,CHEBY,0,.6,1000";
    $portTest->write($commandStatus."\n");
    select(undef, undef, undef, 0.25);  # sleep 1/4 second 250 milliseconds


    $result = $portTest->input;
    print "TestFtNegativeTest command = $commandStatus\r\n";
    print "TestFtNegativeTest result = $result";
    #print $testFileHandle "TestFtNegativeTest command = $commandStatus\r\n";
    #print $testFileHandle "TestFtNegativeTest result = $result";

    if ( (index($result,'USAGE: =FILTTYPE') != -1)) {
        print "TestFtNegativeTest set test \t\t\tPassed\r\n\r\n";
        print $csvFileHandle "TestFilter 0 FO =FILTTYPE G CHEBY 0 .6 1000, Passed\r\n";
        print $testFileHandle "TestFilter 0 FO Passed $commandStatus\r\n\r\n";
        $testStatus = $SUCCESS;
    } else {
        print "TestFtNegativeTest set test \t\t\tFailed\r\n";
        print $csvFileHandle "TestFilter 0 FO =FILTTYPE G CHEBY 0 .6 1000,Failed\r\n";
        print $testFileHandle "TestFilter 0 FO Failed $commandStatus\r\n\r\n";
        $testStatus = $FAILED;
    }

     # set a configuration for cheby with a invalid G Stop
    $commandStatus = "=FILTTYPE,G,CHEBY,2,2,1000";
    $portTest->write($commandStatus."\n");
    select(undef, undef, undef, 0.25);  # sleep 1/4 second 250 milliseconds


    $result = $portTest->input;
    print "TestFtNegativeTest command = $commandStatus\r\n";
    print "TestFtNegativeTest result = $result";
    #print $testFileHandle "TestFtNegativeTest command = $commandStatus\r\n";
    #print $testFileHandle "TestFtNegativeTest result = $result";

    if ( (index($result,'USAGE: =FILTTYPE') != -1)) {
        print "TestFtNegativeTest set test \t\t\tPassed\r\n\r\n";
        print $csvFileHandle "TestFilter Invalid G Stop =FILTTYPE G CHEBY 2 2 1000, Passed\r\n";
        print $testFileHandle "TestFilter Invalid G Stop Passed $commandStatus\r\n\r\n";
        $testStatus = $SUCCESS;
    } else {
        print "TestFtNegativeTest set test \t\t\tFailed\r\n";
        print $csvFileHandle "TestFilter Invalid G Stop =FILTTYPE G CHEBY 2 2 1000,Failed\r\n";
        print $testFileHandle "TestFilter Invalid G Stop Failed $commandStatus\r\n\r\n";
        $testStatus = $FAILED;
    }

    # set a configuration for cheby with a negative stop band gain
    $commandStatus = "=FILTTYPE,G,CHEBY,3,-.6,1000";
    $portTest->write($commandStatus."\n");
    select(undef, undef, undef, 0.25);  # sleep 1/4 second 250 milliseconds

    $result = $portTest->input;
    print "TestFtNegativeTest command = $commandStatus\r\n";
    print "TestFtNegativeTest result = $result";
    #print $testFileHandle "TestFtNegativeTest command = $commandStatus\r\n";
    #print $testFileHandle "TestFtNegativeTest result= $result";

    if ( (index($result,'USAGE: =FILTTYPE') != -1)) {
        print "TestFtNegativeTest set test \t\t\tPassed\r\n\r\n";
        print $csvFileHandle "TestFilter Neg G Stop =FILTTYPE G CHEBY 3 -.6 1000, Passed\r\n";
        print $testFileHandle "TestFilter Neg G Stop Passed $commandStatus\r\n\r\n";
        $testStatus = $SUCCESS;
    } else {
        print "TestFtNegativeTest set test \t\t\tFailed\r\n";
        print $csvFileHandle "TestFilter Neg G Stop =FILTTYPE G CHEBY 3 -.6 1000,Failed\r\n";
        print $testFileHandle "TestFilter Neg G Stop Failed $commandStatus\r\n\r\n";
        $testStatus = $FAILED;
    }

    # set a configuration for cheby with a negative stop band frequency
    $commandStatus = "=FILTTYPE,G,CHEBY,3,.6,-1000";
    $portTest->write($commandStatus."\n");
    select(undef, undef, undef, 0.25);  # sleep 1/4 second 250 milliseconds

    $result = $portTest->input;
    print "TestFtNegativeTest command = $commandStatus\r\n";
    print "TestFtNegativeTest result = $result";
    #print $testFileHandle "TestFtNegativeTest command = $commandStatus\r\n";
    #print $testFileHandle "TestFtNegativeTest result = $result";

    if ( (index($result,'USAGE: =FILTTYPE') != -1)) {
        print "TestFtNegativeTest set test \t\t\tPassed\r\n\r\n";
        print $csvFileHandle "TestFilter Neg Freq =FILTTYPE G CHEBY 3 .6 -1000,Passed\r\n";
        print $testFileHandle "TestFilter Neg Freq Passed $commandStatus\r\n\r\n";
        $testStatus = $SUCCESS;
    } else {
        print "TestFtNegativeTest set test \t\t\tFailed\r\n";
        print $csvFileHandle "TestFilter Neg Freq =FILTTYPE G CHEBY 3 .6 -1000,Failed\r\n";
        print $testFileHandle "TestFilter Neg Freq Failed $commandStatus\r\n\r\n";
        $testStatus = $FAILED;
    }

     # set a configuration for cheby with a zero stop band gain
    $commandStatus = "=FILTTYPE,G,CHEBY,3,0,1000";
    $portTest->write($commandStatus."\n");
    select(undef, undef, undef, 0.25);  # sleep 1/4 second 250 milliseconds

    $result = $portTest->input;
    print "TestFtNegativeTest command = $commandStatus\r\n";
    print "TestFtNegativeTest result = $result";
    #print $testFileHandle "TestFtNegativeTest command = $commandStatus\r\n";
    #print $testFileHandle "TestFtNegativeTest result = $result";

    if ( (index($result,'USAGE: =FILTTYPE') != -1)) {
        print "TestFtNegativeTest set test \t\t\tPassed\r\n\r\n";
        print $csvFileHandle "TestFilter 0 G Stop =FILTTYPE G CHEBY 3 0 1000, Passed\r\n";
        print $testFileHandle "TestFilter 0 G Stop Passed $commandStatus\r\n\r\n";
        $testStatus = $SUCCESS;
    } else {
        print "TestFtNegativeTest set test \t\t\tFailed\r\n";
        print $csvFileHandle "TestFilter 0 G Stop =FILTTYPE G CHEBY 3 0 1000,Failed\r\n";
        print $testFileHandle "TestFilter 0 G Stop Failed $commandStatus\r\n\r\n";
        $testStatus = $FAILED;
    }

    return $testStatus;
} # end of TestFtNegativeTest1775



############################################################################
#  TestSwitchImuVariant
#
#  Description: Switch the unit to an IMU Variant (i.e 1775,1750,1725)
#
#       Inputs: $portTest         - comport device is on
#               $csvFileHandle    - file handle to write csv test results
#               $testFileHandle   - file handle to write txt test results
#               $imuVariant       - The IMU variant to switch to
#
#      Returns: Success or Failure - 1 or 0
#
# Side Effects: None
#
#        Notes: None
#
############################################################################
sub TestSwitchImuVariant
{
    my $portTest       = shift;
    my $csvFileHandle  = shift;
    my $testFileHandle = shift;
    my $imuVariant     = shift;

    my $testStatus   = $SUCCESS;

    print "\r\nTestSwitchImuVariant switching to $imuVariant\r\n";

    # get the IMU Variant
    my $commandStatus = "?SYSCONFIG";
    $portTest->write($commandStatus."\n");

    sleep 1;

    my $result = $portTest->input;
    print "TestSwitchImuVariant command  = $commandStatus\r\n";
    print "TestSwitchImuVariant result = $result\r\n";

    print $testFileHandle "TestSwitchImuVariant command  = $commandStatus\r\n";
    print $testFileHandle "TestSwitchImuVariant result = $result\r\n";


    # set the IMU Variant
    print "TestSwitchImuVariant switching to $imuVariant\r\n";
    $commandStatus = "=SYSCONFIG,$imuVariant";
    $portTest->write($commandStatus."\n");

    sleep 4;

    $result = $portTest->input;
    print "TestSwitchImuVariant command $commandStatus\r\n";
    print "TestSwitchImuVariant result = $result";

    print $testFileHandle "TestSwitchImuVariant command  = $commandStatus\r\n";
    print $testFileHandle "TestSwitchImuVariant result = $result";

    sleep 4;

    # get the IMU Variant
    $commandStatus = "?SYSCONFIG";
    $portTest->write($commandStatus."\n");
    sleep 1;

    $result = $portTest->input;
    print "TestSwitchImuVariant command  = $commandStatus\r\n";
    print "TestSwitchImuVariant result = $result";

    print $testFileHandle "TestSwitchImuVariant command  = $commandStatus\r\n";
    print $testFileHandle "TestSwitchImuVariant result = $result";



    if ((index($result,'SYSCONFIG') != -1)) {

        print "TestSwitchImuVariant \t\t\tPassed\r\n\r\n";
        print $csvFileHandle "TestSwitchImuVariant,Passed\r\n";
        print $testFileHandle "TestSwitchImuVariant, Passed\r\n";
        $testStatus   = $SUCCESS;
    } else {
        print "TestSwitchImuVariant \t\t\tFailed\r\n";
        print $csvFileHandle "TestSwitchImuVariant,Failed\r\n";
        print $testFileHandle "TestSwitchImuVariant, Failed\r\n";
        $testStatus   = $FAILED;
    }

    return $testStatus;
} # end of TestSwitchImuVariant




############################################################################
#  TestFiltTypeNegativeTest
#
#  Description: Negative testing for the filttype command for non-1775 IMU Variants
#
#       Inputs: $portTest         - comport device is on
#               $csvFileHandle    - file handle to write csv test results
#               $testFileHandle   - file handle to write csv test results
#               $deviceName       - the device name running the test on
#
#      Returns: Success or Failure - 0 or 1
#
# Side Effects: None
#
#        Notes: None
#
############################################################################
sub TestFiltTypeNegativeTest
{
    my $portTest       = shift;
    my $csvFileHandle  = shift;
    my $testFileHandle = shift;
    my $deviceName     = shift;

    my $testStatus = $SUCCESS;
    my $command;
    my $result;

    print "TestFiltTypeNegativeTest for non-1775, non-DSPU variants\r\n\r\n";
    print $testFileHandle "TestFiltTypeNegativeTest for non-1775, non-DSPU variants\r\n\r\n";

    # process DSP1760 Variant
    if ((index($deviceName,'DSP') != -1) && (index($deviceName,'DSPU') == -1)) {

        $command = "=filttype,g,cheby,2,0.2,1000";
        $portTest->write($command."\n");
        select(undef, undef, undef, 0.25);  # sleep 1/4 second 250 milliseconds
        $result = $portTest->input;
        print "TestFiltTypeNegativeTest command $command\r\n";
        print "TestFiltTypeNegativeTest result = $result";
        print $testFileHandle "TestFiltTypeNegativeTest command $command\r\n";
        print $testFileHandle "TestFiltTypeNegativeTest result = $result\r\n";

        if( $result eq "USAGE: =FILTTYPE,G,<CHEBY|BUTTER|AVE>\r\n" ) {
            print "TestFiltTypeNegativeTest filttype,g,cheby test \t\t\tPassed\r\n\r\n";
            print $csvFileHandle "TestFiltTypeNegativeTest filttype gyro cheby,Passed\r\n";
            print $testFileHandle "TestFiltTypeNegativeTest filttype gyro cheby, Passed\r\n";
        } else {
            print "TestFiltTypeNegativeTest filttype,g,cheby test \t\t\tFailed\r\n";
            print $csvFileHandle "TestFiltTypeNegativeTest filttype gyro cheby,Failed\r\n";
            print $testFileHandle "TestFiltTypeNegativeTest filttype gyro cheby, Failed\r\n";
            $testStatus = $FAILED;
        }

        $command = "=filttype,g,butter,2,1000";
        $portTest->write($command."\n");
        select(undef, undef, undef, 0.25);  # sleep 1/4 second 250 milliseconds
        $result = $portTest->input;
        print "TestFiltTypeNegativeTest result = $result";
        print $testFileHandle "TestFiltTypeNegativeTest command $command\r\n";
        print $testFileHandle "TestFiltTypeNegativeTest result = $result\r\n";

        if( $result eq "USAGE: =FILTTYPE,G,<CHEBY|BUTTER|AVE>\r\n" ) {
            print "TestFiltTypeNegativeTest filttype,g,butter test \t\t\tPassed\r\n\r\n";
            print $csvFileHandle "TestFiltTypeNegativeTest filttype gyro butter,Passed\r\n";
            print $testFileHandle "TestFiltTypeNegativeTest filttype gyro butter, Passed\r\n";
        } else {
            print "filttype,g,cheby test \t\t\tFailed\r\n";
            print $csvFileHandle "TestFiltTypeNegativeTest filttype gyro butter,Failed\r\n";
            print $testFileHandle "TestFiltTypeNegativeTest filttype gyro butter, Failed\r\n";
            $testStatus = $FAILED;
        }
	}	
		# process 1725/1750 IMU Variants
    if ((index($deviceName,'1725') != -1) || (index($deviceName,'1750') != -1)) {

        $command = "=filttype,g,cheby,2,0.2,1000";
        $portTest->write($command."\n");
        select(undef, undef, undef, 0.25);  # sleep 1/4 second 250 milliseconds
        $result = $portTest->input;
        print "TestFiltTypeNegativeTest command $command\r\n";
        print "TestFiltTypeNegativeTest result = $result";
        print $testFileHandle "TestFiltTypeNegativeTest command $command\r\n";
        print $testFileHandle "TestFiltTypeNegativeTest result = $result\r\n";

        if( $result eq "USAGE: =FILTTYPE,<A|G>,<CHEBY|BUTTER|AVE>\r\n" ) {
            print "TestFiltTypeNegativeTest filttype,g,cheby test \t\t\tPassed\r\n\r\n";
            print $csvFileHandle "TestFiltTypeNegativeTest filttype gyro cheby,Passed\r\n";
            print $testFileHandle "TestFiltTypeNegativeTest filttype gyro cheby, Passed\r\n";
        } else {
            print "TestFiltTypeNegativeTest filttype,g,cheby test \t\t\tFailed\r\n";
            print $csvFileHandle "TestFiltTypeNegativeTest filttype gyro cheby,Failed\r\n";
            print $testFileHandle "TestFiltTypeNegativeTest filttype gyro cheby, Failed\r\n";
            $testStatus = $FAILED;
        }
	
        $command = "=filttype,g,butter,2,1000";
        $portTest->write($command."\n");
        select(undef, undef, undef, 0.25);  # sleep 1/4 second 250 milliseconds
        $result = $portTest->input;
        print "TestFiltTypeNegativeTest result = $result";
        print $testFileHandle "TestFiltTypeNegativeTest command $command\r\n";
        print $testFileHandle "TestFiltTypeNegativeTest result = $result\r\n";

        if( $result eq "USAGE: =FILTTYPE,<A|G>,<CHEBY|BUTTER|AVE>\r\n" ) {
            print "TestFiltTypeNegativeTest filttype,g,butter test \t\t\tPassed\r\n\r\n";
            print $csvFileHandle "TestFiltTypeNegativeTest filttype gyro butter,Passed\r\n";
            print $testFileHandle "TestFiltTypeNegativeTest filttype gyro butter, Passed\r\n";
        } else {
            print "filttype,g,cheby test \t\t\tFailed\r\n";
            print $csvFileHandle "TestFiltTypeNegativeTest filttype gyro butter,Failed\r\n";
            print $testFileHandle "TestFiltTypeNegativeTest filttype gyro butter, Failed\r\n";
            $testStatus = $FAILED;
        }
	}
    # now test the filttype command for the accels
	if ((index($deviceName,'DSP') == -1) && (index($deviceName,'IRS') == -1)) {
		$command = "=filttype,a,cheby,2,0.2,1000";
		$portTest->write($command."\n");
		select(undef, undef, undef, 0.25);  # sleep 1/4 second 250 milliseconds
		$result = $portTest->input;
		print "TestFiltTypeNegativeTest command $command\r\n";
		print "TestFiltTypeNegativeTest result = $result\r\n";
		print $testFileHandle "TestFiltTypeNegativeTest command $command\r\n";
		print $testFileHandle "TestFiltTypeNegativeTest result = $result\r\n";
		if( $result eq "USAGE: =FILTTYPE,<A|G>,<CHEBY|BUTTER|AVE>\r\n" ) {
			print "TestFiltTypeNegativeTest filttype,a,cheby test \t\t\tPassed\r\n\r\n";
			print $csvFileHandle "TestFiltTypeNegativeTest filttype accels cheby,Passed\r\n";
			print $testFileHandle "TestFiltTypeNegativeTest filttype accels cheby, Passed\r\n";
		}
		else {
			print "TestFiltTypeNegativeTest filttype,a,cheby test \t\t\tFailed\r\n";
			print $csvFileHandle "TestFiltTypeNegativeTest filttype accels cheby,Failed\r\n";
			print $testFileHandle "TestFiltTypeNegativeTest filttype accels cheby, Failed\r\n";
			$testStatus = $FAILED;
		}
		$command = "=filttype,a,butter,2,1000";
		$portTest->write($command."\n");
		select(undef, undef, undef, 0.25);  # sleep 1/4 second 250 milliseconds
		$result = $portTest->input;
		print "TestFiltTypeNegativeTest result = $result\r\n";
		print $testFileHandle "TestFiltTypeNegativeTest command $command\r\n";
		print $testFileHandle "TestFiltTypeNegativeTest result = $result\r\n";
		if( $result eq "USAGE: =FILTTYPE,<A|G>,<CHEBY|BUTTER|AVE>\r\n" ) {
			print "TestFiltTypeNegativeTest filttype,a,butter test \t\t\tPassed\r\n\r\n";
			print $csvFileHandle "TestFiltTypeNegativeTest filttype accels butter,Passed\r\n";
			print $testFileHandle "TestFiltTypeNegativeTest filttype accels butter, Passed\r\n";
		}
		else {
			print "filttype,g,cheby test \t\t\tFailed\r\n";
			print $csvFileHandle "TestFiltTypeNegativeTest filttype accels butter,Failed\r\n";
			print $testFileHandle "TestFiltTypeNegativeTest filttype accels butter, Failed\r\n";
			$testStatus = $FAILED;
		}
	}
    
    # DSP1760 and IRS variant negative testing
    if ((index($deviceName,'DSP') != -1) || (index($deviceName,'DSPU') != -1) || (index($deviceName,'IRS') != -1)) {
        $command = "=filttype,a,butter";
        $portTest->write($command."\n");
        select(undef, undef, undef, 0.25);  # sleep 1/4 second 250 milliseconds
        $result = $portTest->input;
        print "TestFiltTypeNegativeTest for DSP1760 result = $result\r\n";
        print "TestFiltTypeNegativeTest for DSP1760 command $command\r\n";
        print $testFileHandle "TestFiltTypeNegativeTest for DSP1760 command $command\r\n";
        print $testFileHandle "TestFiltTypeNegativeTest for DSP1760 result = $result\r\n";

         if ((index($result,'USAGE: =FILTTYPE,G,<CHEBY|BUTTER|AVE>') != -1)) {
            print "TestFiltTypeNegativeTest  for DSP1760 command filttype,a,butter test \t\t\tPassed\r\n\r\n";
            print $csvFileHandle "TestFiltTypeNegativeTest  for DSP1760 command filttype accels butter,Passed\r\n";
            print $testFileHandle "TestFiltTypeNegativeTest  for DSP1760 command filttype accels butter, Passed\r\n";
        } else {
            print "filttype,g,cheby test \t\t\tFailed\r\n";
            print $csvFileHandle "TestFiltTypeNegativeTest for DSP1760 command filttype accels butter,Failed\r\n";
            print $testFileHandle "TestFiltTypeNegativeTest  for DSP1760 command filttype accels butter, Failed\r\n";
            $testStatus = $FAILED;
        }
		
        $command = "=filttype,a,cheby";
        $portTest->write($command."\n");
        select(undef, undef, undef, 0.25);  # sleep 1/4 second 250 milliseconds
        $result = $portTest->input;
        print "TestFiltTypeNegativeTest for DSP1760 result = $result\r\n";
        print "TestFiltTypeNegativeTest for DSP1760 command $command\r\n";
        print $testFileHandle "TestFiltTypeNegativeTest for DSP1760 command $command\r\n";
        print $testFileHandle "TestFiltTypeNegativeTest for DSP1760 result = $result\r\n";

         if ((index($result,'USAGE: =FILTTYPE,G,<CHEBY|BUTTER|AVE>') != -1)) {
            print "TestFiltTypeNegativeTest  for DSP1760 command filttype,a,cheby test \t\t\tPassed\r\n\r\n";
            print $csvFileHandle "TestFiltTypeNegativeTest  for DSP1760 command filttype accels cheby,Passed\r\n";
            print $testFileHandle "TestFiltTypeNegativeTest  for DSP1760 command filttype accels cheby, Passed\r\n";
        } else {
            print "filttype,g,cheby test \t\t\tFailed\r\n";
            print $csvFileHandle "TestFiltTypeNegativeTest for DSP1760 command filttype accels cheby,Failed\r\n";
            print $testFileHandle "TestFiltTypeNegativeTest  for DSP1760 command filttype accels cheby, Failed\r\n";
            $testStatus = $FAILED;
        }
    }


    return $testStatus;

} # end of TestFiltTypeNegativeTest


############################################################################
#  CollectNegativeResults
#
#  Description: Collect Negative Test Results from files
#
#       Inputs: $testFileHandle   - file handle to read test results
#
#      Returns: Success or Failure - 0 or 1
#
# Side Effects: None
#
#        Notes: None
#
############################################################################
sub CollectNegativeResults
{
    my $storageDirectory = shift;
    my $testDevice       = shift; # The device is used in the

    my $testStatus = $SUCCESS;

    print "\r\nCollectNegativeResults using $storageDirectory for $testDevice\r\n";
    my $currentDirectory = cwd(); # get the current working directory
    print "CWD = $currentDirectory\r\n";

    my $testFailedResultsFileNameGlobal = $currentDirectory . "/" . "testFailedResultsGlobal.txt";
    open my $testFailedResultsFileHandleGlobal, '>>', $testFailedResultsFileNameGlobal or die "Couldn't open file testFailedResultsGlobal.txt, $!";

    my $testFailedResultsFileName = $storageDirectory . "testFailedResults.txt";
    open my $testFailedResultsFileHandle, '>', $testFailedResultsFileName or die "Couldn't open file testFailedResults.txt, $!";

    my $testDataFileName = "testfile.txt";
    open $testFileHandle, '<', $testDataFileName or die "Couldn't open file testfile.txt, $!";

    # read from the main text file and copy all failed lineds to the failed results file
    # we will use the failures in the email message body

    print "\r\nCollectNegativeResults for $testDevice \r\n\r\n";
    print $testFailedResultsFileHandleGlobal "\r\n\r\nCollectNegativeResults for $testDevice \r\n\r\n";

    while ( my $line = <$testFileHandle> ) {
        if ( $line =~ /Failed/ ) {
            print $line;
            print $testFailedResultsFileHandle $line;
            print $testFailedResultsFileHandleGlobal $line;
        }
    }
    close $testFileHandle;
    close $testFailedResultsFileHandle;
    close $testFailedResultsFileHandleGlobal;

    return $testStatus;

} # end of CollectNegativeResults

############################################################################
#  ZipDirectory
#
#  Description: Zip the directory for archiving
#
#       Inputs: $ZipDir     - Directory path to zip to
#               $BACKUPNAME - Name of the backup file
#
#      Returns: Success or Failure - 0 or 1
#
# Side Effects: None
#
#        Notes: This routine is run to archive the test results
#
############################################################################
sub ZipDirectory
{
    my $ZipDir     = shift;
    my $BACKUPNAME = shift;

    my $testStatus = $SUCCESS;

    print "\r\nZipDirectory using $ZipDir\r\n";
    my $currentDirectory = cwd(); # get the current working directory
    print "CWD = $currentDirectory\r\n";

    # subroutine to compress the directory tree in to backup.zip in the backup location
    print "Backing up ".$ZipDir."\n";
    my $zip = Archive::Zip->new();

    opendir (DIR, $ZipDir) or die $!;

    while (my $file = readdir(DIR)) {

        # Use -f to look for a file
        next unless (-f $ZipDir."\\".$file);

        $zip->addFile($ZipDir."\\".$file, $file);
        print "Added $file to zip\n";
    }

    closedir(DIR);
    unless ( $zip->writeToFileNamed($BACKUPNAME) == AZ_OK ) {
        die 'write error';
    }

    print "Successfully backed up to ". $BACKUPNAME;
    return $testStatus;

} # end of ZipDirectory

############################################################################
#  TestAXESRotationCommand
#
#  Description: AXES rotation testing
#
#       Inputs: $portTest         - comport device is on
#               $csvFileHandle    - file handle to write csv test results
#               $testFileHandle   - file handle to write txt test results
#
#
#      Returns: Success or Failure - 0 or 1
#
# Side Effects: None
#
#        Notes: this will work for dsp1760 with out accels but is not the intent.
#               any variant without accels reports a zero out. This test inserts a value for the
#               offset and it is used as a live value thus the test will work not as intended but will check correct values.
#
############################################################################
sub TestAXESRotationCommand
{
    my $portTest = shift;
    my $csvFileHandle = shift;
    my $testFileHandle = shift;
	my $deviceName = shift;

	my $ACCELZ = 0;
	my $ACCELY = 1;
	my $ACCELX = 2;
	my $GYROZ = 3;
	my $GYROY= 4;
	my $GYROX = 5;


	my $counter = 0;
	my $testStatus = $SUCCESS;
	my @limits;
	my $Go;
	my $Ao;
	my $Axes;
	my $line;
	my $AoStore;
	my $GoStore;
	my $AxesStore;
	my @dataField;
	my $template = 'ffffff';
	my @SensorType = ("ACCELZ","ACCELY","ACCELX","GYROZ","GYROY","GYROX");

	if ((index($deviceName,'DSP1') != -1) || (index($deviceName,'DSPU1') != -1) ) {    
		print "AXES Rotation 135 Test Not Applicable to Single Axis Device\r\n";
		print $testFileHandle "AXES Rotation 135 Test Not Applicable to Single Axis Device\r\n";
		print $csvFileHandle "AXES Rotation 135 Test Not Applicable to Single Axis Device\n";
	}	
	else {	
		#******************* Save units Axes, GO and AO to restore at end of test
		# send the cfgreset command
		my $subSuccess = TestCfgRstCommand($portTest,$csvFileHandle,$testFileHandle);
		if ($subSuccess == $FAILED) {
			$testStatus = $FAILED;
		}
		my $commandStatus = "?AO";
		$portTest->write($commandStatus."\n");
		select(undef, undef, undef, 0.25);  # sleep 1/4 second 250 milliseconds
		$AoStore = $portTest->input;

		$commandStatus = "?GO";
		$portTest->write($commandStatus."\n");
		select(undef, undef, undef, 0.25);  # sleep 1/4 second 250 milliseconds
		$GoStore = $portTest->input;

		$commandStatus = "?Axes";
		$portTest->write($commandStatus."\n");
		select(undef, undef, undef, 0.25);  # sleep 1/4 second 250 milliseconds
		$AxesStore = $portTest->input;

		# set units to rate and degrees so we can measure cross axes values
		$commandStatus = "=ROTFMT,RATE";
		$portTest->write($commandStatus."\n");
		select(undef, undef, undef, 0.25);  # sleep 1/4 second 250 milliseconds
		my $result = $portTest->input;
		print "\r\n$result\r\n";

		$commandStatus = "=ROTUNITS,DEG";
		$portTest->write($commandStatus."\n");
		select(undef, undef, undef, 0.25);  # sleep 1/4 second 250 milliseconds
		$result = $portTest->input;
		print "\r\n$result\r\n";

		# Set data rate to 10 Hz to make capture easier
		$commandStatus = "=dr,10";
		$portTest->write($commandStatus."\n");
		select(undef, undef, undef, 0.5);  # sleep 1/4 second 250 milliseconds
		$result = $portTest->input;
		print "\r\n$result\r\n";

		# read file which contains GO AO Axes and test limits to compare against
		# also is the test name. For instance Z-X<135> is populate the Z accel and
		# Z gyro with 3 and load the Axes to rotate 135 Degrees.

		open FILE, "testSequence.txt"
		  or die "Can't open file testSequence.txt: $!\n";
		while ( $line = <FILE> ) {

			my @iTest = split(':', $line);

			print "Test " . $iTest[7] . "\n";
			$Go = $iTest[0];
			$Ao = $iTest[1];
			$Axes = $iTest[2];

			$limits[$ACCELX] = 0.0;
			$limits[$ACCELY] = 0.0;
			$limits[$ACCELZ] = 0.0;
			$limits[$GYROX] = 0.0;
			$limits[$GYROY] = 0.0;
			$limits[$GYROZ] = 0.0;


			if ($iTest[3] eq "Z") {
				$limits[$ACCELZ] = $iTest[4] * 1;
				$limits[$GYROZ] = $iTest[4] * 1;
			} elsif ($iTest[3] eq "Y") {
				$limits[$ACCELY] = $iTest[4] * 1;
				$limits[$GYROY] = $iTest[4] * 1;
			}else{
				$limits[$ACCELX] = $iTest[4] * 1;
				$limits[$GYROX] = $iTest[4] * 1;

			}

			if ($iTest[5] eq "Z") {
				$limits[$ACCELZ] = $iTest[6] * 1;
				$limits[$GYROZ] = $iTest[6] * 1;
			} elsif ($iTest[5] eq "Y") {
				$limits[$ACCELY] = $iTest[6] * 1;
				$limits[$GYROY] = $iTest[6] * 1;
			}else{
				$limits[$ACCELX] = $iTest[6] * 1;
				$limits[$GYROX] = $iTest[6] * 1;
			}

			$commandStatus = $Ao;
			$portTest->write($commandStatus."\n");
			select(undef, undef, undef, 0.25);  # sleep 1/4 second 250 milliseconds
			$result = $portTest->input;
			#print $result;

			$commandStatus = $Go;
			$portTest->write($commandStatus."\n");
			select(undef, undef, undef, 0.25);  # sleep 1/4 second 250 milliseconds
			$result = $portTest->input;
			#print $result;


			$portTest->write($Axes."\n");
			select(undef, undef, undef, 0.25);  # sleep 1/4 second 250 milliseconds
			$result = $portTest->input;
			#print $result;

			$commandStatus = "=DEBUG,0";
			$portTest->write($commandStatus."\n");
			select(undef, undef, undef, 1.0);  # sleep 1 second and go get the 5 Hz data
			# off we go. we should be in binary mode and starting to buffer the data for testing.

			$result = $portTest->input;
			my $resultLength = length($result);
			my @headerPlace = FindHeaderBinary($result);
			#print "********->" .   $headerPlace[5] . "\n";

			my $rBuffer =  substr ($result, $headerPlace[5] + 4, 24);
			my $bbuffer = reverse ($rBuffer);
			@dataField = unpack $template, $bbuffer;

			#print $dataField[$GYROX] ." ". $limits[$GYROX] . "\n";
			#print $dataField[$GYROY] ." ". $limits[$GYROY] . "\n";
			#print $dataField[$GYROZ] ." ". $limits[$GYROZ] . "\n";
			#print $dataField[$ACCELX] ." ".$limits[$ACCELX] . "\n";
			#print $dataField[$ACCELY] ." ".$limits[$ACCELY] . "\n";
			#print $dataField[$ACCELZ] ." ".$limits[$ACCELZ] . "\n";

			my $diff;
			for ($counter = 0; $counter < 6; $counter++) {
				$diff =  abs($dataField[$counter] - $limits[$counter]);
				if (index($deviceName,'IMU') != -1) {
					if ( $diff  > 0.31) {
						print "AXES ROTATION FAILURE ***> " . $SensorType[$counter] . " " . $diff . "\r\n";
						print "\r\nTestAXESRotation, $iTest[7] $SensorType[$counter] Failed\r\n\r\n";
						print $testFileHandle "AXES ROTATION ***> " . $SensorType[$counter] . " " . $diff . "\r\n";
						print $testFileHandle "TestAXESRotation, $iTest[7] $SensorType[$counter] Failed\r\n\r\n";				
						$testStatus = $FAILED;
					}
					else {
						print "AXES ROTATION ***> " . $SensorType[$counter] . " " . $diff . "\r\n";
						print "TestAXESRotation, $iTest[7] $SensorType[$counter] Passed\r\n\r\n";
						print $testFileHandle "AXES ROTATION ***> " . $SensorType[$counter] . " " . $diff . "\r\n";
						print $testFileHandle "TestAXESRotation, $iTest[7] $SensorType[$counter] Passed\r\n\r\n";
					}		
				}
				elsif ((index($deviceName,'DSP3') != -1) || (index($deviceName,'DSPU3') != -1) || (index($deviceName,'IRS') != -1)) {
					if (( $diff  > 0.31) && (index($SensorType[$counter],'GYRO') != -1)) {
						print "AXES ROTATION FAILURE ***> " . $SensorType[$counter] . " " . $diff . "\r\n";
						print "\r\nTestAXESRotation, $iTest[7] $SensorType[$counter] Failed\r\n\r\n";
						print $testFileHandle "AXES ROTATION ***> " . $SensorType[$counter] . " " . $diff . "\r\n";
						print $testFileHandle "TestAXESRotation, $iTest[7] $SensorType[$counter] Failed\r\n\r\n";				
						$testStatus = $FAILED;
					}
					elsif (index($SensorType[$counter],'GYRO') != -1) {
						print "AXES ROTATION ***> " . $SensorType[$counter] . " " . $diff . "\r\n";
						print "TestAXESRotation, $iTest[7] $SensorType[$counter] Passed\r\n\r\n";
						print $testFileHandle "AXES ROTATION ***> " . $SensorType[$counter] . " " . $diff . "\r\n";
						print $testFileHandle "TestAXESRotation, $iTest[7] $SensorType[$counter] Passed\r\n\r\n";
					}		
				}
				elsif ((index($deviceName,'DSP2') != -1) || (index($deviceName,'DSPU2') != -1)) {
					if (( $diff  > 0.31) && (index($SensorType[$counter],'GYRO') != -1) && (index($iTest[7],'Y') == -1)) {
						print "AXES ROTATION FAILURE ***> " . $SensorType[$counter] . " " . $diff . "\r\n";
						print "\r\nTestAXESRotation, $iTest[7] $SensorType[$counter] Failed\r\n\r\n";
						print $testFileHandle "AXES ROTATION ***> " . $SensorType[$counter] . " " . $diff . "\r\n";
						print $testFileHandle "TestAXESRotation, $iTest[7] $SensorType[$counter] Failed\r\n\r\n";				
						$testStatus = $FAILED;
					}
					elsif ((index($SensorType[$counter],'GYRO') != -1) && (index($iTest[7],'Y') == -1)) {
						print "AXES ROTATION ***> " . $SensorType[$counter] . " " . $diff . "\r\n";
						print "TestAXESRotation, $iTest[7] $SensorType[$counter] Passed\r\n\r\n";
						print $testFileHandle "AXES ROTATION ***> " . $SensorType[$counter] . " " . $diff . "\r\n";
						print $testFileHandle "TestAXESRotation, $iTest[7] $SensorType[$counter] Passed\r\n\r\n";
					}		
				}
			}
			$portTest->write("=DEBUG,1" . "\n");
			select(undef, undef, undef, 0.25);  # sleep 1/4 second 250 milliseconds
			my $result = $portTest->input;


			#print $result;
		} #end of while

		 # Restoring AO to pre-test value
		 $portTest->write("=" . $AoStore . "\n");
		 select(undef, undef, undef, 0.25);  # sleep 1/4 second 250 milliseconds
		 $result = $portTest->input;
		 print $result;
		 # Restoring GO to pre-test value
		 $portTest->write("=" . $GoStore . "\n");
		 select(undef, undef, undef, 0.25);  # sleep 1/4 second 250 milliseconds
		 $result = $portTest->input;
		 print $result;
		 # Restoring AXES to pre-test value
		 $portTest->write("=" . $AxesStore . "\n");
		 select(undef, undef, undef, 0.25);  # sleep 1/4 second 250 milliseconds
		 $result = $portTest->input;
		 print $result;
		 TestCfgRstCommand($port,$testCsvFileHandle,$testFileHandle);
		if ($testStatus == $SUCCESS){
			print "AXES Rotation 135 Test Passed\r\n";
			print $testFileHandle "AXES Rotation 135 Test Passed\r\n";
			print $csvFileHandle "AXES Rotation 135 Test,Passed\n";
		}
		else {
			print "AXES Rotation 135 Test Failed\r\n";
			print $testFileHandle "AXES Rotation 135 Test Failed\r\n";
			print $csvFileHandle "AXES Rotation 135 Test,Failed\n";
		}
	}
	return $testStatus;

 } # end of TestAXESRotationCommand
 ############################################################################
#  FindHeaderBinary
#
#  Description: parses through binary buffer for the number of instances of
#  				 format A header.
#
#       Inputs: $binBuffer - binary buffer filled with format A data
#
#      Returns: array of locations where the header was found in the buffer
#
# Side Effects: None
#
#        Notes: this function will work when capturing a snapshot of data
#				It will not work if trying to continuously capture and parse.
#
############################################################################
sub FindHeaderBinary
{
	my $binBuffer   = shift;
	my $counter;
    my $bufferSize;
	my @headerLoc;
	my $found = 0;
	$bufferSize = length($binBuffer);
	my @dataBuffer = split(//, $binBuffer);
	for ($counter = 0; $counter < $bufferSize; $counter++) {
		#prevents searching beyond buffer boundary if we are at [endof buffer -3 ]we won't detect the header anyhow.
		if ($counter < $bufferSize - 3) {
			if (ord($dataBuffer[$counter])== 0xfe){
				if (ord($dataBuffer[$counter + 1])== 0x81){
					if (ord($dataBuffer[$counter + 2])== 0xff){
						if (ord($dataBuffer[$counter + 3])== 0x55){
							$headerLoc[$found] = $counter;
							#print "found at -->" . $counter . "\n";
							$found++;
							#print @headerLoc . "\n";
						}
					}
				}
			}
		}
	}
	return @headerLoc;
}#end of FindHeaderBinary

############################################################################
#  ProcessImupacket
#
#  Description: parses the IMU Packet
#
#       Inputs: $csvFileHandle     - file handle to write csv test results
#               $testFileHandle    - file handle to write txt test results
#               $TestPacket - IMU Packet filled with format A data
#               $deviceName - Name of the device
#
#      Returns: NONE
#
# Side Effects: NONE
#
#        Notes: This parsing is for Format A only
#
############################################################################

sub ProcessImupacket {

    my $csvFileHandle  = shift;
    my $testFileHandle = shift;
    my $TestPacket     = shift;
    my $deviceName     = shift;
	my $testDevice	   = shift;

    my $aTestStatus = $SUCCESS;
	my $gTestStatus = $SUCCESS;
	my $testStatus  = $SUCCESS;
    my $gyroX;
    my $gyroY;
    my $gyroZ;
    my $accelX;
    my $accelY;
    my $accelZ;

    my $statusSeqTemp;
    my $temperature;
    my $status;

    print ("ProcessImupacket: TestPacket = $TestPacket" . "\n");

    # unpack and print the 4 bytes packet elements from the packet
    my @packetElements = unpack '(a8)*', $TestPacket;
    print join("\n",@packetElements),"\n";

    # convert the accel and gyro data
    $gyroX = hex($packetElements[$GYROX_LOCATION]);
    $gyroY = hex($packetElements[$GYROY_LOCATION]);
    $gyroZ = hex($packetElements[$GYROZ_LOCATION]);
    printf("\ngyros HEX VALUES: = %04x %04x %04x \n\n", $gyroX, $gyroY, $gyroZ );

    $gyroX = GetFloatFrom32BitHexString($gyroX);
    $gyroY = GetFloatFrom32BitHexString($gyroY);
    $gyroZ = GetFloatFrom32BitHexString($gyroZ);
    print("\ngyros FLOATS: = $gyroX, $gyroY, $gyroZ \n\n");
	print $testFileHandle "\ngyros FLOATS: = $gyroX, $gyroY, $gyroZ \n\n";
    $accelX = hex($packetElements[$ACCELX_LOCATION]);
    $accelY = hex($packetElements[$ACCELY_LOCATION]);
    $accelZ = hex($packetElements[$ACCELZ_LOCATION]);

    printf("\nAccels HEX VALUES: = %04x %04x %04x \n\n", $accelX, $accelY, $accelZ);

    $accelX = GetFloatFrom32BitHexString($accelX);
    $accelY = GetFloatFrom32BitHexString($accelY);
    $accelZ = GetFloatFrom32BitHexString($accelZ);

    printf("\nAccels FLOATS: = $accelX, $accelY, $accelZ \n\n");
	print $testFileHandle "\nAccels FLOATS: = $accelX, $accelY, $accelZ \n\n";

    # convert the temp and status
    $statusSeqTemp = $packetElements[$STATUS_SEQ_TEMP_LOCATION];
    print ("\nstatusSeqTemp = $statusSeqTemp \n");

    $status = substr($statusSeqTemp,0, 2 );
    $temperature = substr($statusSeqTemp,4, 4 );
    print ("\nSTRINGS: status = $status \n temperature = $temperature\n");

    $status = hex($status);
    $temperature = hex($temperature);
    print ("\nVALUES: status = $status \n temperature = $temperature\n");

    # test the device type to parse the packet
    if ((index($deviceName,'DSP') != -1) || (index($deviceName,'IRS') != -1)) {

		if ((index($deviceName,'DSP1') != -1) || (index($deviceName,'DSPU1') != -1)) { # Z axis Only

			if (($gyroZ < $MIN_GYRO_VALUE) || ($gyroZ > $MAX_GYRO_VALUE)) {
				$testStatus = $FAILED;

               print "ProcessImupacket 1760DSP1 Gyro Failed\r\n";
               print $testFileHandle "ProcessImupacket 1760DSP1 Gyro \t\t\tFailed\r\n";
			}
			if ($testDevice eq "IMU") {
				if ($status != 0x07 ) { #($status != 0x07 ) or case where IMU is used for testing DSP SW
					$testStatus = $FAILED;
					print "ProcessImupacket 1760DSP1 Status = $status Failed \r\n";
					print $testFileHandle "ProcessImupacket 1760DSP1 Status = $status  \t\t\tFailed\r\n";
				}
			}
			elsif ($status != 0x04 ) { 
					$testStatus = $FAILED;
					print "ProcessImupacket 1760DSP1 Status = $status Failed \r\n";
					print $testFileHandle "ProcessImupacket 1760DSP1 Status = $status  \t\t\tFailed\r\n";
			}

       } 

       if ((index($deviceName,'DSP2') != -1) || (index($deviceName,'DSPU2') != -1)) { # X and Z axis Only

           if ( ($gyroX < $MIN_GYRO_VALUE) || ($gyroX > $MAX_GYRO_VALUE) || ($gyroZ < $MIN_GYRO_VALUE) || ($gyroZ > $MAX_GYRO_VALUE)) {
               $testStatus = $FAILED;
               print "ProcessImupacket 1760DSP2 Gyro Failed\r\n";
               print $testFileHandle "ProcessImupacket 1760DSP2 Gyro  \t\t\tFailed\r\n";
           }

           if ($testDevice eq "IMU") {
				if ($status != 0x07 ) { #($status != 0x07 ) or case where IMU is used for testing DSP SW
					$testStatus = $FAILED;
					print "ProcessImupacket 1760DSP1 Status = $status Failed \r\n";
					print $testFileHandle "ProcessImupacket 1760DSP1 Status = $status  \t\t\tFailed\r\n";
				}
			}
			elsif ($status != 0x05 ) { 
					$testStatus = $FAILED;
					print "ProcessImupacket 1760DSP1 Status = $status Failed \r\n";
					print $testFileHandle "ProcessImupacket 1760DSP1 Status = $status  \t\t\tFailed\r\n";
			}

       } 

       if ((index($deviceName,'DSP3') != -1) || (index($deviceName,'DSPU3') != -1) || (index($deviceName,'IRS') != -1)) {

           if ( ($gyroX < $MIN_GYRO_VALUE) || ($gyroY < $MIN_GYRO_VALUE) || ($gyroZ < $MIN_GYRO_VALUE) ) {
               $gTestStatus = $FAILED;
           }

           if ( ($gyroX > $MAX_GYRO_VALUE) || ($gyroY > $MAX_GYRO_VALUE) || ($gyroZ > $MAX_GYRO_VALUE) ) {
               $gTestStatus = $FAILED;
           }

           if ($gTestStatus == $FAILED) {
               print "ProcessImupacket 1760DSP3 Gyro Failed\r\n";
               print $testFileHandle "ProcessImupacket 1760DSP3 Gyro  \t\t\tFailed\r\n";
           }

           if ($status != 0x07 ) {
               $testStatus = $FAILED;
               print "ProcessImupacket 1760DSP3 Status = $status Failed \r\n";
               print $testFileHandle "ProcessImupacket 1760DSP3 Status = $status  \t\t\tFailed\r\n";
           }



       }
    }
	else {

       if ( ($accelX < $MIN_ACCEL_0G_VALUE) || ($accelY < $MIN_ACCEL_0G_VALUE) || ($accelZ < $MIN_ACCEL_1G_VALUE) ) {
           $aTestStatus = $FAILED;
       }

       if ( ($accelX > $MAX_ACCEL_0G_VALUE) || ($accelY > $MAX_ACCEL_0G_VALUE) || ($accelZ > $MAX_ACCEL_1G_VALUE) ) {
           $aTestStatus = $FAILED;
       }

       if ($aTestStatus == $FAILED) {
           print "ProcessImupacket $deviceName Accel Failed\r\n";
           print $testFileHandle "ProcessImupacket $deviceName Accel  \t\t\tFailed\r\n";
       }

       if ( ($gyroX < $MIN_GYRO_VALUE) || ($gyroY < $MIN_GYRO_VALUE) || ($gyroZ < $MIN_GYRO_VALUE) ) {
           $gTestStatus = $FAILED;
       }

       if ( ($gyroX > $MAX_GYRO_VALUE) || ($gyroY > $MAX_GYRO_VALUE) || ($gyroZ > $MAX_GYRO_VALUE) ) {
           $gTestStatus = $FAILED;
       }

       if ($gTestStatus == $FAILED) {
           print "ProcessImupacket $deviceName Gyro Failed\r\n";
           print $testFileHandle "ProcessImupacket $deviceName Gyro  \t\t\tFailed\r\n";
       }

       if ($status != 0x77 ) {
           $testStatus = $FAILED;
           print "ProcessImupacket $deviceName Status = $status Failed \r\n";
           print $testFileHandle "ProcessImupacket $deviceName Status = $status  \t\t\tFailed\r\n";
       }

    } # end of else of if (index($deviceName,'DSP1760') != -1)

    if ( ($temperature < $MIN_TEMP_C) || ($temperature > $MAX_TEMP_C) ) {
           $testStatus = $FAILED;
           print "ProcessImupacket $deviceName temperature = $temperature Failed \r\n";
           print $testFileHandle "ProcessImupacket $deviceName temperature = $temperature  \t\t\tFailed\r\n";
    }


    if (($testStatus == $SUCCESS) && ($aTestStatus == $SUCCESS) && ($gTestStatus == $SUCCESS)) {
        print "ProcessImupacket test \t\t\tPassed\r\n\r\n";
        print $csvFileHandle "ProcessImupacket,Passed\r\n";
        print $testFileHandle "ProcessImupacket, Passed\r\n";
    } else {
        print "ProcessImupacket test \t\t\tFailed\r\n";
        print $csvFileHandle "ProcessImupacket,Failed\r\n";
        print $testFileHandle "ProcessImupacket, Failed\r\n";
        $testStatus = $FAILED;
    }

} # end of sub ProcessImupacket

###########################################################################
#  ProcessBITPacket
#
#  Description: parses the IMU Packet for BIT results using BITTEST
#
#       Inputs: $csvFileHandle     - file handle to write csv test results
#               $testFileHandle    - file handle to write txt test results
#               $TestPacket - IMU Packet filled with format A data
#               $deviceName - Name of the device
#
#      Returns: NONE
#
# Side Effects: NONE
#
#        Notes: This parsing is for BIT Format A and B
#
############################################################################

sub ProcessBITPacket {

    my $csvFileHandle  = shift;
    my $testFileHandle = shift;
    my $TestPacket     = shift;
    my $deviceName     = shift;

    my $testStatus = $SUCCESS;
    my $byte1;
    my $byte2;
    my $byte3;
    my $byte4;
    my $byte5;
    my $byte6;

    my $byte7 = 0x7F;
    my $byte8 = 0x7F;

    my $word1;
    my $word2;
    my $word3;
    my $word4;

    my $status;
    my $headerByte;
    my $testString;
    my $bitErrorListSize;

    print ("ProcessBITPacket: TestPacket = $TestPacket" . "\n");
	print $testFileHandle ("ProcessBITPacket: TestPacket = $TestPacket" . "\n");
    # unpack and print the 6 or 8 bytes packet elements from the packet A or packet B type
    my @packetElements = unpack '(a2)*', $TestPacket;
    # print join("\n",@packetElements),"\n";

    $headerByte = $packetElements[0] . $packetElements[1] . $packetElements[2] . $packetElements[3];
    # print ("headerByte = $headerByte \n");

    # convert the bit data form the incoming packet
    $byte1 = hex($packetElements[4]);
    $byte2 = hex($packetElements[5]);
    $byte3 = hex($packetElements[6]);
    $byte4 = hex($packetElements[7]);
    $byte5 = hex($packetElements[8]);
    $byte6 = hex($packetElements[9]);
	$byte7 = hex($packetElements[10]);
	$byte8 = hex($packetElements[11]);
    if ($headerByte eq $FORMAT_BIT_A_HEADER) {
		print "BIT Format is A\r\n";
		print $testFileHandle "BIT Format is A\r\n";
        $word1 = hex($packetElements[7] . $packetElements[6] . $packetElements[5] . $packetElements[4]);
        $word2 = hex($packetElements[9] . $packetElements[8]);
        $bitErrorListSize = $FORMATA_BIT_ERROR_SIZE;
		print "BIT Error List Size = $bitErrorListSize\r\n";
		print $testFileHandle "BIT Error List Size = $bitErrorListSize\r\n";

    } else {
		print "BIT Format is B\r\n";
		print $testFileHandle "BIT Format is B\r\n";
        $word1 = hex($packetElements[7] . $packetElements[6] . $packetElements[5] . $packetElements[4]);
        $word2 = hex($packetElements[11] . $packetElements[10] . $packetElements[9] . $packetElements[8]);
        $bitErrorListSize = Get_Bit_StringSize($headerByte);
		print "BIT Error List Size = $bitErrorListSize\r\n";
		print $testFileHandle "BIT Error List Size = $bitErrorListSize\r\n";
    }

    printf("\nbytes HEX VALUES: = 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x \n\n", $byte1, $byte2, $byte3, $byte4,$byte5, $byte6, $byte7, $byte8 );
    printf("\nWord HEX VALUES: = 0x%02x 0x%02x \n\n", $word1, $word2);

    my $i;
    my $bit;
    my $testBit = 0;
    for ($i = 0, $bit = 1; $i < 32; $i++, $bit <<= 1) {
        $testBit = $word1 & $bit;
        if ($testBit == 0) {
             printf ("Bit %d in word 0x%02x  is zero\n",$i, $word1 ) ;

            $testString = Get_Bit_String($i);
            # test for the reserved bits - use index which will test if the RESERVED keyword exists. A return of -1 indicates that it is not there
            if (index($testString,$RESERVED_BITTEST_ERROR) == -1 ) {
                print $testString . " \n";
                print $testFileHandle "\t\t\t$testString \r\n";
                $testStatus = $FAILED;
            }
        }
    } # end of for loop

    for ($i = 32, $bit = 1; $i < ($bitErrorListSize); $i++, $bit <<= 1) {
        $testBit = $word2 & $bit;
        if ($testBit == 0) {
             printf ("Bit %d in word 0x%02x  is zero\n",$i, $word2 ) ;
            $testString = Get_Bit_String($i);

            # test for the reserved bits - use index which will test if the RESERVED keyword exists. A return of -1 indicates that it is not there
            if (index($testString,$RESERVED_BITTEST_ERROR) == -1 ) {
                print $testString . " \n";
                print $testFileHandle "\t\t\t$testString \r\n";
                $testStatus = $FAILED;
            }
        }
    }

    if ($testStatus == $SUCCESS) {
        print "ProcessBITPacket test \t\t\tPassed\r\n\r\n";
        print $csvFileHandle "ProcessBITPacket,Passed\r\n";
        print $testFileHandle "ProcessBITPacket, Passed\r\n";
    } else {
        print "ProcessBITPacket test \t\t\tFailed\r\n";
        print $csvFileHandle "ProcessBITPacket,Failed\r\n";
        print $testFileHandle "ProcessBITPacket, Failed\r\n";
        $testStatus = $FAILED;
    }

}

############################################################################
#  ProcessBITTEST
#
#  Description: parses the IMU Packet for BIT results using BITTEST
#
#       Inputs: $csvFileHandle     - file handle to write csv test results
#               $testFileHandle    - file handle to write txt test results
#               $TestPacket - IMU Packet filled with format A data
#               $deviceName - Name of the device
#
#      Returns: NONE
#
# Side Effects: NONE
#
#        Notes: This parsing is for Bit A and Bit B
#
############################################################################

sub ProcessBITTEST {
   use warnings;
   no warnings 'uninitialized';
    my $portTest = shift;
    my $logTestResults = shift;
    my $csvFileHandle  = shift;
    my $testFileHandle  = shift;
	my $deviceName     = shift;
    my $imuPacketA;
    my $imuPacketB;

    my $swappedString1;
    my $swappedString2;

    my $hexString1 = "0x7f7f7f7f";
    my $hexString2 = "0x7f7f7f7f";
    my $selfTestString1;
    my $selfTestString2;
	my @serialNumberArray;
	my $testWord1 = 0;
	my $testWord2 = 0;
	my $commandStatus = "";
	my $result = "";
    my $testStatus = $SUCCESS;
	my $testString;
	my $arraySize;
	
    # set a bit mask
	my $i;
	my $j;
    my $bit;
    my $testBit1 = 0;
	my $testBit2 = 0;
	my $bitErrorListSize = Get_Bit_StringSize($arraySize);
		
    for ($i = 0, ; $i < 28; $i++) {
		$hexString1 = Get_Bit_Error_String($i);
		$hexString2 = "0x7f7f7f7f";		
		
		for (my $indexCount = 0; $indexCount < 4; $indexCount++) {
			$commandStatus = "=bittest,1,$hexString1,$hexString2";
			$portTest->write($commandStatus."\n");
			select(undef, undef, undef, 0.25);  # sleep 1/4 second 250 milliseconds
			sleep (5);
			$result = $portTest->input;
			if ( (index($result,"BITTEST") != -1)) {
				$result =~ s/\r|\n//g;
				print "ProcessBITTEST: commandStatus = $commandStatus \n";
				print "ProcessBITTEST: result = $result \n";
				last;
			}
			else {
				$generalStatus = SendDebugCommand($port,"1",0,$testCsvFileHandle,$testFileHandle);
				sleep 1;
				if ($generalStatus == $SUCCESS) {
					print "\n DEBUG Done  $indexCount\r\n";
					TestHalt($port, $testCsvFileHandle,$testFileHandle,0);
					#my $dataValue = "10";
					#TestSetDR($port,$dataValue,1,$testCsvFileHandle,$testFileHandle);
					
				}
				else {
					print "\n DEBUG RESTART\r\n";
					# we might be in config mode from a previous test so we will send a config,0 to get to normal mode
					SendConfigCommand($port,"0",0,$testCsvFileHandle,$testFileHandle);
					portRestart();
					sleep 1;
				}
			}
		} # end of for (my $indexCount = 0; $indexCount < 4; $indexCount++)
		if ( (index($result,"BITTEST") != -1)) {
			$result =~ s/\r|\n//g;
			#print "$result\r\n";
			@serialNumberArray = split("Hex1 Value,= ",$result);
			$testWord1 = $serialNumberArray[1];
			@serialNumberArray = split("BITTEST",$testWord1);
			$testWord1 = $serialNumberArray[0];
			@serialNumberArray = split("Hex2 Value,= ",$result);
			$testWord2 = $serialNumberArray[1];
			print "TestWord1 = $testWord1 TestWord2 = $testWord2\r\n";
			print $testFileHandle "TestWord1 = $testWord1 TestWord2 = $testWord2\r\n";
				
			# run the ?bit and ?bit2 test    
			my $imuPacket = TestBITFormat($port,$testCsvFileHandle,$testFileHandle,$newDir,0);
			(my $resultWord1, my  $resultWord2) = GetBITPacket($testCsvFileHandle,$testFileHandle, $imuPacket, $deviceName);
			printf("\nWord HEX VALUES For Compare: = 0x%02x 0x%02x \n\n", $resultWord1, $resultWord2);
			#print "BIT TEST message: $testWord1  $testWord2\n";
			printf $testFileHandle ("\nWord HEX VALUES For Compare: = 0x%02x 0x%02x \n\n", $resultWord1, $resultWord2);
			for ($j = 0, $bit = 1; $j < 32; $j++, $bit <<= 1) {
				$testBit1 = hex $testWord1 & $bit;
				$testBit2 = $resultWord1 & $bit;
				if ($testBit1 == 0) {
					#printf ("Bit %d in word 0x%02x  is zero\n",$j, $resultWord1 ) ;
					if ((index($deviceName,'DSP3') != -1) || (index($deviceName,'DSPU3') != -1) || (index($deviceName,'IRS') != -1)) {
						$testString = Get_Bit_String_DSP3($j);
					}
					elsif ((index($deviceName,'DSP2') != -1) || (index($deviceName,'DSPU2') != -1)) {
						$testString = Get_Bit_String_DSP2($j);
					}
					elsif ((index($deviceName,'DSP1') != -1) || (index($deviceName,'DSPU1') != -1)) {
						$testString = Get_Bit_String_DSP1($j);
					}
					else {
						$testString = Get_Bit_String($j);
					}
					# test for testword and result word match
					if ((hex $testWord1 == $resultWord1) && (hex $testWord2 == $resultWord2) && (index($testString,$RESERVED_BITTEST_ERROR) == -1 )) {
						printf ("Bit %d in word1 0x%02x  is zero\n",$j, $resultWord1 ) ;
						print "$testString\r\n";
						printf $testFileHandle ("Bit %d in word1 0x%02x  is zero\r\n",$j, $resultWord1 ) ;
						print $testFileHandle "$testString\r\n";
						print "BIT Test Error Word Passed\r\n\r\n";
						print $testFileHandle "BIT Test Error Word Passed\r\n\r\n";
					}
					
					# test for result bit being a masked error bit because it does not apply to the device type
					elsif ((index($testString,"MASKED") != -1 ) && ($testBit2 != 0)) {
						printf ("Bit %d in word1 0x%02x  is one\n",$j, $resultWord1 ) ;
						print "$testString\r\n";
						printf $testFileHandle ("Bit %d in word1 0x%02x  is one\r\n",$j, $resultWord1 ) ;
						print $testFileHandle "$testString\r\n";
						print "BIT Test Error Word Passed\r\n\r\n";
						print $testFileHandle "BIT Test Error Word Passed\r\n\r\n";
					}
					# test for result bit being a reserved error bit; not used to indicate errors.					
					elsif ((index($testString,$RESERVED_BITTEST_ERROR) != -1 )  && ($testBit2 == 0)) {
						printf ("Bit %d in word1 0x%02x  is zero\n",$j, $resultWord1 ) ;
						print "$testString\r\n";
						printf $testFileHandle ("Bit %d in word1 0x%02x  is zero\r\n",$j, $resultWord1 ) ;
						print $testFileHandle "$testString \r\n";					
					}
					else {
						printf ("Bit %d in word1 0x%02x is in error\r\n",$j, $resultWord1 ) ;
						print "$testString\r\n";
						printf $testFileHandle ("Bit %d in word1 0x%02x is in error\r\n",$j, $resultWord1 ) ;
						print $testFileHandle "$testString\r\n";
						print "BIT Test Error Word Failed\r\n\r\n";
						print $testFileHandle "BIT Test Error Word Failed\r\n\r\n";
						$testStatus = $FAILED;				
					}
				}
			} # end of for loop			

			TestRestartShutdown($port);
			#Make sure we are back in Debug mode
			$ModeStatus = "DEBUG";
			print "\r\nMode Status = $ModeStatus\r\n";
			for (my $indexCount = 0; $indexCount < 4; $indexCount++) {
				$generalStatus = SendDebugCommand($port,"1",0,$testCsvFileHandle,$testFileHandle);
				sleep 1;
				if ($generalStatus == $SUCCESS) {
					print "\n DEBUG Done  $indexCount\r\n";
					TestHalt($port, $testCsvFileHandle,$testFileHandle,0);
					#my $dataValue = "10";
					#TestSetDR($port,$dataValue,1,$testCsvFileHandle,$testFileHandle);
					last;
				}
				else {
					print "\n DEBUG RESTART\r\n";
					# we might be in config mode from a previous test so we will send a config,0 to get to normal mode
					SendConfigCommand($port,"0",0,$testCsvFileHandle,$testFileHandle);
					portRestart();
					sleep 1;
				}
			} # end of for (my $indexCount = 0; $indexCount < 4; $indexCount++)
		}
		else {
			print "Process BITTEST command Fail\r\n";
			print $testFileHandle "Process BITTEST command Fail\r\n";
			$testStatus = $FAILED;
			return;
		}
	sleep (2);
	} # end of setting word 1 error bits for loop 
		
	for ($i = 0, ; $i < 23; $i++) {
		$hexString2 = Get_Bit_Error_String($i);
		$hexString1 = "0x7f7f7f7f";
		for (my $indexCount = 0; $indexCount < 4; $indexCount++) {
			$commandStatus = "=bittest,1,$hexString1,$hexString2";
			$portTest->write($commandStatus."\n");
			select(undef, undef, undef, 0.25);  # sleep 1/4 second 250 milliseconds
			sleep (5);
			$result = $portTest->input;
			if ( (index($result,"BITTEST") != -1)) {
				$result =~ s/\r|\n//g;
				print "ProcessBITTEST: commandStatus = $commandStatus \n";
				print "ProcessBITTEST: result = $result \n";
				last;
			}
			else {
				$generalStatus = SendDebugCommand($port,"1",0,$testCsvFileHandle,$testFileHandle);
					sleep 1;
					if ($generalStatus == $SUCCESS) {
						print "\n DEBUG Done  $indexCount\r\n";
						TestHalt($port, $testCsvFileHandle,$testFileHandle,0);
						#my $dataValue = "10";
						#TestSetDR($port,$dataValue,1,$testCsvFileHandle,$testFileHandle);					
					}
					else {
						print "\n DEBUG RESTART\r\n";
						# we might be in config mode from a previous test so we will send a config,0 to get to normal mode
						SendConfigCommand($port,"0",0,$testCsvFileHandle,$testFileHandle);
						portRestart();
						sleep 1;
					}
			}		
		} # end of for (my $indexCount = 0; $indexCount < 4; $indexCount++)
		
		if ( (index($result,"BITTEST") != -1)) {
			$result =~ s/\r|\n//g;
			#print "$result\r\n";
			@serialNumberArray = split("Hex1 Value,= ",$result);
			$testWord1 = $serialNumberArray[1];
			@serialNumberArray = split("BITTEST",$testWord1);
			$testWord1 = $serialNumberArray[0];
			@serialNumberArray = split("Hex2 Value,= ",$result);
			$testWord2 = $serialNumberArray[1];
			print "TestWord1 = $testWord1 TestWord2 = $testWord2\r\n";
			print $testFileHandle "TestWord1 = $testWord1 TestWord2 = $testWord2\r\n";
				
			# run the ?bit and ?bit2 test
    
			my $imuPacket = TestBITFormat($port,$testCsvFileHandle,$testFileHandle,$newDir,0);

			(my $resultWord1, my  $resultWord2) = GetBITPacket($testCsvFileHandle,$testFileHandle, $imuPacket, $deviceName);
			printf("\nWord HEX VALUES For Compare: = 0x%02x 0x%02x \n\n", $resultWord1, $resultWord2);
			#print "BIT TEST message: $testWord1  $testWord2\n";
			printf $testFileHandle ("\nWord HEX VALUES For Compare: = 0x%02x 0x%02x \n\n", $resultWord1, $resultWord2);
			for ($j = 32, $bit = 1; $j < ($bitErrorListSize); $j++, $bit <<= 1) {
				$testBit1 = hex $testWord2 & $bit;
				$testBit2 = $resultWord2 & $bit;
				if ($testBit1 == 0) {
					#printf ("Bit %d in word 0x%02x  is zero\n",$j, $resultWord1 ) ;
					if ((index($deviceName,'DSP3') != -1) || (index($deviceName,'DSPU3') != -1) || (index($deviceName,'IRS') != -1)) {
						$testString = Get_Bit_String_DSP3($j);
					}
					elsif ((index($deviceName,'DSP2') != -1) || (index($deviceName,'DSPU2') != -1)) {
						$testString = Get_Bit_String_DSP2($j);
					}
					elsif ((index($deviceName,'DSP1') != -1) || (index($deviceName,'DSPU1') != -1)) {
						$testString = Get_Bit_String_DSP1($j);
					}
					else {
						$testString = Get_Bit_String($j);
					}
					# test for testword and result word match
					if ((hex $testWord1 == $resultWord1) && (hex $testWord2 == $resultWord2) && (index($testString,$RESERVED_BITTEST_ERROR) == -1 )) {
						printf ("Bit %d in word2 0x%02x  is zero\n",$j, $resultWord2 ) ;
						print "$testString\r\n";
						printf $testFileHandle ("Bit %d in word2 0x%02x  is zero\r\n",$j, $resultWord2 ) ;
						print $testFileHandle "$testString\r\n";
						print "BIT Test Error Word Passed\r\n\r\n";
						print $testFileHandle "BIT Test Error Word Passed\r\n\r\n";
					}
					# test for result bit being a masked error bit because it does not apply to the device type
					elsif ((index($testString,"MASKED") != -1 ) && ($testBit2 != 0)) {
						printf ("Bit %d in word2 0x%02x  is one\n",$j, $resultWord2 ) ;
						print "$testString\r\n";
						printf $testFileHandle ("Bit %d in word2 0x%02x  is one\r\n",$j, $resultWord2 ) ;
						print $testFileHandle "$testString\r\n";
						print "BIT Test Error Word Passed\r\n\r\n";
						print $testFileHandle "BIT Test Error Word Passed\r\n\r\n";
					}
					# test for result bit being a reserved error bit; not used to indicate errors.					
					elsif ((index($testString,$RESERVED_BITTEST_ERROR) != -1 )  && ($testBit2 == 0)) {
						printf ("Bit %d in word2 0x%02x  is zero\n",$j, $resultWord2 ) ;
						print "$testString\r\n";
						printf $testFileHandle ("Bit %d in word2 0x%02x  is zero\r\n",$j, $resultWord2 ) ;
						print $testFileHandle "$testString \r\n";					
					}
					else {
						printf ("Bit %d in word2 0x%02x is in error\r\n",$j, $resultWord2 ) ;
						print "$testString\r\n";
						printf $testFileHandle ("Bit %d in word2 0x%02x is in error\r\n",$j, $resultWord2 ) ;
						print $testFileHandle "$testString\r\n";
						print "BIT Test Error Word Failed\r\n";
						print $testFileHandle "BIT Test Error Word Failed\r\n\r\n";
						$testStatus = $FAILED;				
					}
				}
			} # end of for loop
			
			TestRestartShutdown($port);
			#Make sure we are back in Debug mode
			$ModeStatus = "DEBUG";
			print "\r\nMode Status = $ModeStatus\r\n";
			for (my $indexCount = 0; $indexCount < 4; $indexCount++) {
				$generalStatus = SendDebugCommand($port,"1",0,$testCsvFileHandle,$testFileHandle);
				sleep 1;
				if ($generalStatus == $SUCCESS) {
					print "\n DEBUG Done  $indexCount\r\n";
					TestHalt($port, $testCsvFileHandle,$testFileHandle,0);
					#my $dataValue = "10";
					#TestSetDR($port,$dataValue,1,$testCsvFileHandle,$testFileHandle);
					last;
				}
				else {
					print "\n DEBUG RESTART\r\n";
					# we might be in config mode from a previous test so we will send a config,0 to get to normal mode
					SendConfigCommand($port,"0",0,$testCsvFileHandle,$testFileHandle);
					portRestart();
					sleep 1;
				}
			} # end of for (my $indexCount = 0; $indexCount < 4; $indexCount++)
		}
		else {
			print "Process BITTEST command Fail\r\n";
			print $testFileHandle "Process BITTEST command Fail\r\n";
			$testStatus = $FAILED;
			return;
		}			
	sleep (2);
	} # end of setting word2 error bits for loop
	if ($testStatus == $SUCCESS){
		print "BITTEST Test Pass\r\n";
		print $testFileHandle "BITTEST Test Passed\r\n";
		print $csvFileHandle "BITTEST Test,Passed\n";
	}
	else {
		print "BITTEST Test Fail\r\n";
		print $testFileHandle "BITTEST Test Failed\r\n";
		print $csvFileHandle "BITTEST Test,Failed\n";
	}
	
	# disable BITTEST masking
	$commandStatus = "=bittest,0";
	$portTest->write($commandStatus."\n");
	select(undef, undef, undef, 0.25);  # sleep 1/4 second 250 milliseconds
	$result = $portTest->input;
	print "ProcessBITTEST: commandStatus = $commandStatus \n";
	print $testFileHandle "ProcessBITTEST: commandStatus = $commandStatus \n";
	print "ProcessBITTEST: result = $result \n";
	print $testFileHandle "ProcessBITTEST: result = $result \n";
	TestCfgRstCommand($port,$testCsvFileHandle,$testFileHandle);
	# make sure we go out of DEBUG mode and reset configuration
	TestRestartShutdown($port);
	$ModeStatus = "DEBUG";
	print "\r\nMode Status = $ModeStatus\r\n";
	for (my $indexCount = 0; $indexCount < 4; $indexCount++) {
		$generalStatus = SendDebugCommand($port,"1",0,$testCsvFileHandle,$testFileHandle);
		sleep 1;
		if ($generalStatus == $SUCCESS) {
			print "\n DEBUG Done  $indexCount\r\n";
			TestHalt($port, $testCsvFileHandle,$testFileHandle,0);
			#my $dataValue = "10";
			#TestSetDR($port,$dataValue,1,$testCsvFileHandle,$testFileHandle);
			last;
		}
		else {
			print "\n DEBUG RESTART\r\n";
			# we might be in config mode from a previous test so we will send a config,0 to get to normal mode
			SendConfigCommand($port,"0",0,$testCsvFileHandle,$testFileHandle);
			portRestart();
			sleep 1;
		}
	} # end of for (my $indexCount = 0; $indexCount < 4; $indexCount++)
	
	SendDebugCommand($portTest,"0",0,$csvFileHandle);
	select(undef, undef, undef, 0.25);  # sleep 1/4 second 250 milliseconds
	
	return $testStatus;

} # end of ProcessBITTEST

############################################################################
#  GetBITPacket
#
#  Description: BIT Message Test
#               Test to insure the BIT test works and BIT results are in
#               the output; Test ?bit and ?bit,2
#
#       Inputs: $portTest         - comport device is on#
#               $csvFileHandle    - file handle to write csv test results
#               $testFileHandle    - file handle to write txt test results
#               $storageDirectory - location to store the BIT results file
#
#      Returns: Success or Failure - 0 or 1
#
# Side Effects: None
#
#        Notes: None
#
############################################################################

sub GetBITPacket
{
    my $csvFileHandle  = shift;
    my $testFileHandle = shift;
    my $TestPacket     = shift;
    my $deviceName     = shift;

    my $testStatus = $SUCCESS;
    my $byte1;
    my $byte2;
    my $byte3;
    my $byte4;
    my $byte5;
    my $byte6;
    my $byte7;
    my $byte8;

    my $word1;
    my $word2;
    my $word3;
    my $word4;

    my $status;
    my $headerByte;
    my $testString;
    my $bitErrorListSize;

    print ("GetBITPacket: TestPacket = $TestPacket" . "\n");
	print $testFileHandle ("GetBITPacket: TestPacket = $TestPacket" . "\n");
    # unpack and print the 6 or 8 bytes packet elements from the packet A or packet B type
    my @packetElements = unpack '(a2)*', $TestPacket;
    # print join("\n",@packetElements),"\n";

    $headerByte = $packetElements[0] . $packetElements[1] . $packetElements[2] . $packetElements[3];
    # print ("headerByte = $headerByte \n");

    # convert the bit data from the incoming packet
    $byte1 = hex($packetElements[4]);
    $byte2 = hex($packetElements[5]);
    $byte3 = hex($packetElements[6]);
    $byte4 = hex($packetElements[7]);
    $byte5 = hex($packetElements[8]);
    $byte6 = hex($packetElements[9]);
	$byte7 = hex($packetElements[10]);
	$byte8 = hex($packetElements[11]);
    if ($headerByte eq $FORMAT_BIT_B_HEADER) {
		print "BIT Format is B\r\n";
		print $testFileHandle "BIT Format is B\r\n";
        $word1 = hex($packetElements[7] . $packetElements[6] . $packetElements[5] . $packetElements[4]);
        $word2 = hex($packetElements[11] . $packetElements[10] . $packetElements[9] . $packetElements[8]);
        #$bitErrorListSize = Get_Bit_StringSize($headerByte);
		#print "BIT Error List Size = $bitErrorListSize\r\n";
		#print $testFileHandle "BIT Error List Size = $bitErrorListSize\r\n";
    }

    printf("\nbytes HEX VALUES: = 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x \n\n", $byte1, $byte2, $byte3, $byte4,$byte5, $byte6, $byte7, $byte8 );
    printf("\nWord HEX VALUES: = 0x%02x 0x%02x \n\n", $word1, $word2);

    return $word1,$word2;
    
} # end of GetBITPacket


############################################################################
#  GetFloatFrom32BitHexString
#
#  Description: parses the IMU PacketCalculates a float from a 32 bit hex string
#
#       Inputs: $word32 - 32 bit hex string (e.g. 0x3f87b13c)
#
#
#      Returns: float value
#
# Side Effects: NONE
#
#        Notes: $word32 must be a value and not a string
#
############################################################################
sub GetFloatFrom32BitHexString {

   my $word32 = shift;

   #print("\nEntered GetFloatFrom32BitHexString word32 = $word32 \n");

   my $sign = ($word32 & 0x80000000) ? -1 : 1;
   my $expo = (($word32 & 0x7F800000) >> 23) - 127;
   my $mant = ($word32 & 0x007FFFFF | 0x00800000);

   my $num = $sign * (2 ** $expo) * ( $mant / (1 << 23));

   # print("$word32 = $word32 \n sign = $sign \n expo = $expo \n mant = $mant \n num = $num\n");

   return $num;
} # end of sub GetFloatFrom32BitHexString

