#if 0   // don't include header in comments/line count
# ##############################################################################
#    FILE NAME:  SetFogSysConfig.pl
#
#
#  DESCRIPTION:  Set the Fog System Configuration for the selected  
#				 type so each can be tested using automated perl scripts;	
#
#        NOTES:  This script is intended to be used to configure a 17XXIMU
#				 for each type of FOG varient based
#				 on the 1775IMU board set and software platforms
#				 and run the TestImu.pl script for each configuration.
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
use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
require 'ConfigTypes.pl'; #Contains all the variants of the 1775IMU board set based FOG variants
################### Constants  ########################################
# constants are defined by using CAPS and underbars
# version and revision should change anytime there is a change in the scripts.
my $VERSION  = "XA";
my $REVISION = "0.02";

# We will use the convention that a return of a function for success is one (1) and failure is zero (0)
my $SUCCESS = 1;
my $FAILED = 0;

#####################################
####                             ####
####     THE CODE BEGINS HERE    ####
####                             ####
#####################################

# we will start indenting here as this is the beginning or the "real" processing

###### Determine passed in arguments for test cases to run  #######
    my $port_name = 'COM3'; # default
	my $testFileSelection = "";
	my $testCaseSelection = "";
    my $numArgs = $#ARGV + 1;
    #print "thanx, you gave me $numArgs command-line arguments:\n";
	print "Test Software = $0\r\n";
	print "Test Software Version = $VERSION Revision = $REVISION\r\n";
    # test if the user entered the correct number of parameters
    if ($numArgs > 0) {
        $port_name = $ARGV[0];

        if ($numArgs > 1) {
            # we will print the options so the user can determine if they
            # are correct when the usage command is generated
            foreach my $argnum (0 .. $#ARGV) {
                print "$ARGV[$argnum]\n";
            }
            $testFileSelection = $ARGV[1];
			$testCaseSelection = $ARGV[2];
            print "\ntest file selection = $testFileSelection\n";
			print "\ntest case selection = $testCaseSelection\n";
        } else {
            print "\nUsage: perl SetSysConfig.pl [COM PORT] <test file>; COM port[e.g. COM4] and test file [e.g. TestImu.pl] is mandatory\n";
			exit;
        }              
    }
	else {
        print "\nUsage: perl SetSysConfig.pl [COM PORT] <test file>; COM port[e.g. COM4] and test file [e.g. TestImu.pl] is mandatory\n";
        exit;
	}
		


################### COM PORTS  ########################################
    $| = 1; #enable autoflush

    my $comPortConfigFile = 'Com921600.cfg';
    my $imuBaud   = 921600;
    my $port = new Win32::SerialPort ($port_name) || die "Can't open port: $^E\n";

    # we have to be sure that the 921600 and 4147200 baud is available in the Serial Port
    # interface as it is usually not in the Win32::SerialPort module
    $port->{"_L_BAUD"}{921600} = 921600;
    $port->{"_L_BAUD"}{4147200} = 4147200;
    #print "baud rate: ", join(" ", $port->baudrate), "\n";

    $port->databits(8);
    $port->baudrate(921600);
    $port->parity("none");
    $port->stopbits(1);
    $port->handshake("none");
    $port->buffers(4096, 4096);

    $port->write_settings || undef $port;
    $port->save($comPortConfigFile);
############################################################

#################### MAIN CODE ###############################
	my $systemConfig;
	my $deviceName = "";
	my $i = 0;
	my $deviceType = "";
	GoDebug ($port);	
	$deviceName = TestSystemConfigCommand ($port);
    print "Device Type = $deviceName\r\n";
	if ((index($deviceName,'IMU') != -1)) {
		print "Test Device is a 17XX IMU, test script batch file will proceed\r\n";
		$deviceType = "IMU";
    }
	else {
		print "Test Device is not a 17XX IMU which is required for this test script batch file\r\n";
	exit;
	}
	for ($i = 0, ; $i < 10; $i++) {
		$systemConfig = Get_Config_Type($i);
		TestSetSysConfig ($port,$systemConfig);
		$port = CallMainTest ($port,$port_name,$testFileSelection,$testCaseSelection, $deviceType);
		GoDebug ($port);
	}
	$systemConfig = $deviceName;	
	TestSetSysConfig ($port,$systemConfig);
	TestStart ($port);
	SendDebugCommand($port,"0");
	
################### END OF MAIN  ########################################

################### SUBROUTINES  ########################################

############################################################################
#  GoDebug
#
#  Description: Go into debug node to star test
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
# Go into DEBUG mode;  We should be in Normal Mode when first testing
    # we will use DEBUG mode to change the data rate and process the ?ws command to get the version, etc.
sub GoDebug
{
    my $generalStatus = 1;	
	for (my $indexCount = 0; $indexCount < 4; $indexCount++) {

        $generalStatus = SendDebugCommand($port,"1");

        sleep 1;
        if ($generalStatus == $SUCCESS) {
            print "\n DEBUG Done  $indexCount\r\n";
            TestHalt($port);

            last;
        }
		else {
            print "\n DEBUG RESTART\r\n";
            # we might be in config mode from a previous test so we will send a config,0 to get to normal mode
            SendConfigCommand($port,"0");
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

        exit;
    }
} # End GoDebug
	
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

    }
	else {
        print "System Config Test Failed\r\n";
        $sysConfigDeviceName =  "UNKNOWN_DEVICE";
    }

    return $sysConfigDeviceName;

} # end of TestSystemConfigCommand

