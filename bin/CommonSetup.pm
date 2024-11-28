# 
# $Header: install/utl/scripts/db/CommonSetup.pm.pp /st_install_19/2 2018/11/23 07:35:05 josepe Exp $
#
# CommonSetup.pm
# 
# Copyright (c) 2017, 2018, Oracle and/or its affiliates. All rights reserved.
#
#    NAME
#      CommonSetup.pm - Common Setup perl module
#
#    DESCRIPTION
#      Contains the common code to launch the setup scripts.
#
#    MODIFIED   (MM/DD/YY)
#    apfwkr      11/21/18 - Backport josepe_bug-28911311 from main
#    vansoni     09/11/18 - XbranchMerge vansoni_dicdi-2581 from main
#    josepe      11/15/18 - BUG_28911311 Changing current directory before
#                           perform find command.
#    vansoni     09/04/18 - removing inventory/Scripts/ext/jlib from classpath
#    davjimen    08/27/18 - detect if linux should be used instead of linux64
#    davjimen    08/23/18 - add flag to showAdditionalInfo
#    rfgonzal    07/13/18 - DICDI2508 - Move rootPreCheck after getImageInfo
#    davjimen    07/13/18 - fix oui library location
#    davjimen    07/09/18 - add function to determine d64 flag
#    davjimen    06/21/18 - detect if win32 should be used instead of win64
#    davjimen    06/20/18 - add jwc-cred.jar into classpath
#    davjimen    05/28/18 - add custom max heap size method
#    davjimen    05/16/18 - flag -d64 not required in aix
#    davjimen    03/08/18 - add client setup changes
#    poosrini    12/18/17 - use LIBMAJORVSN in place of DB_VERSION_FIRST_DIGIT
#    davjimen    12/07/17 - support orch tool launch
#    lorajan     09/15/17 - Adding mgmtua.jar in the classpath for mgmtua
#                           downgrade support.
#    rfgonzal    09/13/17 - bug 26788168 - rootpre.sh is not required for DB in
#                           Solaris
#    rfgonzal    08/30/17 - add image info
#    davjimen    08/23/17 - remove multiple slashes from oracle home path
#    davjimen    08/17/17 - remove destinationHome message
#    poosrini    08/01/17 - oraclepki
#    davjimen    07/10/17 - clear quotes from expansible args and set ours
#    davjimen    07/06/17 - support applyRU and applyRUR to apply PSU
#    davjimen    06/26/17 - bug 26351914 - create method to calculate 
#                           the temp log directory
#    davjimen    06/22/17 - add quotes to some args to not expand
#    davjimen    06/15/17 - lrg 20368653 - set oui library location
#    rtattuku    06/12/17 - Library version change from 12 to 18
#    vansoni     06/12/17 - -version support removed
#    davjimen    05/16/17 - add mgmtca and clscred jars to the classpath
#    apperuma    04/20/17 - Set printtime option if its passed
#    lorajan     03/22/17 - Adding pilot jar in the classpath.
#    davjimen    01/06/17 - Creation
# 
use Cwd qw(abs_path);
use File::Basename;
use File::Path qw(make_path remove_tree);
use File::Copy qw(cp mv);
use File::Find;
use Time::Piece;

package CommonSetup;
	
sub new {
	my $class = shift;
	my %params = @_;
	my $self = {
		"TYPE" => $params{"TYPE"},
		"PRODUCT_DESCRIPTION" => $params{"PRODUCT_DESCRIPTION"},
		"PRODUCT_JAR_NAME" => $params{"PRODUCT_JAR_NAME"},
		"SETUP_SCRIPTS" => $params{"SETUP_SCRIPTS"},
		"LOG_DIR_PREFIX" => $params{"LOG_DIR_PREFIX"},
		"MAIN_CLASS" => $params{"MAIN_CLASS"},
	};
	bless $self, $class;
	return $self;
}

# The current platform
my $PLATFORM=$^O;

# The architecture and the platform directory name
my ($ARCH,$PLATFORM_DIRECTORY_NAME) = &determinePlatformDirName();

# The ID of the user
my $ID = exists($ENV{ID}) ? $ENV{ID} : '/usr/bin/id';

# The user name
my $user;

# Flag to determine if the current platform is Windows
my $isWindows = ($PLATFORM =~ /.*MSWin.*/) ? 1 : 0;

# The directory separator
my $dirSep = '';

# The classpath separator
my $pathSep;

# The Oracle home path
my $ORACLE_HOME = "";

# The scratch path
my $scratchPath = "";

# The timestamp
my $timestamp = "";

# The temporary location
my $tmpLoc = "";

# The temporary log directory
my $tempLogDir = "";
	
# Path to the OUI platform directory
my $OUI_LIBRARY_LOCATION = "";

# Determine the classpath
my $classPath = "";

# Generic arguments
my $printTimeArg = "-printtime";
my $noWaitArg = "-nowait";
my $debugArg = "-debug";
my $javaDebugArg = "-javadebug";

# Pilot variables
my $launchPilot = "false";
my $pluginArg = "-plugin";

# Generic variables
my $printtime="-printtime";
my $noWait="false";
my $debug="false";
my $debugOpts='';
my $javadebug="false";
my $javadebugOpts='';
my $maxHeapSizeArg="";
my $defaultMaxHeapSize="-Xmx2048m";

# JRE location variables
my $JRELOC = "";
my $customJRE = 'false';
my $jreLocArg = '-jreLoc';

# define the patching variables
# PSU variables
my $patchTypePSU = '-applyPSU';
my $patchTypeRU = '-applyRU';
my $patchTypeRUR = '-applyRUR';
my $applyingPSU = 'false';
# OneOffs variables
my $patchTypeOneOffs = '-applyOneOffs';
my $applyingOneOffs = 'false';
# OPatch variables
my $updatingOpatch = 'false';
my $opatchLocArg = '-opatchLocation';
my $skipOpatchVersionArg = '-skipOpatchVersionCheck';
# Generic patch variables
my $patching = 'false'; # To deterine if a patch will be applied
my @patchArgs; # To carry all the patch related arguments passed.
my $applyInstallerUpdatesArg = "-applyInstallerUpdates";
my $applyingInstallerUpdates = 'false';
my $revertArg = "-revert";
my $revertingInstallerUpdate = 'false';
my $skipPatchStatusCheckArg = "-skipPatchStatusCheck";
my $skipPatchStatusCheck = 'false';

# bug 18154139 - support -J option (-J-m -J-D properties)
my @javaOptions;
my @remainingArgs;
my $javaOptionsSize = @ARGV;

# The destination oracle home path
my $dstoraclehome = "";
my $destinationHomeArg = "-destinationHome";

# The java binary
my $JAVACMD = "";

# bug 21613196 - wa for jdk bug 8060036
my $jdkBug8060036WA = ' -XX:-OmitStackTraceInFastThrow -XX:CompileCommand=quiet -XX:CompileCommand=exclude,javax/swing/text/GlyphView,getBreakSpot ';	

# The wizard command
my $wizardCmd = "";

# Image info variables
my $printImageInfoArg = "-printImageInfo";
my $printImageInfo = 'false';
my $showAdditionalInfoArg = "-showAdditionalInfo";
my $showAdditionalInfo = 'false';

# Exit code of the module
return 1;

