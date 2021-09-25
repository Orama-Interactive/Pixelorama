#!/bin/bash

BUILD_DIR=$PWD
CACHE_DIR=$PWD/../.godot-ubports

# The latest build can always be obtained from this URL
URL_LATEST=https://gitlab.com/abmyii/ubports-godot/-/jobs/artifacts/ut-port-stable/download?job=xenial_${ARCH}_binary

# Determine the ID of the latest successful pipeline
function getNewestVersion() {
	wget -qO - https://gitlab.com/api/v4/projects/23065313/pipelines?status=success | tr ',' '\n' | grep id | head -n 1 | cut -d ':' -f 2 > newest
}

# Download a build
function download() {
	# Accept job ID as single argument
	if [ $# = 1 ]; then
		# Check if the most recently downloaded build for this architecture is from the same pipeline
		if [ -f $1.* ]; then
			echo "Already downloaded artifacts from from job $1. Using cached files."
		else
			# Download requested build and update version indicator
			wget https://gitlab.com/api/v4/projects/23065313/jobs/$1/artifacts -O temp.zip
			DOWNLOADED=`unzip -Z -1 temp.zip`
			DOWNLOADED=${DOWNLOADED##*.}
			rm -f *.$DOWNLOADED
			touch "$1.$DOWNLOADED"
			echo "Downloaded build for $DOWNLOADED from job $JOB."
			unzip -o temp.zip
			rm temp.zip
		fi
	# If no argument given, download latest build
	else
		echo "Removing references to other builds..."
		rm -f *.${ARCH}
		echo "Downloading latest build..."
		wget $URL_LATEST -O temp.zip
		unzip -o temp.zip
		rm temp.zip
	fi
}

# Store everything in a separate cache directory
mkdir -p "$CACHE_DIR"
cd "$CACHE_DIR"

# If single argument given, download from that pipeline
if [ $# = 1 ]; then
	wget -qO - https://gitlab.com/api/v4/projects/23065313/pipelines/$1/jobs | tr ',' '\n' | grep -E -e "^\W+id" | sed -e 's/[^0-9]//g' | while read JOB; do
		echo "Downloading artifacts from job $JOB in pipeline $1..."
		download $JOB
	done
# If nothing has been downloaded before, download newest build
elif [ ! -f "local-version.${ARCH}" ]; then
	echo "No local copy found."
	getNewestVersion
	download
	mv newest local-version.${ARCH}
# Otherwise, check if there's a newer version available
else
	getNewestVersion
	diff newest local-version.${ARCH} > /dev/null
	if [ $? = 0 ]; then
		echo "No newer version to download. Using cached build."
		rm newest
	else
		echo "Newer version available."
		download
		mv newest local-version.${ARCH}
	fi
fi

# Copy Godot executable to build directory
cd "$BUILD_DIR"
cp "$CACHE_DIR"/godot.ubports.${ARCH} godot
