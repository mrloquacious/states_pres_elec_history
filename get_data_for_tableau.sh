#!/bin/bash

##### BEGIN NATIONAL #####
curl -o national.html https://uselectionatlas.org/RESULTS/compare.php?type=national&year=2016&f=1&off=0&elect=0
sleep 1

# The --quiet flag suppresses the errors, but makes it glaringly obvious how long it takes to download.
# Convert the downloaded .html to a .pdf:
echo ""
echo "Hold on, this will take a little while! ..."
htmldoc --webpage --quiet -f national.pdf national.html
rm national.html 

# Convert the .pdf to a .csv:
java -jar ./tabula-java-1.0.3/target/tabula-1.0.3-jar-with-dependencies.jar -p 1 -g -o national.csv national.pdf
rm national.pdf

# Remove the thousands-separator commas so we can more easily parse the .csv.
awk -F'"' -v OFS='' '{ for (i=2; i<=NF; i+=2) gsub(",", "", $i) } 1' national.csv > clean_national.csv
rm national.csv

# Calculate the national margin for each year, copy to a new file, and delete the old:
national_margin=$(gawk ' BEGIN { FS = "," }
  { if ($1 != "Map") {
    printf("%s\n", $13-$14)
    }
  }' clean_national.csv)
rm clean_national.csv

# Convert string to array:
national_margin_array=($(echo "$national_margin"))
##### END NATIONAL #####

##### BEGIN STATES #####
# Directory to store individual state files to combine into final all_states file:
mkdir "toPaste"

#TODO TEST:
#mkdir "cleanCSVs"

# Create file/variable to hold the Year column:
touch all_states0
all_states0=all_states0

# String to build and add as our final all_states file:
states=""

# The last state is Wyoming whose fips=56 (a few fips in the sequence 1-56 don't have a related state):
# I just learned that FIPS is Federal Information P Service and US territories are interspersed throughout the list.
# For example, American Samoa FIPS=4.
NUM=56

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
  # Start at char 60 and get 15 chars (len of longest state):
  state="${toParse:60:20}"
  # Chop off everything from the less than sign to the end:  
  state=("${state//<*/ }")
  state=$(echo $state | sed 's/ /_/g')
  echo "$state"

  # Bypass for any fips that don't map to a state:
  if [[ "$state" == '' ]]; then
    rm $myHTML
    continue
  fi

  # Add state + comma to $states header string. If we're at the end, just add state:
  if (( $NUM == $i )); then
    states+="$state"
  else
    states+="$state,"
  fi
  #echo "$states"

  # Create some files to work with:
  myPDF="$state.pdf"
  myCSV="$state.csv"
  cleanCSV="$state.txt"
  state_lean="$state.col"

  # Convert the downloaded .html to a .pdf:
  htmldoc --webpage -f $myPDF $myHTML

  rm $myHTML 

  # TODO Just discovered the --batch flag -- can save the PDFs in a dir and convert them all at once.
  # Convert the .pdf to a .csv:
  java -jar ./tabula-java-1.0.3/target/tabula-1.0.3-jar-with-dependencies.jar -p 1 -g -o $myCSV $myPDF
  rm $myPDF

  # Remove the thousands-separator commas so we can more easily parse the .csv.
  awk -F'"' -v OFS='' '{ for (i=2; i<=NF; i+=2) gsub(",", "", $i) } 1' $myCSV > $cleanCSV
  rm $myCSV

  # Build the year column to be pasted into our final all_states document (this only happens on the first pass): 
  if [[ $i == 1 ]]; then
    year=$(gawk '
    BEGIN { FS = "," }
      { if ($3 != "Year") {
        printf("%s\n", $3) 
      }
      }' $cleanCSV)
  fi
  echo "$year" > $all_states0

  # Build the column for the current state. The calculation is DemMargin - RepMargin. 
  # While there is already a Margin column we could use, the info on which party is ahead is unclear via data alone.
  # It's clear on the website which party is ahead through color coding.
  state_margin=$(gawk '
  BEGIN { FS = "," }
    { if ($1 != "Map") {
      printf("%s\n", $10-$11)
    }
    }' $cleanCSV)

  # Convert string to array:
  state_margin_array=($(echo "$state_margin"))

  # Loop through and calculate lean for each year:
  z=0
  for margin in "${state_margin_array[@]}"
  do
    awk "BEGIN {print $margin - ${national_margin_array[$z]}}" >> $state_lean
    z=$((z+1))
  done 

  #TODO TEST:
  rm -f $cleanCSV
  #mv $cleanCSV "cleanCSVs"

  # Save the .col files to the directory we created:
  mv $state_lean "toPaste"
done

# Loop through the .col files and paste them onto the last:
i=1
j=0
for file in toPaste/*.col;
do
  paste -d "," "all_states$j" $file >> "all_states$i"
  i=$((i+1))
  j=$((j+1))
done

# Remove the underscores from the state names and add the header row which we've built as we looped:
states=$(echo $states | sed 's/_/ /g')
gsed -i "1s/^/Date,$states\n/g" all_states$j

# Cleanup:
mv "all_states$j" pres_elec_state_margins.csv
rm -f all_states*

#TODO TEST:
rm -rf toPaste
#echo "$states" > states.csv