sub main {
	my ($self, @args) = @_;
  
	# The directory separator
	$dirSep = $self->getDirSep();

	# The classpath separator
	if ($isWindows)  {
		$pathSep = ';';
	} else {
		$pathSep = ':';
	}

	# Determine the ORACLE_HOME
	$ORACLE_HOME = $self->determineOracleHome();

	# Root and Administrator user check
	$self->rootAndAdminUserCheck();

	# Parse the arguments
	$self->parseArgs();

	# Check if pilot is to be launched
	$self->checkPilotLaunch();

	# Check if its a change destination home action
	$self->changeDestinationHome();
	
	# Perform home ownership checks
	$self->homeOwnershipChecks();
	
	# The timestamp
	$timestamp = $self->calculateTimestamp();
	
	# The temporary location
	$tmpLoc = $self->calculateTempLoc();

	# The temporary log directory
	$tempLogDir = $self->calculateTempLogDir();
	
	# Create temporary log directory
	$self->createTempDirectory();
	
	# Get the JRE location
	$JRELOC = $ORACLE_HOME.$dirSep.'jdk'.$dirSep.'jre';

	# Path to the OUI platform directory
	$OUI_LIBRARY_LOCATION = getOUILibLoc($PLATFORM_DIRECTORY_NAME);
	
	# Determine the classpath
	$classPath = $self->getClassPath();
	
	# Set env variables and library path
	$self->setLdLibraryPath($ORACLE_HOME);
	
	# Get the java binary for the java command
	$JAVACMD = $self->getJavaCmd($PLATFORM, $JRELOC, $dirSep, $PLATFORM_DIRECTORY_NAME);

	# bug 21020114 - add java memory options
	push(@javaOptions, "-Xms150m");

	$maxHeapSizeArg = $self->getMaxHeapSizeArg($PLATFORM_DIRECTORY_NAME, $JAVACMD, $defaultMaxHeapSize);
	push(@javaOptions, $maxHeapSizeArg);
	
	# Print image info
	$self->getImageInfo();

	# Check the patch actions
	$self->checkPatchActions();
	
	# Unsetting ORA_CRS_HOME Env Variable.
	delete $ENV{ORA_CRS_HOME};

        # Root pre check
        $self->rootPreCheck();
	
	# Set the wizard command
	$wizardCmd = $self->setWizardCmd($self->{"MAIN_CLASS"});
	
	# Run the wizard command
	$self->runWizardCmd();
}

sub getOUILibLoc() {
	my $platform = shift;
	my $homeOUILib = $ORACLE_HOME.$dirSep.'oui'.$dirSep.'lib';
	my $loc = $homeOUILib.$dirSep.$platform;
	# bug 28220339 - detect the right win64/32 directory
	if($platform eq "win") {
		my $winloc = $loc.'64';
		if(! -d $winloc) {
			$winloc = $loc.'32';
		}
		$loc = $winloc;
	} elsif($platform eq "linux") {
		# bug 28558563 - detect the right linux64/linux directory
		my $linuxloc = $loc.'64';
		if(! -d $linuxloc) {
			$linuxloc = $loc;
		}
		$loc = $linuxloc;
	}
	return $loc;
}

sub getMaxHeapSizeArg() {
	# bug 21297469 - change memory to 2GB
	return $defaultMaxHeapSize;
}

sub launchPilot() {
	my $self = shift;
	my $oracleHome = $ENV{ORACLE_HOME};
	
	my $pilotCmd = $oracleHome.$dirSep."install".$dirSep."pilot"." ".join(' ',@ARGV);
	my $pilotCode = $self->runCommand($pilotCmd);
	$self->terminate($pilotCode);
}

sub checkPilotLaunch() {
	my $self = shift;

	if($launchPilot eq "true") {
		$self->launchPilot();
	}
}

sub determineOracleHome() {
	my $self = shift;
	my $oracleHome = $ENV{ORACLE_HOME};
	
	# bug 26098267 - Remove multiple slashes in a row
	$oracleHome =~ s/[\/]+/\//g;
	
	# Re-set the ORACLE_HOME env variable
	$ENV{ORACLE_HOME} = $oracleHome;

	return $oracleHome;
}

sub calculateTempLogDir() {
	my $self = shift;
	return $tmpLoc.$dirSep.$self->{"LOG_DIR_PREFIX"}.$timestamp;
}

sub createTempDirectory() {
	mkdir($tempLogDir);
}

sub getDirSep() {
	my ($self, @args) = @_;
	my $sep = '';
	if ($isWindows)  {
		$sep = '\\';
	} else {
		$sep = '/';
	}
	return $sep;
}

sub determinePlatformDirName() {
	if($PLATFORM=~/.*hpux.*/) {
		$ARCH=`uname -m`;
		if($ARCH=~/.*ia64.*/) {
			$PLATFORM_DIRECTORY_NAME="hpia64";
		} else {
			$PLATFORM_DIRECTORY_NAME="hpunix";
		}
	} elsif($PLATFORM=~/.*aix.*/) {
		$PLATFORM_DIRECTORY_NAME="aix";
	} elsif($PLATFORM=~/.*linux.*/) {
		$ARCH=`uname -m`;
		if($ARCH=~/.*x86_64.*/) {
			$PLATFORM_DIRECTORY_NAME="linux";
		} elsif($ARCH=~/.*ppc64.*/) {
			$PLATFORM_DIRECTORY_NAME="linuxppc64";
		} elsif($ARCH=~/.*s390x.*/) {
			$PLATFORM_DIRECTORY_NAME="linuxS390";
		} else {
			$PLATFORM_DIRECTORY_NAME="linux";
		}
	} elsif($PLATFORM=~/.*solaris.*/) {
		# bug 20399971 - use uname -p to get solaris architecture
		$ARCH=`uname -p`;
		if($ARCH=~/.*sparc.*/) {
			$PLATFORM_DIRECTORY_NAME="solaris";
		} else {
			$PLATFORM_DIRECTORY_NAME="intelsolaris";
		}
	} elsif($PLATFORM=~/.*MSWin.*/) {
		$PLATFORM_DIRECTORY_NAME="win";
	}
	
	return($ARCH, $PLATFORM_DIRECTORY_NAME)
}

sub calculateTempLoc() {
	my $tmpLoc = $ENV{TEMP};
	if(! defined $tmpLoc or "$tmpLoc" eq "") {
		$tmpLoc = $ENV{TMP};
		if(! defined $tmpLoc or "$tmpLoc" eq "") {
			$tmpLoc = $ENV{TMPDIR};
			if(! defined $tmpLoc or "$tmpLoc" eq "") {
				if($PLATFORM=~/.*MSWin.*/) {
					$tmpLoc = 'C:'.$dirSep.'temp';
					} else {
					$tmpLoc = "/tmp";
				}
			}
		}
	}
	return $tmpLoc;
}

sub rootAndAdminUserCheck() {
	
	# Check is not root user
	if (! $isWindows) {
		my $id = `$ID`;
		$id =~ /.*?\((\w+)\).*/;
		$user = $1;
		
		# check for non-root user
		if ($user eq 'root') {
			print "\nERROR: You must not be logged in as root to run this tool.\n";
			exit 1;
		}
	}

	# check in windows if user is non-admin
	if ($isWindows) {
		require Win32;
		if(! Win32::IsAdminUser()) {
			print "\nERROR: You must be logged in as an Administrator user to run this tool.\n";
			exit 1;
		}
	}
}

