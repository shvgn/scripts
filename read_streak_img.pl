#!/usr/bin/env perl

use Modern::Perl;         
use File::Slurp qw( read_file );
use Data::Dumper;

my $filename = shift @ARGV;
open my $fh, "<", $filename or die "$!"; 
# my $status = read( $fh, ...);

my $filecontent  = read_file( $filename ); # The img file size is about 2.1 Mb

# my $data = '[Application],Date="07-01-2014",Time="14:02:07",Software="HPD-TA",Application=2,ApplicationTitle="High Performance Digital Temporal Analyzer",SoftwareVersion="8.2.0 pf3",SoftwareDate="17.01.2008"
# [Camera],AMD=N,NMD=F,EMD=E,SMD=N,ADS=10,SHT=1,FBL=90,EST=1,SHA=K,SFD=F,SPX=2,TNS=1,ATP=N,CEG=0,CEO=0,ESC=B,TimingMode="Internal timing",TriggerMode="Edge trigger",TriggerSource="BNC",VerticalBinning="1",TapNo="1",TriggerPolarity="neg.",CCDArea="1024 x 1024",Binning="2 x 2",ScanMode="Normal",NoLines=1024,CameraName="C4742-95-10NR",Type=7,SubType=7
# [Acquisition],NrExposure=1,NrTrigger=0,ExposureTime=10 s,AcqMode=4,DataType=4,DataTypeOfSingleImage=2,CurveCorr=0,DefectCorrection=0,areSource="0,0,1024,1024",areGRBScan="0,0,1024,1024",pntOrigCh="128,0",pntOrigFB="0,0",pntBinning="1,1",BytesPerPixel=2,IsLineData=0,BacksubCorr=-1,ShadingCorr=0,ZAxisLabel=Intensity,ZAxisUnit=Count
# [Grabber],ConfigFile="C:\Program Files\HPDTA\HPDTA820\digital.cnf",Type=2,SubType=1,ICPMemSize=0
# [DisplayLUT],EntrySize=4,LowerValue=0,UpperValue=561,BitRange="16 bit",Color=2,LUTType=0,LUTInverted=0,DisplayNegative=0,Gamma=1,First812OvlCol=1,Lut16xShift=0,Lut16xOvlVal=32767
# [ExternalDevices],TriggerDelay=150,PostTriggerTime=10,ExposureTime=10,TDStatusCableConnected=0,ConnectMonitorOut=0,ConnectResetIn=0,TriggerMethod=0,UseDTBE=0,A6538Connected=0,CounterBoardInstalled=-1,GPIBInstalled=-1,CounterBoardIOBase=560,GPIBIOBase=0
# [Streak camera],UseDevice=-1,DeviceName="C5680",PluginName="M5675",GPIBCableConnected=-1,GPIBBase=8,Time Range="4",Mode="Operate",Gate Mode="Normal",MCP Gain="18",Shutter="Open",Gate Time="0",Delay="0",FocusTimeOver="5"
# [Spectrograph],UseDevice=-1,DeviceName="Chromex 500IS",PluginName="",GPIBCableConnected=-1,GPIBBase=9,Wavelength="285",Grating="150 g/mm",Slit Width="100",Blaze="500",Ruling="150",Mode="Spectrogr.",Exit Slit Width="0"
# [Delay box],UseDevice=-1,DeviceName="C6878",PluginName="",GPIBCableConnected=-1,GPIBBase=11,Delay Time="10800",Lock Mode="Unlocked",Device Status="O.K."
# [Delay2 box],UseDevice=0
# [Scaling],ScalingXType=2,ScalingXScale=1,ScalingXUnit="nm",ScalingXScalingFile=*2099448,ScalingYType=2,ScalingYScale=9.775171E-04,ScalingYUnit="ps",ScalingYScalingFile=*2103544[Comment],UserComment=""'; 

# This starting thing must be changed to those used in matlab script. The very beginning of an image file contains info
# about the length and position of this information line. 
my $start = index $filecontent, '[Application]';
my $end   = index $filecontent, 'UserComment';

$end	  = index $filecontent, '"', ++$end; # First double quote
$end	  = index $filecontent, '"', ++$end; # Second double quote 
while ( substr($filecontent, $end-1, 1) eq '\\' ) {
	# Avoid escaped secodn double quote
	$end = index $filecontent, '"', ++$end; 
}


