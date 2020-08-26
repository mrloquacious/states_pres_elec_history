#!/bin/bash

# Directory to store individual state files to combine into final allStates file:
mkdir "toPaste"

# Create file/variable to hold the Year column:
touch allStates0
allStates0=allStates0

# String to build and add as our final allStates file:
states=''

# The last state is Wyoming whose fips=56 (a few fips in the sequence 1-56 don't have a related state):
NUM=4

# Loop from i to NUM:
for i in `seq $NUM`
do
  # Download the .html from the election atlas website. Increment the fips parameter and cycle through the states: 
  myURL="https://uselectionatlas.org/RESULTS/compare.php?fips=$i&f=1&off=0&elect=0&type=state"
  myHTML="STATE$i.html"
  curl -o $myHTML $myURL

  # Have to give it a second to download:
  sleep 1

  # Grab the state name from the html for use later:
  toParse=$(sed '39q;d' $myHTML)
  state="${toParse:60:15}"
  state=(${state//</ })
  echo $state

  #TODO Not sure if all of the failed fips will look the same. Might have to alter this:
  # Bypass for any fips that don't map to a state:
  if [[ "$state" == '/b>' ]]; then
    rm $myHTML
    continue
  fi

  #TODO Add state + comma to $states header string. If we're at the end, just add state:
  if (( $NUM == $i )); then
    states+="$state"
  else
    states+="$state,"
  fi

  # Create some files to work with:
  myPDF="$state.pdf"
  myCSV="$state.csv"
  cleanCSV="$state.txt"
  stateMarg="$state.col"

  # Convert the downloaded .html to a .pdf:
  htmldoc --webpage -f $myPDF $myHTML
  rm $myHTML 

  # Convert the .pdf to a .csv:
  java -jar ./tabula-java-1.0.3/target/tabula-1.0.3-jar-with-dependencies.jar -p 1 -g -o $myCSV $myPDF
  rm $myPDF

  # Remove the thousands-separator commas so we can more easily parse the .csv.
  awk -F'"' -v OFS='' '{ for (i=2; i<=NF; i+=2) gsub(",", "", $i) } 1' $myCSV > $cleanCSV
  rm $myCSV

  # Build the year column to be pasted into our final allStates document (this only happens on the first pass): 
  if [[ $i == 1 ]]; then
    year=$(gawk '
    BEGIN {
        FS = ","
      }
      { if ($3 != "Year") {
        printf("%s\n", $3) 
      }
      }' $cleanCSV)
  fi
  echo "$year" > $allStates0

  # Build the column for the current state. The calculation is DemMargin - RepMargin. 
  # While there is already a Margin column we could use, the info on which party is ahead is unclear via data alone.
  # It's clear on the website which party is ahead through color coding.
  #TODO It might be worth considering if it's possible to extract that info from the .html, if only as an excercise:
  marg=$(gawk '
  BEGIN {
      FS = ","
    }
    { if ($1 != "Map") {
      printf("%s\n", $10-$11)
    }
    }' $cleanCSV)
  echo "$marg" > $stateMarg
  rm $cleanCSV

  # Save the .col files to the directory we created:
  mv $stateMarg "toPaste"
done

# Loop through the .col files and paste them onto the last:
i=1
j=0
for file in toPaste/*.col;
do
  paste -d "," "allStates$j" $file >> "allStates$i"
  i=$((i+1))
  j=$((j+1))
done

# Add the header row which we've built as we looped:
gsed -i "1s/^/Date,$states\n/g" allStates$j

# Cleanup:
mv "allStates$j" pres_elec_state_margins.csv
rm -f allStates*
rm -rf toPaste