sub getVersion() {
	my ($self, @args) = @_;

	my $jarName = $self->{"PRODUCT_JAR_NAME"};
	
	if($jarName) {
		# check all args and if -version or -v is there then show the version and exit immediately
		# don't proceed further
		my $versionExists = "false";
		for(my $cntval = 0; $cntval < @ARGV; $cntval++) {
			if(lc($ARGV[$cntval]) eq "-version" || lc($ARGV[$cntval]) eq "-v") {
				$versionExists ="true";
			}
		}
		if($versionExists eq "true") {
			# check for instcrs jar
			my $crs_jar_loc = $ENV{ORACLE_HOME}.$dirSep.'install'.$dirSep.'jlib'.$dirSep.$jarName;
			if (-f $crs_jar_loc){	
				my $unzip_loc = "";	 
				if ($isWindows)  {
					$unzip_loc = $ENV{ORACLE_HOME}.$dirSep.'bin'.$dirSep.'unzip.exe';
				} else {
					$unzip_loc = $ENV{ORACLE_HOME}.$dirSep.'bin'.$dirSep.'unzip';
				}
				
				my $manifestDir = 'META-INF'.$dirSep.'MANIFEST.MF';   
				my $jarManifestInfo = `$unzip_loc -p $crs_jar_loc $manifestDir`;
				
				# check for status of last executed cmd
				if(($? == -1) || ($jarManifestInfo eq '') || (not defined $jarManifestInfo) || ($jarManifestInfo =~ /^ *$/) || (
				$jarManifestInfo =~ /^\s*$/) ){
					print "\nERROR: Failed to retrive version info.\n";
					exit 1;
				} else {
					# remove unwanted new lines
					chomp($jarManifestInfo);
					
					# When we create a JAR file,
						# The manifest's entries take the form of "header: value" pairs.
					# The name of a header is separated from its value by a colon.
					my @values = split(':', $jarManifestInfo);
					
					# jarManifest value array not empty
					# the product version header is always be the last value
					if(@values){
						print "$values[-1]\n";
					}
					exit;
				}
			}
		}
	}
}

sub changeDestinationHome() {
	my ($self, @args) = @_;
	
	my $setupScripts = $self->{"SETUP_SCRIPTS"};
	
	if($setupScripts) {
		if($dstoraclehome) {

			my $setupScript;
			if($isWindows) {
				$setupScript = $dstoraclehome.$dirSep.(split(',', $setupScripts))[1];
			} else {
				$setupScript = $dstoraclehome.$dirSep.(split(',', $setupScripts))[0];
			}

			$|++; #autoflush stdout
			my $ohDir=$ENV{ORACLE_HOME};
			
			# Check that all the files from the source home are readable by the current user
			if(! $isWindows) {
				my $readAll=$self->areAllFilesReadable($ohDir);
				if("$readAll" eq "false") {
					print "ERROR: Unable to copy the software to the specified location ($dstoraclehome). Ensure user ($user) has read access over the source software home ($ohDir).\n";
					exit(-1);
				}
			}
			
			my $filecnt=0;
			if(-f $dstoraclehome){
				print "ERROR: Target location ($dstoraclehome) should not be a file.\n";
				exit(-1);
			}
			if(! -d $dstoraclehome) {
				File::Path::make_path($dstoraclehome) or die "mkdir failed: $!";
			} else{
				opendir(DIR, "$dstoraclehome") or die "Cant open $dstoraclehome: $!\n";
				my @files = readdir(DIR);
				closedir(DIR);
				if(@files){
					foreach (@files) {
						if( ("$_" ne ".") and ("$_" ne "..") ) {
							print "ERROR: Target location ($dstoraclehome) should be an empty directory.\n";
							exit(-1);
						}
					}
				}
			}
			
			# Check that the destinationHome is writable
			if(! -w "$dstoraclehome") {
				print "ERROR: Target location ($dstoraclehome) should be writable by user ($user).\n";
				exit(-1);
			}
			
			print "Copying files to $dstoraclehome...";
			File::Find::find(sub{
				# create all dirs
				my $dirpath=substr($File::Find::dir,length($ohDir)+1);
				if(! -d "$dstoraclehome/$dirpath"){
					File::Path::make_path("$dstoraclehome/$dirpath") or die "mkdir failed: $!\n";
				}
			},"$ohDir");
			File::Find::find(sub{
				#create links
				if( -l $File::Find::name ){
					my $rellinkpath=substr($File::Find::name,length($ohDir)+1);
					my $linkpath=readlink($File::Find::name);
					symlink($linkpath,"$dstoraclehome/$rellinkpath")or die "create symlink $dstoraclehome/$rellinkpath -> $linkpath failed: $!\n";
				} elsif( -f $File::Find::name ){
					# copy all files
					my $filepath=substr($File::Find::name,length($ohDir)+1);
					File::Copy::cp($File::Find::name,"$dstoraclehome/$filepath") or die "Copy of $File::Find::name to $dstoraclehome/$filepath failed: $!\n";
					$filecnt++;
					if($filecnt == 1000){
						print "."; # print a progress dot for every thousand files
						$filecnt=0; # reset counter
					}
				} elsif( -d $File::Find::name ) {
					# create left out empty dirs
					my $reldirpath=substr($File::Find::name,length($ohDir)+1);
					if(!-d "$dstoraclehome/$reldirpath"){
						File::Path::make_path("$dstoraclehome/$reldirpath") or die "mkdir of $dstoraclehome/$reldirpath failed: $!\n";
					}
				}
			},"$ohDir");
			print "\n"; # next line
			my $argcnt = @ARGV;
			my @newcmd;
			push(@newcmd,"$setupScript");

			for(my $cnt = 0; $cnt < $argcnt; $cnt++) {
				my $myarg = $ARGV[$cnt];
				if($myarg ne "-destinationHome") {
					#include for new cmd
					push(@newcmd,$myarg);
				} else{
					# ignore for new cmd
					if($cnt+1 < $argcnt and substr($ARGV[$cnt+1],0,1) ne "-"){
						$cnt++;
					}
				}
			}
			$SIG{CHLD} = 'IGNORE';
			unless ( fork() ) {
				#spawn setup
				print "Executing $newcmd[0]\n";
				exec(@newcmd);
				exit(0);
			}
			exit(0);
		}
	}
}