my $textdata = substr $filecontent, $start, $end-$start+1;



my %data = ();

# sub saysep {
# 	say '-' x 90;
# }







# Turn strings "...,key1=value1,key2=value2,..." into hash {..., key1 => value1, key2 => value2, ...}
# FIXME UserComment containig doublequotes will break 
sub make_hash_ref {
	
	my $string = shift;

	# Clean carriage return symbol
	$string =~ s/\r//g;

	# One special case here in the 'Axquisition' section
	# We catch commas inside double quotes "0,0", "1,1", "0,0,1024,1024"
	my $specsymbol = 'ti8LNqOe45wesy3WzW0Wh7mxCVdHCTucQm'; # Pretty random :) Not elegant though.
	$string =~ s/"(\d{1,4}),(\d{1,4}),(\d{1,4}),(\d{1,4})"/"$1$specsymbol$2$specsymbol$3$specsymbol$4"/g;
	$string =~ s/"(\d{1,4}),(\d{1,4})"/"$1$specsymbol$2"/g;

	# Now we can split the string by commas.
	my @pairs = split ',', $string;
	# ...and place it in a hash
	my $href  = { map { my ($k, $v) = split '='; $k => $v } @pairs };
	
 	
	%$href = map {

		my $v = $$href{$_}; 
		# ...and delete all double quotes
		$v =~ s/"//g;
		
		if ($v =~ $specsymbol) {
			# ...and let arrays become real ones!
			my @a = grep { $_ ne '' } split ( $specsymbol, $v ); 
			$v = \@a;
		}

		$_ => $v 

	} keys %$href;
	
	# say Dumper $href;
	return $href;
}






sub make_matlab_struct_eval {}








my @splitted = split '\[', $textdata;
shift @splitted; 		# No need to keep the first empty string
chomp for @splitted;	# And newlinws, too


# Now we are going to make sections which are keys in the data hash
%data = map { 	
			my ($k, $v) = split '],';    
			$k => $v 
		} @splitted;

# And adding nested hashed to that keys instead of strings
%data = map { $_ => make_hash_ref $data{$_} } keys %data;


# say Dumper %data;
# say $_ . ' -- ' . $data{Acquisition}{$_}  for keys %{ $data{Acquisition} };
# say  $data{Acquisition}{ZAxisUnit};





# Read scaling binary data and unpack it to array of floats
sub scaling_from_file {

	my ( $fh, $scaling_pos, $len ) = @_;

	$scaling_pos =~ s/\*//g;
	my $sz = 32;   # float32 size

	binmode( $fh );
	seek( $fh, $scaling_pos, 0 );

	my $status = read( $fh, my $scaling_bin, $len*$sz );
	my @scaling = unpack( 'f' . $len, $scaling_bin);

	# return @scaling if wantarray; # Do I need this? 
	return \@scaling;
}





my $scale_sz_wavelength = 1024;
my $scale_sz_time		= 1280;


$data{ Scaling }{ ScalingX } = scaling_from_file( $fh, 
												$data{ Scaling }{ ScalingXScalingFile }, 
												$scale_sz_wavelength  );
$data{ Scaling }{ ScalingY } = scaling_from_file( $fh, 
												$data{ Scaling }{ ScalingYScalingFile }, 
												$scale_sz_time		  );

# say Dumper %data;





__END__



Source info example:


[Application],Date="07-01-2014",Time="14:02:07",Software="HPD-TA",Application=2,ApplicationTitle="High Performance Digital Temporal Analyzer",SoftwareVersion="8.2.0 pf3",SoftwareDate="17.01.2008"
[Camera],AMD=N,NMD=F,EMD=E,SMD=N,ADS=10,SHT=1,FBL=90,EST=1,SHA=K,SFD=F,SPX=2,TNS=1,ATP=N,CEG=0,CEO=0,ESC=B,TimingMode="Internal timing",TriggerMode="Edge trigger",TriggerSource="BNC",VerticalBinning="1",TapNo="1",TriggerPolarity="neg.",CCDArea="1024 x 1024",Binning="2 x 2",ScanMode="Normal",NoLines=1024,CameraName="C4742-95-10NR",Type=7,SubType=7
[Acquisition],NrExposure=1,NrTrigger=0,ExposureTime=10 s,AcqMode=4,DataType=4,DataTypeOfSingleImage=2,CurveCorr=0,DefectCorrection=0,areSource="0,0,1024,1024",areGRBScan="0,0,1024,1024",pntOrigCh="128,0",pntOrigFB="0,0",pntBinning="1,1",BytesPerPixel=2,IsLineData=0,BacksubCorr=-1,ShadingCorr=0,ZAxisLabel=Intensity,ZAxisUnit=Count
[Grabber],ConfigFile="C:\Program Files\HPDTA\HPDTA820\digital.cnf",Type=2,SubType=1,ICPMemSize=0
[DisplayLUT],EntrySize=4,LowerValue=0,UpperValue=561,BitRange="16 bit",Color=2,LUTType=0,LUTInverted=0,DisplayNegative=0,Gamma=1,First812OvlCol=1,Lut16xShift=0,Lut16xOvlVal=32767
[ExternalDevices],TriggerDelay=150,PostTriggerTime=10,ExposureTime=10,TDStatusCableConnected=0,ConnectMonitorOut=0,ConnectResetIn=0,TriggerMethod=0,UseDTBE=0,A6538Connected=0,CounterBoardInstalled=-1,GPIBInstalled=-1,CounterBoardIOBase=560,GPIBIOBase=0
[Streak camera],UseDevice=-1,DeviceName="C5680",PluginName="M5675",GPIBCableConnected=-1,GPIBBase=8,Time Range="4",Mode="Operate",Gate Mode="Normal",MCP Gain="18",Shutter="Open",Gate Time="0",Delay="0",FocusTimeOver="5"
[Spectrograph],UseDevice=-1,DeviceName="Chromex 500IS",PluginName="",GPIBCableConnected=-1,GPIBBase=9,Wavelength="285",Grating="150 g/mm",Slit Width="100",Blaze="500",Ruling="150",Mode="Spectrogr.",Exit Slit Width="0"
[Delay box],UseDevice=-1,DeviceName="C6878",PluginName="",GPIBCableConnected=-1,GPIBBase=11,Delay Time="10800",Lock Mode="Unlocked",Device Status="O.K."
[Delay2 box],UseDevice=0
[Scaling],ScalingXType=2,ScalingXScale=1,ScalingXUnit="nm",ScalingXScalingFile=*2099448,ScalingYType=2,ScalingYScale=9.775171E-04,ScalingYUnit="ps",ScalingYScalingFile=*2103544[Comment],UserComment=""


Parsed info exmaple:


$VAR1 = 'Delay box';
$VAR2 = {
          'DeviceName' => 'C6878',
          'GPIBCableConnected' => '-1',
          'GPIBBase' => '11',
          'Lock Mode' => 'Unlocked',
          'UseDevice' => '-1',
          'Delay Time' => '10800',
          'Device Status' => 'O.K.',
          'PluginName' => ''
        };
$VAR3 = 'Application';
$VAR4 = {
          'SoftwareVersion' => '8.2.0 pf3',
          'Date' => '07-01-2014',
          'ApplicationTitle' => 'High Performance Digital Temporal Analyzer',
          'Application' => '2',
          'SoftwareDate' => '17.01.2008',
          'Software' => 'HPD-TA',
          'Time' => '14:02:07'
        };
$VAR5 = 'Streak camera';
$VAR6 = {
          'Delay' => '0',
          'GPIBCableConnected' => '-1',
          'GPIBBase' => '8',
          'Time Range' => '4',
          'MCP Gain' => '18',
          'Mode' => 'Operate',
          'Shutter' => 'Open',
          'Gate Time' => '0',
          'Gate Mode' => 'Normal',
          'DeviceName' => 'C5680',
          'PluginName' => 'M5675',
          'UseDevice' => '-1',
          'FocusTimeOver' => '5'
        };
$VAR7 = 'Spectrograph';
$VAR8 = {
          'PluginName' => '',
          'Slit Width' => '100',
          'Wavelength' => '285',
          'UseDevice' => '-1',
          'Grating' => '150 g/mm',
          'Mode' => 'Spectrogr.',
          'GPIBCableConnected' => '-1',
          'Blaze' => '500',
          'GPIBBase' => '9',
          'Ruling' => '150',
          'DeviceName' => 'Chromex 500IS',
          'Exit Slit Width' => '0'
        };