############################################################################
#  TestSetSysConfig
#
#  Description: Test the Set System Configuration Command =sysconfig
#
#       Inputs: $portTest         - comport device is on
#               
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
	my $systemConfig = shift;
    my $result = "";
    my $command = "";
	$command = "=sysconfig,$systemConfig";
	$portTest->write($command."\n");
	select(undef, undef, undef, 5.0);  # sleep 3 seconds
	$result = $portTest->input;
	print "=sysconfig command test $result\r\n\r\n";
	$command = "?sysconfig";
	$portTest->write($command."\n");
	select(undef, undef, undef, 0.50);  # sleep 1.5 seconds
	$result = $portTest->input;
	# remove the carriage return line feed;
	$result =~ s/\r|\n//g;
	print "Result of ?sysconfig = $result\r\n";
	if ((index($result,"$systemConfig") != -1)) {
		print "=sysconfig command Passed\r\n";
    }
	else {
		print "=sysconfig command Failed\r\n";
	}
	
#exit;
}
    
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
#  SendDebugCommand
#
#  Description: Send the Debug command to enter or exit DEBUG mode
#
#       Inputs: $portTest         - comport device is on
#               $dataValue        - value to use in the command - 0 to Exit and 1 to Enter DEBUG mode
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
    my $testStatus = $SUCCESS;
    my $substr = "DEBUG";
    my $invalidString = "INVALID"; # this can occur if we are in CONFIG mode
                                   # and we are trying to get into DEBUG mode

    my $command = "=debug,$dataValue";

    $portTest->write($command."\r\n");

    select(undef, undef, undef, 0.75);  # sleep 1/2 second
    my $result = $portTest->input;
    print "Debug result = $result\r\n";

    if ((index($result, $invalidString) != -1)) {
        print "DEBUG test \t\t\tFailed\r\n";
        $testStatus = $FAILED;   
    } else {

        if (index($result, $substr) != -1) {

            print "DEBUG set test \t\t\tPassed\r\n\r\n";
            $testStatus = $SUCCESS;
         } else {
            print "DEBUG test \t\t\tFailed\r\n";
            $testStatus = $FAILED;
        }
    }
    

    return $testStatus;
} # end of SendDebugCommand

############################################################################
#  SendConfigCommand
#
#  Description: Test the Set/Clear Config Mode Command =config,X where X is
#				1 Enter Config Mode or 0 Exit Config Mode
#
#       Inputs: $portTest         - comport device is on
#               $dataValue        - value to use in the command - 0 to Exit and 1 to Enter CONFIG mode
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
    my $testStatus = $SUCCESS;

    my $command = "=config,$dataValue";
	my $result = $portTest->input;
    $portTest->lookclear;
    $portTest->write($command."\n");
    select(undef, undef, undef, 0.50);  # sleep 1/4 second 250 milliseconds
    $result = $portTest->input;

    print "Config result = $result";
    my $substr = "CONFIG";
    if (index($result, $substr) != -1) {
        print "=config,$dataValue Test \t\t\tPassed\r\n\r\n";
        $testStatus = $SUCCESS;
    } else {
        print "=config,$dataValue Test \t\t\tFailed\r\n";
        $testStatus = $FAILED;
    }
    
    return $testStatus;
} # end of SendConfigCommand

############################################################################
#  TestHalt
#
#  Description: Test halt command
#
#       Inputs: $portTest         - comport device is ons
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
    my $haltStatus = "=halt";

    $portTest->write($haltStatus."\n");

    select(undef, undef, undef, 0.15);  # sleep 1/4 second 250 milliseconds
    my $result = $portTest->input;
    print "HALT result = $result\r\n";
    my $substr = "HALT";
    if (index($result, $substr) != -1) {
        print "HALT set test \t\t\tPassed\r\n\r\n";
        return 1;
    } else {
        print "HALT test \t\t\tFailed\r\n";
        return 0;
    }
    
} # end of TestHalt

############################################################################
#  TestStart
#
#  Description: Test start command
#
#       Inputs: $portTest         - comport device is ons
#               
#      Returns: Success or Failure - 0 or 1
#
# Side Effects: None
#
#        Notes: Only available after debug command and in DEBUG mode
#
############################################################################
sub TestStart
{
    my $portTest       = shift;
    my $startStatus = "=start";

    $portTest->write($startStatus."\n");

    select(undef, undef, undef, 0.15);  # sleep 1/4 second 250 milliseconds
    my $result = $portTest->input;
    print "Start result = $result\r\n";
    my $substr = "START";
    if (index($result, $substr) != -1) {
        print "START set test \t\t\tPassed\r\n\r\n";
        return 1;
    } else {
        print "START test \t\t\tFailed\r\n";
        return 0;
    }
    
} # end of TestStart

############################################################################
#  CallMainTest
#
#  Description: Call The Main Test Script and Run Tests For Selected FOG type
#
#       Inputs: $port         - comport device is ons
#				$port_name	-name of port ie. com4
#               
#      Returns: none
#
# Side Effects: None
#
#        Notes: None
#
############################################################################

sub CallMainTest
{
my $port = shift;
my $port_name = shift;
my $testFile = shift;
my $testCase = shift;
my $deviceType = shift;
$port->close || warn "Comport Close Failed!\r\n";
undef $port;
my $command = ('perl ' . $testFile . ' ' . $port_name . ' ' . $testCase . ' ' . $deviceType);
print "System Command = $command\r\n";
system ($command);
$port = new Win32::SerialPort ($port_name) || die "Can't open port: $^E\n";
#portRestart();
return ($port);
	
} #End CallMainTest