sub homeOwnershipChecks() {
	my ($self, @args) = @_;
	
	my $productDescription = $self->{"PRODUCT_DESCRIPTION"};
	
	if($productDescription) {
		# Home ownership checks
		if (! $isWindows) {
			# check current user owns OH
			# bug 20400258 - only allow home owner user to run the tool
			my $ohDir=$ENV{ORACLE_HOME};
			# check that OH path is a directory
			if(! -d $ohDir) {
				$self->showOwnerErrorAndExit();
			}  
			my $ohDirOwner='';
			# get the owner of the OH dir
			($ohDirOwner=getpwuid((stat($ohDir))[4])) or $self->showOwnerErrorAndExit();
			# check that owner of OH was set
			if($ohDirOwner eq '') {
				$self->showOwnerErrorAndExit();
			} 
			# check if the home owner is not root, which would be the case
			# if a cluster is already configured in it.
			if($ohDirOwner ne 'root') {
				# check that current user is owner of OH  
				if($user ne $ohDirOwner) {
					print "\nERROR: Unable to run the setup script as user ($user). Run the setup script from a location where the $productDescription software image is owned by user ($user).\n";
					exit 1;
				}
			} else {
				# case the OH is owned by root
				
				# bug 20802525 - if home already configured, check ownership of OH/oraInst.loc file
				my $oraInstloc="$ohDir/oraInst.loc";
				
				# check if the OH/oraInst.loc file exist
				if(! -e $oraInstloc) {
					# if it does not exist, the goldimage might have been unzipped with root
					print "\nERROR: Ensure that the $productDescription software image files at ($ohDir) are not owned by root.\n";
					exit 1;    
				}
				
				my $oraInstlocOwner='';
				# get the owner of the OH/oraInst.loc file
				($oraInstlocOwner=getpwuid((stat($oraInstloc))[4])) or $self->showOwnerErrorAndExit();
				# check that owner of OH/oraInst.loc was set
				if($oraInstlocOwner eq '') {
					$self->showOwnerErrorAndExit();
				}
				
				# check that current user is owner of OH/oraInst.loc 
				if($oraInstlocOwner ne 'root') {
					if($user ne $oraInstlocOwner) {
						print "\nERROR: You must be logged in as user ($oraInstlocOwner) to run this tool.\n";
						exit 1;
					}
				} else {
					$self->showOwnerErrorAndExit();
				}
			}
		}
	}
}
	
sub rootPreCheck() {
	my ($self, @args) = @_;

	# add rootpre.sh requirement
	if(! $isWindows) {
		# bug 21973856 - use a script to determine if rootpre is required
		# bug 26788168 - rootpre.sh is not required for DB in Solaris
		my $rootPreReqCmd = $ENV{ORACLE_HOME}.$dirSep.'bin'.$dirSep.'rootPreRequired.sh '.$self->{"TYPE"}.' '.join(' ',@ARGV);
		my $showRootPre = `$rootPreReqCmd`;
		chomp($showRootPre); 
		if($showRootPre eq "true") {
			print "\n********************************************************************************\n\n";
			print "Your platform requires the root user to perform certain pre-installation\n";
			print "OS preparation.  The root user should run the shell script 'rootpre.sh' before\n";
			print "you proceed with Oracle installation. The rootpre.sh script can be found at:\n";
			print $ENV{ORACLE_HOME}.$dirSep.'clone'.$dirSep.'rootpre.sh';
			print "\n\nAnswer 'y' if root has run 'rootpre.sh' so you can proceed with Oracle\n";
			print "installation.\n";
			print "Answer 'n' to abort installation and then ask root to run 'rootpre.sh'.\n";
			print "\n********************************************************************************\n\n";
			print "Has 'rootpre.sh' been run by root in this machine? [y/n] (n)\n";
			# read user input
			my $userInput = <STDIN>;
			# remove leading new line char
			chomp($userInput);
			# trim blank spaces
			$userInput =~ s/^\s+//;
			$userInput =~ s/\s+$//;
			if ( !(lc($userInput) eq "y") ) {
				print "Installation stopped to run 'rootpre.sh' by root.\n";
				exit 1;
			}
		}
	}
}	

sub calculateTimestamp() {
	# Calculate the timestamp, temp dir and templogdir location
	my $timestamp = Time::Piece::localtime->strftime('%Y-%m-%d_%H-%M-%S');
	# Get the 24 hr format string (00 - 23)
	my $hour = substr($timestamp, 11, 2);
	my $AMPM = 'PM';
	# If the hr starts with 0 or is 10 or 11, its AM
	if(substr($hour, 0, 1) eq '0' or $hour eq '10' or $hour eq '11') {
		$AMPM = 'AM';
	} else {
		# For PM case, we need to convert the 24 hr string into 12 hr format (00-12), for this
		# we keep the hr string if it is already 12, for any other case we get the modulo 12
		if($hour ne '12') {
			$hour = ($hour % 12);
		}
		# If the hr string ends up with one char after the modulo operation, add a 0 in front  
		if(length($hour) == 1) {
			$hour = '0'.$hour;
		}
	}
	# Reconstruct the timestamp by replacing the hour string and appending the AM/PM
	$timestamp = substr($timestamp,0,11).$hour.substr($timestamp, 13).$AMPM;
	return $timestamp;
}

