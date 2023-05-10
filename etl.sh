#!/bin/bash
#Nicholas Adney
#Final Project
#4/18/2023

server=$1
user_id=$2
file_location=$3
file_name=$(basename "$file_location")

#ensuring the number of arguments inputted is 3
if [ "$#" -ne 3 ]; then
    echo "Usage: etl.sh remote-server remote-userid remote-file"
    exit 1
fi

#SCP the file from remote server to local directory
#sending output to dev/null. for some reason this does not work for errors
scp $user_id@$server:$file_location . > /dev/null

#ensuring the above scp exitted with no errors
if [ ! $? -eq 0 ]; then
    echo "Usage: Please check remote-server, remote-userid, and remote-file"
    exit 1

    else
#changing the original file name to transaction
mv $file_name transaction.csv.bz2

#unzipping the file
bunzip2 transaction.csv.bz2
file_name="transaction.csv"
echo "File has been successfully transferred: $file_name"

#removing the header from file
tail -n+2 $file_name > tmp.txt && mv tmp.txt $file_name

#converting all text to lowercase
cat $file_name | tr [:upper:] [:lower:] > tmp.txt && mv tmp.txt $file_name

#updating values in gender field
#value of '1' or 'female' should be 'f'
#value of '0' or 'male' should be 'm'
#otherwise, the value is set to 'u'
awk -F ',' '{
    OFS=","
    if ($5 == "1" || $5 == "female") {$5="f"} 
    else if ($5 == "0" || $5 == "male") {$5="m"} 
    else {$5="u"}
    print}' $file_name > tmp.txt && mv tmp.txt $file_name

#removing records that do not have a state or where the state contains 'NA'
awk -F ',' '{
    OFS=","
    if ($12 == "na" || $12 == "") {print > "exceptions.csv"}
    else {print > "temp.csv"}}' $file_name && mv temp.csv $file_name

#removing the "$" sign from the purchase_amt field
awk -F ',' '{
    OFS=","
    gsub(/\$/, "", $6) 
    print}' $file_name > tmp.txt && mv tmp.txt $file_name

#sort on customerID
sort -k 1,1 $file_name > tmp.txt && mv tmp.txt $file_name

#generating summary.csv
awk -F ',' 'BEGIN {OFS=","}
    #summing the purchase_amount for each customerID and also assigning respective values
    {sum_purchase_amt[$1]+=$6; customerID=$1; state=$12; zip=$13; lastname=$3; firstname=$2;
    #directing output to sort then summary.csv
    print customerID,state,zip,lastname,firstname,purchase_amount,sum_purchase_amt[$1]}' $file_name | sort -k 2,2 -nrk 3,3 -k 4,4 -k 5,5 > summary.csv
echo "summary.csv has been successfully created"

#generating transaction.rpt consisting of the number of transactions per state
awk -F ',' '{num_transactions[$12]++}
                #then direct the output to transaction.rpt
    END {
        for (state in num_transactions) 
                print  toupper(state) "      "  num_transactions[state]}' $file_name | sort -nrk 2,2 -k 1,1 > transaction.tmp
#adding the header
echo "Report by: Nick Adney" > header.tmp
echo "Transaction Count Report" >> header.tmp
echo "State   Transaction Count" >> header.tmp
#now merging the header and temporary transaction report together
cat header.tmp transaction.tmp > transaction.rpt
rm header.tmp && rm transaction.tmp
echo "transaction.rpt has been successfully created"

#generating purchase.rpt consisting of the total purchase amount by state and gender
awk -F ',' '{total_purch[$12][$5]+=$6}
    END {
        for (state in total_purch)
            { for (gender in total_purch[state])
                printf "%s %5s %15.2f\n", toupper(state), toupper(gender), total_purch[state][gender]}}' $file_name | sort -nrk 3,3 -k 1,1 -k 2,2 > purchase.tmp
#adding the header
echo "Report by: Nick Adney" > header.tmp
echo "Purchas Total Report" >> header.tmp
echo "State  Gender  Purchase Amount" >> header.tmp
#now merging the header and temporary purchase report together
cat header.tmp purchase.tmp > purchase.rpt
rm header.tmp && rm purchase.tmp
echo "purchase.rpt has been successfully created"
fi
