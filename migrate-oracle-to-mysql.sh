#!/bin/bash

tableNames="";
mysqlDataDir="/usr/local/mysql/data";
connectionString='sqlplus -s orauser/password'

getTableNames() {
tableNames=$($connectionString  <<EOF
  SET LINESIZE 3000
  SET FEEDBACK OFF
  SET HEADING OFF
  SET COLSEP ,;
  SET ECHO OFF;
  select table_name from user_tables;
  EXIT;
EOF
)
}

getTableMetadata() {
  table_name=$1

#Get column names.
columnList=$($connectionString  <<EOF
  SET LINESIZE 3000
  SET FEEDBACK OFF
  SET HEADING OFF
  SET COLSEP ,;
  SET ECHO OFF;
  SELECT  column_name FROM all_tab_columns where table_name= '$table_name';
  EXIT;
EOF
)

#Get datatypes.
datatype=$($connectionString  <<EOF
  SET LINESIZE 3000
  SET FEEDBACK OFF
  SET HEADING OFF
  SET COLSEP ,;
  SET ECHO OFF;
  SELECT data_type FROM all_tab_columns where table_name= '$table_name';
  EXIT;
EOF
)

#Get column size.
colSize=$($connectionString  <<EOF
  SET LINESIZE 200
  SET FEEDBACK OFF
  SET HEADING OFF
  SET COLSEP ,;
  SET ECHO OFF;
  set null 0
  SELECT DATA_PRECISION FROM all_tab_columns where table_name= '$table_name';
  EXIT;
EOF
)
}

checkColumnValue() {
  datatype=$1;
  column=$2;
  colsize=$3;

  if [ "$datatype" == "NUMBER" ]; then
    if [ "$colsize" == "1" ]; then
      echo "$column = case when @var$column = '' or @var$column ='0' then cast(0 as unsigned) else cast(1 as unsigned) end";
    else
      echo "$column = if (@var$column = '' , NULL, @var$column)";
    fi
  fi

  if [ "$datatype" == "DATE" ]; then
    echo "$column = if (@var$column = '', NULL, STR_TO_DATE(@var$column, '%d-%b-%y'))";
  fi

  if [ "$datatype" == "VARCHAR2" ]; then
    echo "$column = if (@var$column = '' , NULL, @var$column)"; 
  fi

  if [ "$datatype" == "FLOAT" ]; then
    echo "$column = if (@var$column = '' , NULL, @var$column)";
  fi

  if [ "$datatype" == "TIMESTAMP(6)" ]; then
     echo "$column = if (@var$column = '', NULL, STR_TO_DATE(@var$column,'%d-%b-%y %l.%i.%s.%f %p'))";
  fi  
}

creatLoadDataSQL() {
  #Retrive col and datatype
  read -a dataTypeArray <<< $datatype
  read -a columnArray <<< $columnList
  read -a columnSize <<< $colSize

  #Create a column string as (@varROLL_NO, @varNAME, @varDATE, @varADDRESS)
  element_count=${#dataTypeArray[@]}
  idx=0;
  colstring="(";
  while [ "$idx" -lt "$element_count" ]
  do
    if [[ ("${dataTypeArray[idx]}" != 'CLOB')]]; then
      if [ "$colstring" != "("  ] ; then 
        colstring="$colstring ,";
      fi
      colstring="$colstring @var${columnArray[$idx]}"
    fi
    ((idx++));
  done
  colstring="$colstring)";
  echo $colstring >> LOAD_DATA.SQL 

  #Create a set statements for date and other data_types.
  #Numeric : set ROLL_NO = if (@varROLL = '' , NULL, @varROLL)
  #varchar : set NAME = if (@varNAME = '', NULL, @varNAME)
  #DATE : set JOIN_DATE = if (@varJOIN_DATE = '' , NULL, STR_TO_DATE(@varJOIN_DATE, '%d-%b-%y'))

  element_count=${#dataTypeArray[@]}
  idx=0;
  setDatatypeString="set"
  while [ "$idx" -lt "$element_count" ]
  do
    if [[ ("${dataTypeArray[idx]}" != 'CLOB')]]; then
      if [ "$setDatatypeString" != "set"  ] ; then
        setDatatypeString="$setDatatypeString ,";
      fi
      setDatatypeString="$setDatatypeString $(checkColumnValue ${dataTypeArray[idx]} ${columnArray[idx]} ${columnSize[idx]})";
    fi
    ((idx++));
  done
  echo "$setDatatypeString;" >> LOAD_DATA.SQL
}

createLoadDataFile() {
  table_name=$1;
  echo -e "\n\! echo "-----Below is $table_name result:----"" >> LOAD_DATA.SQL
  echo -e "\nLOAD DATA INFILE '$mysqlDataDir/$table_name.csv' " >> LOAD_DATA.SQL
  echo "INTO TABLE $table_name" >> LOAD_DATA.SQL
  echo "FIELDS TERMINATED BY ',' " >> LOAD_DATA.SQL
  echo "ENCLOSED BY '\"' " >> LOAD_DATA.SQL
  echo "LINES TERMINATED BY '\n'" >> LOAD_DATA.SQL
  creatLoadDataSQL;
}

createDataCSV() {
  table_name=$1;
  filename="$table_name.csv"
  idx=0;
  read -a dataTypeArray <<< $datatype
  read -a columnArray <<< $columnList

  columnNameHeader='';
  for column in $columnList
  do
    if [[ ("${columnArray[$idx]}" == "$column") && ("${dataTypeArray[idx]}" != 'CLOB') ]]; then
      if [ "$columnNameHeader" != '' ]; then
        columnNameHeader="$columnNameHeader||'\",\"'||";
      fi
      columnNameHeader="$columnNameHeader $column"; 
    fi
    (idx++)
  done

#Creation of CSV
$connectionString <<EOF
SET ECHO OFF
  SET NEWPAGE 0
  SET SPACE 0
  SET PAGESIZE 0
  SET FEED off
  SET HEADING off
  SET TRIMSPOOL on
  SET LINESIZE 32767
  SPOOL $filename
  SELECT '"'||$columnNameHeader||'"' FROM $1;
  SPOOL OFF
  EXIT;  
EOF
  zip $table_name.zip $filename
  rm $filename;
}

main() {
  getTableNames;

  for table in $tableNames 
  do
    getTableMetadata $table;
    createDataCSV $table;
    createLoadDataFile $table;
  done
}
main;