sub getClassPath() {
	my ($self, @args) = @_;
	
	# Path to the OUI Scripts directory
	my $OUI_Scripts=$ORACLE_HOME.$dirSep.'inventory'.$dirSep.'Scripts';
	
	# set scratchPath as OH/inventory/Scripts
	$scratchPath=$OUI_Scripts;

	# include jars in classpath
	my @INSTALL_JARS_LIST=($ORACLE_HOME.$dirSep.'install'.$dirSep.'jlib'.$dirSep.'installcommons_1.0.0b.jar',
	$ORACLE_HOME.$dirSep.'install'.$dirSep.'jlib'.$dirSep.'instcommon.jar', 
	$ORACLE_HOME.$dirSep.'install'.$dirSep.'jlib'.$dirSep.'instcrs.jar',
	$ORACLE_HOME.$dirSep.'install'.$dirSep.'jlib'.$dirSep.'pilot_1.0.0b.jar',
	$ORACLE_HOME.$dirSep.'install'.$dirSep.'jlib'.$dirSep.'instdb.jar',
	$ORACLE_HOME.$dirSep.'install'.$dirSep.'jlib'.$dirSep.'instclient.jar',
	$ORACLE_HOME.$dirSep.'install'.$dirSep.'jlib'.$dirSep.'emCoreConsole.jar');
	
	# Check if the install jars exist
	my @INSTALL_JARS;
	for my $installJar (@INSTALL_JARS_LIST) {
		if(-e $installJar) {
			push(@INSTALL_JARS, $installJar);
		}
	}

	# bug 21277531 - include srvmhas.jar and gns.jar into the classpath
	# bug 20676526 - load srvm.jar from OH/jlib
	# bug 28205806 - load jwc-cred.jar from OH/jlib
	my @EXT_JARS=($ORACLE_HOME.$dirSep.'jlib'.$dirSep.'cvu.jar',
	$ORACLE_HOME.$dirSep.'jlib'.$dirSep.'srvmhas.jar',
	$ORACLE_HOME.$dirSep.'jlib'.$dirSep.'srvmasm.jar',
	$ORACLE_HOME.$dirSep.'jlib'.$dirSep.'gns.jar',
	$ORACLE_HOME.$dirSep.'jlib'.$dirSep.'srvm.jar',
	$ORACLE_HOME.$dirSep.'jlib'.$dirSep.'oraclepki.jar',
        $ORACLE_HOME.$dirSep.'jlib'.$dirSep.'mgmtca.jar',
        $ORACLE_HOME.$dirSep.'jlib'.$dirSep.'mgmtua.jar',
        $ORACLE_HOME.$dirSep.'jlib'.$dirSep.'clscred.jar',
	$ORACLE_HOME.$dirSep.'jlib'.$dirSep.'oracle.dbtools-common.jar',
	$ORACLE_HOME.$dirSep.'jlib'.$dirSep.'wsclient_extended.jar',
	$ORACLE_HOME.$dirSep.'jlib'.$dirSep.'adf-share-ca.jar',
	$ORACLE_HOME.$dirSep.'jlib'.$dirSep.'jmxspi.jar',
	$ORACLE_HOME.$dirSep.'jlib'.$dirSep.'emca.jar',
	$ORACLE_HOME.$dirSep.'jlib'.$dirSep.'entityManager_proxy.jar',
	$ORACLE_HOME.$dirSep.'jlib'.$dirSep.'javax.security.jacc_1.0.0.0_1-1.jar',
	$ORACLE_HOME.$dirSep.'jlib'.$dirSep.'orai18n-mapping.jar',
	$ORACLE_HOME.$dirSep.'jlib'.$dirSep.'orai18n-utility.jar',
	$ORACLE_HOME.$dirSep.'jlib'.$dirSep.'orai18n-translation.jar',
	$ORACLE_HOME.$dirSep.'jlib'.$dirSep.'jwc-cred.jar',
	$ORACLE_HOME.$dirSep.'jdbc'.$dirSep.'lib'.$dirSep.'ojdbc8.jar',
	$ORACLE_HOME.$dirSep.'OPatch'.$dirSep.'jlib'.$dirSep.'opatchsdk.jar',
	$ORACLE_HOME.$dirSep.'OPatch'.$dirSep.'jlib'.$dirSep.'opatch.jar',
	$ORACLE_HOME.$dirSep.'oui'.$dirSep.'jlib'.$dirSep.'OraPrereqChecks.jar',
	$ORACLE_HOME.$dirSep.'oui'.$dirSep.'jlib'.$dirSep.'prov_fixup.jar',
	$ORACLE_HOME.$dirSep.'oui'.$dirSep.'jlib'.$dirSep.'ssh.jar',
	$ORACLE_HOME.$dirSep.'oui'.$dirSep.'jlib'.$dirSep.'jsch.jar',
	$ORACLE_HOME.$dirSep.'oui'.$dirSep.'jlib'.$dirSep.'remoteinterfaces.jar',
	$ORACLE_HOME.$dirSep.'oui'.$dirSep.'jlib'.$dirSep.'OraPrereq.jar');
	foreach my $extjar(@EXT_JARS){
		$self->addJarToClassPath($extjar,\@INSTALL_JARS);
	}

	# include all jars of oui/jlib in classpath
	my $ouijlib_dir=$ORACLE_HOME.$dirSep.'oui'.$dirSep.'jlib'.$dirSep;
	opendir(DIR,$ouijlib_dir) || die "can't opendir $ouijlib_dir: $!";
	foreach my $file(readdir(DIR)){
		if (! -d $file) {
			chomp($file);
			$self->addJarToClassPath($ouijlib_dir.$file, \@INSTALL_JARS);
		}
	}
	close(DIR);

	return join($pathSep,@INSTALL_JARS);
}

