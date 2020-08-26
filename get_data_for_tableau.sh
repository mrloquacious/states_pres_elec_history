#!/bin/bash

touch allStates0
allStates0=allStates0

states=''
mkdir "toPaste"

NUM=2
for i in `seq $NUM`
do
  myURL="https://uselectionatlas.org/RESULTS/compare.php?fips=$i&f=1&off=0&elect=0&type=state"
  myHTML="STATE$i.html"
  curl -o $myHTML $myURL
  sleep 1
  toParse=$(sed '39q;d' $myHTML)
  state="${toParse:60:15}"
  state=(${state//</ })
  echo $state
  # if state == /b> continue:
  if [[ "$state" == '/b>' ]]; then
    rm $myHTML
    continue
  fi

  # Might have to check if it's the last index (which shouldn't have comma):
  states+="$state,"

  myPDF="$state.pdf"
  myCSV="$state.csv"
  cleanCSV="$state.txt"
  stateMarg="$state.col"
  htmldoc --webpage -f $myPDF $myHTML
  rm $myHTML 
  java -jar ./tabula-java-1.0.3/target/tabula-1.0.3-jar-with-dependencies.jar -p 1 -g -o $myCSV $myPDF
  rm $myPDF
  # Remove the thousands-separator commas so we can more easily parse the .csv.
  #awk -F'"' -v OFS='' '{ for (i=2; i<=NF; i+=2) gsub(",", "", $i) } 1' Alabama.csv > AL.csv
  awk -F'"' -v OFS='' '{ for (i=2; i<=NF; i+=2) gsub(",", "", $i) } 1' $myCSV > $cleanCSV
  rm $myCSV

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

  # Save the .col files to a directory
  mv $stateMarg "toPaste"
done

# Run a for loop on the .col dir and delete each .col file after paste:
i=1
j=0
for file in toPaste/*.col;
do
  paste -d "," "allStates$j" $file >> "allStates$i"
  i=$((i+1))
  j=$((j+1))
done

# Add the header row:
gsed -i "1s/^/Date,$states\n/g" allStates$j
#gsed -i "1s/^/Date,${states[*]} \n/g" allStates.csv
# The BSD sed requires a backup, but doesn't understand \n. GNU sed doesn't understand .bak, but understands \n.
#sed -i .bak '1s/^/Date,AL,\n/g' allStates.csv

# Not now. Later ...
#mv "allStates$j" THESTATES.CSV
#rm -f allStates*


##### TRASH #####

# Map,Pie,Year,Total,D,R,I,Margin,%Margin,Dem,Rep,Ind,Oth.,Dem,Rep,Ind,Other

#while IFS=, read -r Map Pie Year Total D R I Margin PMargin PDem PRep PInd POth Dem Rep Ind Oth ; do
#  # do something... Don't forget to skip the header line!
#  [[ "$Map" != "Map" ]] # && echo "$Year"
#  unset Year
#  declare -i $Year
#  #echo $Dem
#  #tot=$((Dem + Rep))
#  echo $((Year + Year))
#  #echo $[[8 + Year]]
#  #printf %.1f "$(( 10 ** 3 * $tot ))e-3"
#done < Alabama.txt 
##done < $cleanCSV

#awk '
#BEGIN {
#    FS = ","
#    #FPAT = "([^,]+)|(\"[^\"]+\")"
#    count=0
#}
#{
#  if ($1 != "Map") { # Do not forget to skip the header line!
#    # We need to append a column for each state to allStates.csv
#    # Was thinking use paste -d "," myCSV, but I need 2 files or more to use paste.
#    # Worst case, I save to a temp file and then paste to allStates.csv. 
#    #print $10 > allStates.csv
#
#    #paste -d "," allStates Minnesota
#    printf("%s\n", $10-$11)
#    ++count
#  }
#}
#END {
#  printf("Number of entries: %s\n", count)
#}
#' Alabama.txt #AL.csv


