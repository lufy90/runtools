#!/bin/bash
# filename: tools.sh
# Author: lufei
# Date: 20200109 15:57:53


## SETTINS
BASEURL=http://autoserver:8000/testtools


installpkg(){
#	[ -z $PACKAGES ] && return 0
        local i
        echo "Checking packages ..."
        for i
        do
                rpm -qi $i &> /dev/null || \
                        yum install $i -y &> /dev/null || \
                        echo "WARNING: yum insatll $i failed, related cases may return FAIL."
        done
}

get_tarball() {
	[ -f $TARBALL ] || \
	{
		echo "INFO: downloading $TARBALL ..."
		echo "INFO: wget $URL"
		wget $URL || \
		{
			echo "ERROR: wget $URL failed."
			exit 1
		}
	}

	[ -f $TARBALL.$MD5SUFFIX ] || \
	{
		echo "INFO: downloading $TARBALL.$MD5SUFFIX"
		wget $URL.$MD5SUFFIX || \
                {
                        echo "WARN: wget $URL.$MD5SUFFIX failed"
                        echo "Cannot check $TARBALL"
			return 1
                }
	}
	local expect_md5=`cat $TARBALL.$MD5SUFFIX | cut -d " " -f 1`
	local actrual_md5=`md5sum $TARBALL | cut -d " " -f 1`
	[ $expect_md5 == $actrual_md5 ] || \
	{
		echo "WARN: $TARBALL has different MD5 than expected."
		echo "expect:  $expect_md5"
		echo "actrual: $actrual_md5"
		return 1
	}
	echo "INFO: $TARBALL downloaded."
}

is_sub_item() {
        local a=$1
        local b=$2
        for i in $b
        do
                [ $a == $i ] && return 0
        done
        return 1
}

install() {
        installpkg $PACKAGES
	[ -f $TARBALL ] || \
		get_tarball
	if [ x$TARGET != x ]; then
        	if [ -d $TARGET ] || [ -f $TARGET ]; then
	        	echo "ERROR: $TARGET already exist"
		        echo "Change target in $TOOLNAME test config file"
		        echo "Or stop install and use the already exit."
             		exit 1
	        fi
	fi
	local tarball=$TARBALL
	local suffix=${tarball##*.}
	local arch=`arch`
	local folder=$FOLDER
	local cmd=$INSTALLCMD
	local date_end=`date +%Y_%m_%d_%Hh_%M_%S`

	if (is_sub_item $suffix "tar gz bz2 xz tgz"); then
		tar xf $tarball
	elif (is_sub_item $suffix "zip"); then
		unzip $tarball
	else
		echo "WARN: unkown type: $tarball"
	#	return 1
	fi
	[ -z $PATCH ] || patch -p0 $PATCH
	echo "INFO: install $TOOLNAME"
	echo "INFO: $cmd"
	eval $cmd &> $RESULTDIR/${TOOLNAME}_install.log || \
	{
		echo "ERROR: $TOOLNAME install failed."
		echo "Check $RESULTDIR/${TOOLNAME}_install.log for details."
		exit 2
	}
}

runtest() {
	[ -d $TARGET ] || \
		install
	local cmd=$RUNCMD
	echo "INFO: run test"
	echo "INFO: $cmd"
	eval $cmd &> $RESULTDIR/${TOOLNAME}_runtest.log
}

runstress() {
	[ -d $TARGET ] || \
		install
	local cmd=$STRESSCMD
	echo "INFO: run stress"
	echo "INFO: $cmd"
	eval $cmd &> $RESULTDIR/${TOOLNAME}_stress.log
}

run() {
	local op=$1
	shift
	local testfiles=$1
	for i in `echo $testfiles | tr "," " "`
	do
		source $i || \
		{
			echo "ERROR: failed to import $i"
			exit 3
		}
		echo "INFO: $op $i"
		local date_end=`date +%Y_%m_%d_%Hh_%M_%S`
		RESULTDIR=${RESULT:-$TOOLNAME}_$date_end
		mkdir -p $RESULTDIR
		[ -d $RESULTDIR ] || \
		{
			echo "ERROR: failed to create $RESULTDIR"
			exit 1
		}
		$op $@
	done
}

generate() {
	local testfile=$1
	[ ! -f $testfile ] || \
	{
		echo "ERROR: $testfile already exists."
		exit 1
	}
	cat > $testfile << eof
# name: $testfile
# date: $(date)
#
# This file is generated by $0
# You should edit this file before you run the test.

# base url of tarball
BASEURL=$BASEURL
# test name, same as file name by default.
TOOLNAME=$testfile
# suffix of md5 file
MD5SUFFIX=md5
# test version
VERSION=
# test official site
SITE=
# tarball file name
TARBALL=
# tarball url, 
URL=\$BASEURL/\$TARBALL
# folder after untar
FOLDER=
# patch file
PATCH=\${TOOLNAME}.patch
# install destination, directory
TARGET=


INSTALLCMD=
RESULTS=
RUNCMD=
STRESSCMD=
eof
}

usage() {
	cat << eof
USAGE: $0 <option> <test> [<test1> ...] 

OPTIONS:
    get        get test tarball
    install    install TESTTOOL
    test       run test
    stress     run stress test
    generate   gernerate test file
    help       show usage

TEST:
    Particular file for define the test.
    The basic formart can be generated by:

        $0 generate <filename>

eof
}

gendoc() {
	:
}

main(){
	local option=$1
	shift
        case $option in
                "install")
			run install $@ ;;
                "test")
			run runtest $@ ;;
                "stress")			
                        run runstress $@ ;;
		"get")
			run get_tarball $@ ;;
		"generate")
			generate $@ ;;
                ""|* )
                        usage ;;
        esac
}


main $@