sub parseArgs() {
	my ($self, @args) = @_;
	
	for(my $count = 0; $count < $javaOptionsSize; $count++) {
		my $javaOption = $ARGV[$count];
		my $firstTwoChars = substr($javaOption, 0, 2);
		if($firstTwoChars eq "-J") {
			push(@javaOptions, substr($javaOption,2));
		} elsif(lc($javaOption) eq lc($pluginArg)) {
			$launchPilot="true";
			last;
		} elsif(lc($javaOption) eq lc($printTimeArg)) {
			$printtime="-printtime";
		} elsif(lc($javaOption) eq lc($noWaitArg)) {
			$noWait="true";
		} elsif(lc($javaOption) eq lc($debugArg)) {
			$debug="true";
			$debugOpts=' -DTRACING.LEVEL=2 -DTRACING.ENABLED=TRUE ';
			push(@remainingArgs, $javaOption);
		} elsif(lc($javaOption) eq lc($javaDebugArg)) {
			$javadebug="true";
			$javadebugOpts = " -Xdebug -agentlib:jdwp=transport=dt_socket,server=y,suspend=y,address=8001 ";
		} elsif(lc($javaOption) eq lc($applyInstallerUpdatesArg)){
			if($applyingInstallerUpdates eq 'true') {
				$self->repetitiveArgsError($applyInstallerUpdatesArg);
			}
			$applyingInstallerUpdates = 'true';
			push(@patchArgs, $javaOption);
			$patching = 'true';
			# do not pass -applyInstallerUpdates to java cmd
				# also skip next param only if it doesn't start with "-"
			# i.e. skip if it is a a value and not another param
			if($count+1 < $javaOptionsSize and substr($ARGV[$count+1],0,1) ne "-"){
				$count++;
				push(@patchArgs, $ARGV[$count]);
			}
		} elsif(($javaOption eq $patchTypePSU) or ($javaOption eq $patchTypeRU) or ($javaOption eq $patchTypeRUR)) {
			if($applyingPSU eq 'true') {
				# The argument was already passed
				$self->repetitiveArgsError($patchTypePSU);
			}
			push(@patchArgs, $javaOption);
			# this block takes out the apply arguments from the java cmd
			# set $patching as true
			$patching = 'true';
			$applyingPSU = 'true';
			# get the next arg value as the path with the patch
			if($count+1 < $javaOptionsSize and substr($ARGV[$count+1],0,1) ne "-"){
				$count++;
				push(@patchArgs, $ARGV[$count]);
			}
		} elsif($javaOption eq $patchTypeOneOffs) {
			if($applyingOneOffs eq 'true') {
				# The argument was already passed
				$self->repetitiveArgsError($patchTypeOneOffs);
			}
			push(@patchArgs, $javaOption);
			# this block takes out the apply arguments from the java cmd
			# set $patching as true
			$patching = 'true';
			$applyingOneOffs = 'true';
			# get the next arg value as the path with the patch
			if($count+1 < $javaOptionsSize and substr($ARGV[$count+1],0,1) ne "-"){
				$count++;
				push(@patchArgs, $ARGV[$count]);
			}
		} elsif($javaOption eq "-skipRemoteCopy") {
			# bug 22147365 - enable skipRemoteCopy flag
			push(@remainingArgs, "-noCopy -nolink");
		} elsif(($javaOption =~ /^ORACLE_HOME=/) or ($javaOption =~ /^-ORACLE_HOME$/)) {
			# The ORACLE_HOME argument or option was passed
			my $rightOHCmdline = "true";
			my $OHcmdline = "";
			if($javaOption =~ /^ORACLE_HOME=/) {
				# Option case: 'ORACLE_HOME=value'
				$OHcmdline = (split('=', $javaOption))[1];
			} elsif($javaOption =~ /^-ORACLE_HOME$/) {
				# Argument case: '-ORACLE_HOME value'
				if($count+1 < $javaOptionsSize and substr($ARGV[$count+1],0,1) ne "-"){
					$count++;
					$OHcmdline = $ARGV[$count];
				}
			}
			
			if("$OHcmdline" ne "") {
				if(length($OHcmdline) > 1) {
					# Remove the trailing slash if existent
					if($OHcmdline =~ /$dirSep$/) {
						$OHcmdline = substr($OHcmdline, 0, length($OHcmdline)-1);
					}
				}
				# Check if the OH provided in the cmdline matches the one detected by the Setup script.
				if($OHcmdline ne $ORACLE_HOME) {
					$rightOHCmdline = "false";
				}
			} else {
				$rightOHCmdline = "false";
			}
			
			if($rightOHCmdline eq "false") {
				print("ERROR: The installer has detected that the Oracle home location provided in the command line is not correct. The Oracle home is the location from where setup script is executed.\n\nIt is not required to specify ORACLE_HOME in the command line for the installation.\n");
				exit(1);
			}
		} elsif($javaOption eq $opatchLocArg) {
			if($updatingOpatch eq 'true') {
				# The argument was already passed
				$self->repetitiveArgsError($opatchLocArg);
			}
			push(@patchArgs, $javaOption);
			$patching = 'true';
			$updatingOpatch = 'true';
			# get the next arg value as the opatch location
			if($count+1 < $javaOptionsSize and substr($ARGV[$count+1],0,1) ne "-"){
				$count++;
				push(@patchArgs, $ARGV[$count]);
			}
		} elsif($javaOption eq $skipOpatchVersionArg) {
			push(@patchArgs, $javaOption);
		} elsif($javaOption eq $revertArg) {
			$revertingInstallerUpdate = 'true';
			push(@patchArgs, $javaOption);
		} elsif(lc($javaOption) eq lc($jreLocArg)) {
			# Get the next arg as the custom JRE location
			if($count+1 < $javaOptionsSize and substr($ARGV[$count+1],0,1) ne "-"){
				$customJRE = 'true';
				$count++;
				$JRELOC = $ARGV[$count];
			}
		} elsif(lc($javaOption) eq lc($skipPatchStatusCheckArg)) {
			$skipPatchStatusCheck = 'true';
		} elsif(lc($javaOption) eq lc($destinationHomeArg)) {
			# Get the next arg as the destination home
			if($count+1 < $javaOptionsSize and substr($ARGV[$count+1],0,1) ne "-"){
				$count++;
				$dstoraclehome = $ARGV[$count];
			}
		} elsif($javaOption =~ /\{/ || $javaOption =~ /\*/) {
			# lrg 20441240 - Clear any pre-existing quote
			$javaOption =~ s/'//g;
			$javaOption =~ s/"//g;

			# Add quotes to avoid expansion
			push(@remainingArgs, "'".$javaOption."'");
		} elsif(lc($javaOption) eq lc($printImageInfoArg)) {
                        $printImageInfo = 'true';
		} elsif(lc($javaOption) eq lc($showAdditionalInfoArg)) {
                        $showAdditionalInfo = 'true';
		} else {
			push(@remainingArgs, $javaOption);
		}
	}
}

sub getJavaCmd() {
	my $self = shift;
	my $platform = shift;
	my $jreLoc = shift;
	my $dirSep = shift;
	my $platDirName = shift;
	my $javacmd = $jreLoc.$dirSep.'bin'.$dirSep.'java';

	#Adding the -d64 flag for java command on hybrid unixplatforms.
        # bug 28026249 - flag -d64 not required in aix
	if( $platform=~ /.*solaris.*/ || $platform=~ /.*hpux.*/ ){
		$javacmd .= ' -d64';
	}
	return $javacmd;
}

sub getImageInfo() {
	my ($self, @args) = @_;
	
	#Check if image info should be printed out	
	if($printImageInfo eq 'true') {
                my $imageInfoCmd = $JAVACMD.' -cp '.$classPath.' oracle.install.library.util.imageinfo.ImageInfoUtil '.$ORACLE_HOME.' '.$showAdditionalInfo;
                my $imageInfoOut = qx{$imageInfoCmd};
                my $checkImageInfoStatusCode = $?;
                if($imageInfoOut ne ""){
                        print "\n$imageInfoOut\n";
                }
                $self->terminate($checkImageInfoStatusCode);
        }
}
	
sub checkPatchActions() {
	my ($self, @args) = @_;
	
	# Check for the patch status
	$self->checkPatchStatus();

	# Check patch revert action
	$self->checkPatchRevert();
	
	# Check patch action
	$self->checkPatchAction();
}
	
sub checkPatchStatus() {
	my ($self, @args) = @_;
	
	# Check patch status
	if($skipPatchStatusCheck eq 'false') {
		my $checkPatchStatusCmd = $JAVACMD.' -cp '.$classPath.' '.join(' ',@javaOptions).' oracle.install.ivw.common.driver.InstallerPatchDriver '.$self->{LOG_DIR_PREFIX}.' '.$ORACLE_HOME.' -status -timestamp '.$timestamp.' -tempLocation '.$tempLogDir;
		my $checkPatchStatusOut = qx{$checkPatchStatusCmd};
		my $checkPatchStatusCode = $?;
		if($checkPatchStatusCode ne "0" and $revertingInstallerUpdate eq 'false') {
			print "\n$checkPatchStatusOut\n";
			$self->terminate($checkPatchStatusCode);
		}
	}
}

sub checkPatchRevert() {
	my ($self, @args) = @_;
	
	# Check if its a revert action
	if($revertingInstallerUpdate eq 'true') {
		my ($tempHome, $newJre, $newClassPath) = $self->bootstrap();
		
		my $newJavaBinary = $self->getJavaCmd($PLATFORM, $newJre, $dirSep, $PLATFORM_DIRECTORY_NAME);
		
		my $ouiLoc = '-Doracle.installer.oui_loc='.$ORACLE_HOME.$dirSep.'oui';
		
		my $revertInstallerPatchCmd = $newJavaBinary.' -cp '.$newClassPath.$javadebugOpts.' '.join(' ',@javaOptions).' '.$ouiLoc.' -Djava.util.logging.FileHandler.append=true oracle.install.ivw.common.driver.InstallerPatchDriver '.$self->{LOG_DIR_PREFIX}.' '.$ORACLE_HOME.' -revert -timestamp '.$timestamp.' -tempLocation '.$tempLogDir;
		my $revertInstallerPatchCode = $self->runCommand($revertInstallerPatchCmd);
		
		File::Path::remove_tree($tempHome);
		
		$self->terminate($revertInstallerPatchCode);
	}
}

sub checkPatchAction() {
	my ($self, @args) = @_;
	
	# Check if its a patch action
	if($patching eq 'true') {
		
		my ($tempHome, $newJre, $newClassPath) = $self->bootstrap();
		
		my $newJavaBinary = $self->getJavaCmd($PLATFORM, $newJre, $dirSep, $PLATFORM_DIRECTORY_NAME);
		
		my $ouiLoc = '-Doracle.installer.oui_loc='.$ORACLE_HOME.$dirSep.'oui';
		
		my $debugFlag = '';
		if($debug) {
			$debugFlag = '-debug';
		}  
		
		my $installerPatchCmd = $newJavaBinary.' -cp '.$newClassPath.$javadebugOpts.' '.join(' ',@javaOptions).' '.$ouiLoc.' -Djava.util.logging.FileHandler.append=true oracle.install.ivw.common.driver.InstallerPatchDriver '.$self->{LOG_DIR_PREFIX}.' '.$ORACLE_HOME.' '.$debugFlag.' -timestamp '.$timestamp.' -tempLocation '.$tempLogDir.' '.join(' ',@patchArgs);
		my $installerPatchCode = $self->runCommand($installerPatchCmd);
		
		File::Path::remove_tree($tempHome);
		
		if($installerPatchCode ne "0") {
			$self->terminate($installerPatchCode);
		}
	}
}

sub setWizardCmd() {
	my $self = shift;
	my $mainClass = shift;
	
	# java cmd to launch
	return $JAVACMD.' -cp '.$classPath.$debugOpts.$javadebugOpts.$jdkBug8060036WA.' -Doracle.installer.library_loc='.$OUI_LIBRARY_LOCATION.' -Djava.io.tmpdir='.$tempLogDir.' -Doracle.installer.timestamp='.$timestamp.' -Doracle.installer.tempLogDir='.$tempLogDir.' -Doracle.installer.scratchPath='.$scratchPath.' -DORACLE_HOME='.$ORACLE_HOME.' '.join(' ',@javaOptions).' -Xdebug '.$self->{"MAIN_CLASS"}.' '.$printtime.' ORACLE_HOME='.$ORACLE_HOME.' '.join(' ',@remainingArgs);
}

sub runWizardCmd() {
	#Check for writability permission for system preference files. (bug #10041861)
	#if files don't have writable permission then add the writable permission.
	#remove added writable permission at the end.
	my $systemLockFilePermissionAdded='0';
	my $systemRootModeFilePermissionAdded='0';
	my $systemLockFile=$JRELOC.$dirSep.'.systemPrefs'.$dirSep.'.system.lock';
	my $systemRootModeFile=$JRELOC.$dirSep.'.systemPrefs'.$dirSep.'.systemRootModFile';
	my $CHMOD='/bin/chmod';
	if($PLATFORM=~ /.*aix.*/){
		if((-e $systemLockFile) && !(-w $systemLockFile)){
			my $chmodcmd=$CHMOD.' u+w '.$systemLockFile;
			system($chmodcmd);
			$systemLockFilePermissionAdded='1';
		}
		if((-e $systemRootModeFile) && !(-w $systemRootModeFile)){
			my $chmodcmd=$CHMOD.' u+w '.$systemRootModeFile;
			system($chmodcmd);
			$systemRootModeFilePermissionAdded='1';
		}
	}

	# change dir
	chdir $ORACLE_HOME;
	
	# Determine the current existent files in the scratch path location
	my @scratchPathFiles;
	File::Find::find(sub{
		push(@scratchPathFiles, $File::Find::name);
	}, $scratchPath);

	# execute java cmd
	my $retcode=0;
	if($isWindows) {
		# WA for Perl bug 18917 (double execution)
		open(WCMD, "$wizardCmd |");
		while(<WCMD>) {
			print STDOUT $_;
		}
		close(WCMD);
		$retcode=$?;
	} else {
		# if os is unix and -noWait is passed in the command line then launching the SetupWizard in background.
		if($noWait eq "true") {
			$SIG{CHLD} = 'IGNORE';
			unless ( fork() ) {
				# Spawn SetupWizard
				$retcode=exec($wizardCmd);
				exit(0);
			}
		   } else {
			$retcode=system($wizardCmd);
		}
	}

	if( $PLATFORM=~ /.*aix.*/){
		if($systemLockFilePermissionAdded){
			my $chmodcmd=$CHMOD.' u-w '.$systemLockFile;
			system($chmodcmd);
		}
		if($systemRootModeFilePermissionAdded){
			my $chmodcmd=$CHMOD.' u-w '.$systemRootModeFile;
			system($chmodcmd);
		}
	}

	# Remove all the newly created files from the scratch path location
	my @oldScratchPathFiles;
	foreach (@scratchPathFiles) {
		push(@oldScratchPathFiles, $_);
	}
	my @newScratchPathFiles;
	File::Find::find(sub{
		push(@newScratchPathFiles, $File::Find::name);
	}, $scratchPath);
	foreach my $newFile (@newScratchPathFiles) {
		if(-e $newFile) {
			my $isOldFile = 'false';
			my $count = 0;
			foreach my $oldFile (@oldScratchPathFiles) {
				if($oldFile eq $newFile) {
					$isOldFile = 'true';
					
					# Optimize by removing the file from the old scratch path files array
					splice(@oldScratchPathFiles, $count, 1);
					last;
				}
				$count++;
			}
			if($isOldFile eq 'false') {
				if(-d $newFile) {
					File::Path::remove_tree($newFile);
					} else {
					unlink($newFile);
				}
			}
		}
	}

	exit $retcode >> 8;
}
	
sub runCommand() {
	my $self = shift;
	my $command = shift;
	my $exitCode = 0;
	if($isWindows) {
		# WA for Perl bug 18917 (double execution)
		open(WCMD, "$command |");
		while(<WCMD>) {
			print STDOUT $_;
		}
		close(WCMD);
		$exitCode=$?;
	} else {
		$exitCode=system($command);
	}
	return $exitCode;
}

sub setLdLibraryPath() {
	my $self = shift;
	my $oracleHome = shift;
	my $osname=$^O;
	my $LD_LIBRARY_PATH = $oracleHome.$dirSep.'lib'.$pathSep.$OUI_LIBRARY_LOCATION.$pathSep.$oracleHome.$dirSep.'bin';
	$LD_LIBRARY_PATH .= $pathSep.$ENV{LD_LIBRARY_PATH} if (exists($ENV{LD_LIBRARY_PATH}));
	$ENV{LD_LIBRARY_PATH} = $LD_LIBRARY_PATH;
	if ( $osname =~ /.*solaris.*/){
		$ENV{LD_LIBRARY_PATH_64} = $LD_LIBRARY_PATH;
	}
	
	if ($osname =~ /.*HPUX.*/i) {
		my $SHLIB_PATH = $LD_LIBRARY_PATH;
		$SHLIB_PATH .= $pathSep.$ENV{SHLIB_PATH} if (exists($ENV{SHLIB_PATH}));
		$ENV{SHLIB_PATH} = $SHLIB_PATH;
	}
	
	if ($osname =~ /.*AIX.*/i) {
		my $LIBPATH = $LD_LIBRARY_PATH;
		$LIBPATH .= $pathSep.$ENV{LIBPATH} if (exists($ENV{LIBPATH}));
		$ENV{LIBPATH} = $LIBPATH;
	}
}

sub showOwnerErrorAndExit() {
	print "\nERROR: Could not validate ownership of the Oracle home software.\n";
	print "       Verify that the software is not corrupt.\n";
	exit 1;
}

sub addJarToClassPath() {
	my ($self, $newJar, $existentJars) = @_;
	my $newJarName = File::Basename::basename($newJar);
	my $newJarExists = 0;
	# check if the jar is not already in the classpath
	for(my $count = 0; $count < @{$existentJars}; $count++) {
		my $jarName = File::Basename::basename(${$existentJars}[$count]);
		# compare the names of the jars
		if($jarName eq $newJarName) {
			$newJarExists=1;
			last;
		}
	}
	if(! $newJarExists) {
		push(@{$existentJars}, $newJar);
	}
}

###
# To show proper error message when repetitive arguments are passed,
# and it is not supported for such given argument.
###
sub repetitiveArgsError() {
        my $self = shift;
	my $repetitiveArg = shift;
	
	print "\nERROR: Repetition of command line argument is not supported: $repetitiveArg.\n";
	exit 1;
}

###
# To check if all the files from a given file or directory are
# readable by the current user.
# This subroutine is only for unix platforms.
#
# returns "true" if all files from the given directory are readable
# by the current user, "false" otherwise.
###
sub areAllFilesReadable() {
        my $self = shift;
	my $dirPath = shift;
	my $readAll="true";
	my $FIND="/bin/find";
	if(! -f "$FIND") {
		$FIND="/usr/bin/find";
	}
	# This check can only be done if the find binary is available
	if(-f "$FIND") {
		# find command: 'find dirPath ! -readable 2> /dev/null'
		my $allNonReadableFilesCmd=$FIND.' '.$dirPath.' ! -readable 2> /dev/null';
		my @nonReadableFiles=`$allNonReadableFilesCmd`;
		my $exitCodeNonReadFilesCmd=$?;
		if("$exitCodeNonReadFilesCmd" ne "0") {
			# If the find command fails, then some subdirectories are not readable by the current user
			$readAll="false";
		} else {
			# We iterate through the results of the find command to see if any of them is a file
			foreach (@nonReadableFiles) {
				if(-f "$_") {
					$readAll="false";
					last;
				}
			}
		}
	}
	return $readAll;
}

###
# To bootstrap the jdk and some jars into a temporary home in
# the temporary location.
# return The temporary home, the temporary java binary, and the
# temporary classpath.
###
sub bootstrap() {
	my ($self, @args) = @_;
	
	my $tempHome = $tempLogDir.$dirSep."tempHome";
	
	if($isWindows) {
		# bug 24517277 - Bootstrap the required DLLs
		my $dllDir = $tempHome.$dirSep."dlls";
		File::Path::make_path($dllDir);
		
		my @dllFiles;
		my $homeBin = $ORACLE_HOME.$dirSep."bin";
		my $ouiLibWin64 = $ORACLE_HOME.$dirSep."oui".$dirSep."lib".$dirSep."win64";
		push(@dllFiles, $homeBin.$dirSep."orasrvm19.dll");
		push(@dllFiles, $homeBin.$dirSep."orawsec19.dll");
		push(@dllFiles, $homeBin.$dirSep."orauts.dll");
		push(@dllFiles, $ouiLibWin64.$dirSep."oraInstaller.dll");
		foreach my $dll (@dllFiles) {
			my $dllName = File::Basename::basename($dll);
			my $newDllPath = $dllDir.$dirSep.$dllName;
			File::Copy::cp($dll,$newDllPath);
		}
		
		# Pre-append the temp dll dir into the PATH env var
		$ENV{PATH} = $dllDir.$pathSep.$ENV{PATH};
	}
	
	# Only bootstrap the JRE if there was no custom JRE provided
	my $jreDir = $tempHome.$dirSep."jre";
	if($customJRE eq 'false') {  
		File::Path::make_path($jreDir);
		$self->copyAllFiles($ORACLE_HOME.$dirSep."jdk".$dirSep."jre", $jreDir);
	} else {
		$jreDir = $JRELOC;
	}
	
	my $newCP = "";
	my $installJarsPath = $ORACLE_HOME.$dirSep."install".$dirSep."jlib";
	my $ouiJlibJarsPath = $ORACLE_HOME.$dirSep."oui".$dirSep."jlib";
	my $jlibJarsPath = $ORACLE_HOME.$dirSep."jlib";
	my @installJars;
	# Install jars
	push(@installJars, $installJarsPath.$dirSep."installcommons_1.0.0b.jar");
	push(@installJars, $installJarsPath.$dirSep."instcommon.jar");
	push(@installJars, $installJarsPath.$dirSep."instcrs.jar");
	push(@installJars, $installJarsPath.$dirSep."instdb.jar");
	push(@installJars, $installJarsPath.$dirSep."instclient.jar");
	# OUI jars
	push(@installJars, $ouiJlibJarsPath.$dirSep."OraInstaller.jar");
	push(@installJars, $ouiJlibJarsPath.$dirSep."xmlparserv2.jar");
	push(@installJars, $ouiJlibJarsPath.$dirSep."share.jar");
	# SRVM jars
	push(@installJars, $jlibJarsPath.$dirSep."srvm.jar");
	push(@installJars, $jlibJarsPath.$dirSep."cvu.jar");
	
	foreach my $jar (@installJars) {
		my $jarName = File::Basename::basename($jar);
		my $parentPath = File::Basename::dirname($jar);
		my $relPath = substr($parentPath, length($ORACLE_HOME)+1);
		my $newJarPath = $tempHome.$dirSep.$relPath;
		File::Path::make_path($newJarPath);
		
		$self->copyAllFiles($jar, $newJarPath);
		$newCP = $newCP.$newJarPath.$dirSep.$jarName.$pathSep;
	}
	
	if(length($newCP) > 0) {
		$newCP = substr($newCP, 0, length($newCP)-1);
	}
	
	return ($tempHome,$jreDir,$newCP);
}

###
# To copy all the files from a directory, in a recursive way,
# but the subdirectories will not be copied, instead they will
# be created in the destination location.
###
sub copyAllFiles() {
        my $self = shift;
	my $sourceDir = shift;
	my $destDir = shift;
	
	# Make the destination directory if not existent
	if (! -d $destDir) {
		File::Path::make_path("$destDir");
	}
	
	# Remove trailing slash from the sourceDir path
	if(length($sourceDir) > 1) {
		my $lastChar = substr($sourceDir,length($sourceDir)-1);
		while("$lastChar" eq "$dirSep") {
			$sourceDir = substr($sourceDir, 0, length($sourceDir)-1);
			$lastChar = substr($sourceDir,length($sourceDir)-1);
		}
	}
	
	# Copy the files from sourceDir to destDir
	File::Find::find(sub{
		# Get the file name, starting from the end of the sourceDir
		my $filepath=substr($File::Find::name,length($sourceDir));
		# Get the relative path from the file
		my $relparentdir=substr($filepath,0,rindex($filepath,$dirSep));
		# Check if the relative path exists in the destDir, if not, make it
		if(! -d $destDir.$dirSep.$relparentdir) {
			File::Path::make_path($destDir.$dirSep.$relparentdir);
		}
		if(-d $_) {
			# For directories, check if they already exist in the destDir, if not, make them
			if(! -d $destDir.$dirSep.$filepath) {
				File::Path::make_path($destDir.$dirSep.$filepath);
			}
		} else {
			# For files, copy them to the destDir
			File::Copy::cp($File::Find::name,$destDir.$dirSep.$filepath);
		}
	},$sourceDir);
}

###
# To exit the perl execution.
# The temp log dir will be removed if its empty.
###
sub terminate() {
        my $self = shift;
	my $exitCode = shift;
	
	# Remove the temp log dir if its empty
	my @tmpDirFiles;
	File::Find::find(sub{
		my $fileName = $File::Find::name;
		if($fileName ne $tempLogDir) {
			push(@tmpDirFiles, $fileName);
		}
	}, $tempLogDir);
	
	if(!@tmpDirFiles) {
		File::Path::remove_tree($tempLogDir);
	}
	
	exit $exitCode >> 8;
}