$VAR9 = 'ExternalDevices';
$VAR10 = {
           'ExposureTime' => '10',
           'TDStatusCableConnected' => '0',
           'GPIBIOBase' => '0',
           'PostTriggerTime' => '10',
           'UseDTBE' => '0',
           'A6538Connected' => '0',
           'CounterBoardInstalled' => '-1',
           'GPIBInstalled' => '-1',
           'CounterBoardIOBase' => '560',
           'TriggerDelay' => '150',
           'ConnectMonitorOut' => '0',
           'TriggerMethod' => '0',
           'ConnectResetIn' => '0'
         };
$VAR11 = 'Grabber';
$VAR12 = {
           'ICPMemSize' => '0',
           'ConfigFile' => 'C:\\Program Files\\HPDTA\\HPDTA820\\digital.cnf',
           'SubType' => '1',
           'Type' => '2'
         };
$VAR13 = 'Comment';
$VAR14 = {
           'UserComment' => ''
         };
$VAR15 = 'Scaling';
$VAR16 = {
           'ScalingXScale' => '1',
           'ScalingXUnit' => 'nm',
           'ScalingYScale' => '9.775171E-04',
           'ScalingXScalingFile' => '*2099448',
           'ScalingYScalingFile' => '*2103544',
           'ScalingYUnit' => 'ps',
           'ScalingXType' => '2',
           'ScalingYType' => '2'
         };
$VAR17 = 'DisplayLUT';
$VAR18 = {
           'BitRange' => '16 bit',
           'Color' => '2',
           'First812OvlCol' => '1',
           'LUTInverted' => '0',
           'LowerValue' => '0',
           'Gamma' => '1',
           'UpperValue' => '561',
           'EntrySize' => '4',
           'LUTType' => '0',
           'Lut16xShift' => '0',
           'DisplayNegative' => '0',
           'Lut16xOvlVal' => '32767'
         };
$VAR19 = 'Acquisition';
$VAR20 = {
           'ZAxisLabel' => 'Intensity',
           'IsLineData' => '0',
           'pntBinning' => [
                             '1',
                             '1'
                           ],
           'CurveCorr' => '0',
           'ExposureTime' => '10 s',
           'areSource' => [
                            '0',
                            '0',
                            '1024',
                            '1024'
                          ],
           'AcqMode' => '4',
           'pntOrigFB' => [
                            '0',
                            '0'
                          ],
           'BacksubCorr' => '-1',
           'areGRBScan' => [
                             '0',
                             '0',
                             '1024',
                             '1024'
                           ],
           'NrExposure' => '1',
           'NrTrigger' => '0',
           'DataType' => '4',
           'ShadingCorr' => '0',
           'pntOrigCh' => [
                            '128',
                            '0'
                          ],
           'DataTypeOfSingleImage' => '2',
           'BytesPerPixel' => '2',
           'ZAxisUnit' => 'Count',
           'DefectCorrection' => '0'
         };
$VAR21 = 'Delay2 box';
$VAR22 = {
           'UseDevice' => '0'
         };
$VAR23 = 'Camera';
$VAR24 = {
           'ScanMode' => 'Normal',
           'SHT' => '1',
           'NoLines' => '1024',
           'TriggerMode' => 'Edge trigger',
           'SPX' => '2',
           'NMD' => 'F',
           'Binning' => '2 x 2',
           'ESC' => 'B',
           'Type' => '7',
           'SubType' => '7',
           'TNS' => '1',
           'CameraName' => 'C4742-95-10NR',
           'SHA' => 'K',
           'CCDArea' => '1024 x 1024',
           'CEO' => '0',
           'ATP' => 'N',
           'SFD' => 'F',
           'EST' => '1',
           'VerticalBinning' => '1',
           'TimingMode' => 'Internal timing',
           'FBL' => '90',
           'SMD' => 'N',
           'EMD' => 'E',
           'TapNo' => '1',
           'TriggerPolarity' => 'neg.',
           'CEG' => '0',
           'ADS' => '10',
           'TriggerSource' => 'BNC',
           'AMD' => 'N'
         };
