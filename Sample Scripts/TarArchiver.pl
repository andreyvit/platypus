#!/usr/bin/perl
#
# This script will create a gzipped tar archive on your Desktop
# from the files dropped on it.  Make sure to set it as droppable, 
# and output type to Progress Bar for some style. 
#

$cnt = 0;

$cmd = "/usr/bin/tar cvfz ~/Desktop/archive.tgz ";

# loop through list of files dropped
foreach(@ARGV)
{
		# add each file in turn
		$cmd .= "'$_' ";
}

system($cmd);